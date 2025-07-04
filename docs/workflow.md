# Example Processes and Workflows

This guide walks you through creating your first Nextflow pipeline using bids2nf to process BIDS datasets. bids2nf automatically organizes your BIDS data into structured Nextflow channels, making it easy to build robust neuroimaging pipelines.

## Step 1: Prepare Your BIDS Dataset

Ensure your data follows the [BIDS specification](https://bids.neuroimaging.io/). Here are two common neuroimaging scenarios:

### Magnetization Transfer Saturation (MTS) Dataset
```
mts_dataset/
├── dataset_description.json
├── participants.tsv
└── sub-01/
    └── anat/
        ├── sub-01_flip-01_mt-off_MTS.nii.gz
        ├── sub-01_flip-01_mt-off_MTS.json
        ├── sub-01_flip-01_mt-on_MTS.nii.gz
        ├── sub-01_flip-01_mt-on_MTS.json
        ├── sub-01_flip-02_mt-off_MTS.nii.gz
        └── sub-01_flip-02_mt-off_MTS.json
```

### Multi-Echo Gradient Echo (MEGRE) Dataset
```
megre_dataset/
├── dataset_description.json
├── participants.tsv
└── sub-01/
    └── anat/
        ├── sub-01_echo-1_MEGRE.nii.gz
        ├── sub-01_echo-1_MEGRE.json
        ├── sub-01_echo-2_MEGRE.nii.gz
        ├── sub-01_echo-2_MEGRE.json
        ├── sub-01_echo-3_MEGRE.nii.gz
        └── sub-01_echo-3_MEGRE.json
```

## Step 2: Use the Built-in Configuration

bids2nf comes with pre-configured support for most common BIDS patterns including MTS, MEGRE, VFA, MPM, and many others. Simply use the provided `bids2nf.yaml` file - no configuration needed!

The default configuration already includes:
- **MTS**: Magnetization Transfer Saturation (T1w, MTw, PDw contrasts)
- **MEGRE**: Multi-Echo Gradient Echo (organized by echo time)
- **VFA**: Variable Flip Angle (organized by flip angle)
- **MPM**: Multi-Parameter Mapping (combined contrasts and echoes)
- And many more...

If your data follows standard BIDS conventions, you can skip configuration entirely. If you need custom configurations, see the [supported configurations](supported.md) documentation.

## Step 3: Create Your Nextflow Pipeline

In your project directory (separate from the bids2nf repository), create a pipeline file called `my_example_bids_pipeline.nf`:

```
your_project/
├── my_example_bids_pipeline.nf
├── data/
│   └── your_bids_dataset/
└── results/
```

```groovy
// my_example_bids_pipeline.nf
include { bids2nf } from '/path/to/bids2nf/main.nf'

// Define parameters
params.bids_dir = null
params.output_dir = 'results'

// Validate required parameters
if (!params.bids_dir) {
    error "Please provide --bids_dir parameter"
}

workflow {
    // Create organized channels from your BIDS dataset
    bids_channel = bids2nf(params.bids_dir)
    
    // Process the data
    analyze_data(bids_channel)
}

// Your analysis process
process analyze_data {
    tag "${subject}_${session}_${run}"
    publishDir "${params.output_dir}/${subject}", mode: 'copy'
    
    input:
    tuple val(grouping_key), val(data)
    
    output:
    path "*.nii.gz", optional: true
    path "*.json", optional: true
    
    script:
    def (subject, session, run) = grouping_key
    def bids_data = data.data
    
    """
    echo "Processing ${subject} (session: ${session}, run: ${run})"
    echo "Available data: ${bids_data.keySet().join(', ')}"
    
    # Process based on what data is available
    ${generate_processing_script(bids_data)}
    """
}

def generate_processing_script(bids_data) {
    if (bids_data.containsKey('MTS')) {
        return mts_processing_script(bids_data['MTS'])
    } else if (bids_data.containsKey('MEGRE')) {
        return megre_processing_script(bids_data['MEGRE'])
    } else {
        return "echo 'No recognized data pattern found'"
    }
}

def mts_processing_script(mts_data) {
    return """
    # MTS quantitative analysis
    t1w_file="${mts_data['T1w']['nii']}"
    mtw_file="${mts_data['MTw']['nii']}"
    pdw_file="${mts_data['PDw']['nii']}"
    
    echo "Running MTS analysis..."
    echo "T1w: \$t1w_file"
    echo "MTw: \$mtw_file"
    echo "PDw: \$pdw_file"
    
    # Calculate MT ratio and other quantitative maps
    python3 << 'EOF'
import nibabel as nib
import numpy as np
import json

# Load images
t1w = nib.load("${mts_data['T1w']['nii']}")
mtw = nib.load("${mts_data['MTw']['nii']}")
pdw = nib.load("${mts_data['PDw']['nii']}")

# Calculate MT ratio
mt_ratio = (pdw.get_fdata() - mtw.get_fdata()) / pdw.get_fdata()
mt_ratio = np.nan_to_num(mt_ratio, 0)

# Save MT ratio map
mt_ratio_img = nib.Nifti1Image(mt_ratio, t1w.affine, t1w.header)
nib.save(mt_ratio_img, 'mt_ratio.nii.gz')

# Create summary statistics
stats = {
    'mean_mt_ratio': float(np.mean(mt_ratio[mt_ratio > 0])),
    'std_mt_ratio': float(np.std(mt_ratio[mt_ratio > 0])),
    'processing_complete': True
}

with open('mts_results.json', 'w') as f:
    json.dump(stats, f, indent=2)

print("MTS processing completed")
EOF
    """
}

def megre_processing_script(megre_data) {
    def echo_files = megre_data['nii']
    def num_echoes = echo_files.size()
    
    return """
    # Multi-echo gradient echo analysis
    echo "Processing ${num_echoes} echo images for T2* mapping"
    
    # List all echo files
    ${echo_files.withIndex().collect { file, idx -> 
        "echo_${idx+1}=\"${file}\""
    }.join('\n    ')}
    
    python3 << 'EOF'
import nibabel as nib
import numpy as np
import json
from scipy.optimize import curve_fit

def t2star_decay(te, s0, t2star):
    return s0 * np.exp(-te / t2star)

# Load echo images and times
echo_files = [${echo_files.collect { "\"${it}\"" }.join(', ')}]
echo_times = []

# Extract echo times from JSON files
${echo_files.withIndex().collect { file, idx ->
    def json_file = file.replace('.nii.gz', '.json').replace('.nii', '.json')
    """
with open("${json_file}", 'r') as f:
    metadata = json.load(f)
    echo_times.append(metadata.get('EchoTime', ${(idx+1)*0.005}))  # Default if missing
    """
}.join('\n')}

echo_times = np.array(echo_times)
print(f"Echo times: {echo_times}")

# Load image data
echo_data = []
for i, echo_file in enumerate(echo_files):
    img = nib.load(echo_file)
    echo_data.append(img.get_fdata())
    if i == 0:
        affine, header = img.affine, img.header

echo_data = np.array(echo_data)
print(f"Data shape: {echo_data.shape}")

# Fit T2* decay
t2star_map = np.zeros(echo_data.shape[1:])
r2star_map = np.zeros(echo_data.shape[1:])

# Fit voxel-wise (simplified for demo)
valid_mask = np.mean(echo_data, axis=0) > np.percentile(echo_data, 50)

for i in range(echo_data.shape[1]):
    for j in range(echo_data.shape[2]):
        for k in range(echo_data.shape[3]):
            if valid_mask[i, j, k]:
                try:
                    signal = echo_data[:, i, j, k]
                    if np.all(signal > 0):
                        popt, _ = curve_fit(t2star_decay, echo_times, signal, 
                                          bounds=([0, 0.001], [np.inf, 0.2]))
                        t2star_map[i, j, k] = popt[1] * 1000  # Convert to ms
                        r2star_map[i, j, k] = 1.0 / popt[1]  # R2* = 1/T2*
                except:
                    pass

# Save maps
t2star_img = nib.Nifti1Image(t2star_map, affine, header)
nib.save(t2star_img, 't2star_map.nii.gz')

r2star_img = nib.Nifti1Image(r2star_map, affine, header)
nib.save(r2star_img, 'r2star_map.nii.gz')

# Summary statistics
stats = {
    'num_echoes': ${num_echoes},
    'echo_times_ms': (echo_times * 1000).tolist(),
    'mean_t2star_ms': float(np.mean(t2star_map[t2star_map > 0])),
    'mean_r2star_hz': float(np.mean(r2star_map[r2star_map > 0])),
    'processing_complete': True
}

with open('megre_results.json', 'w') as f:
    json.dump(stats, f, indent=2)

print("MEGRE T2* mapping completed")
EOF
    """
}
```

## Step 4: Understanding Data Access

bids2nf automatically organizes your data based on your configuration. Here's how to access it:

### MTS Data Access
```groovy
// Access specific contrasts directly
def t1w_file = bids_data['MTS']['T1w']['nii']
def mtw_file = bids_data['MTS']['MTw']['nii'] 
def pdw_file = bids_data['MTS']['PDw']['nii']

// Access corresponding JSON metadata
def t1w_json = bids_data['MTS']['T1w']['json']
```

### MEGRE Data Access
```groovy
// Access the array of echo images
def echo_images = bids_data['MEGRE']['nii']  // List of all echo files
def echo_jsons = bids_data['MEGRE']['json']  // Corresponding JSON files

// Access specific echoes
def first_echo = echo_images[0]
def last_echo = echo_images[-1]
```

## Step 5: Run Your Pipeline

Execute your pipeline:

```bash
# For MTS dataset
nextflow run my_example_bids_pipeline.nf --bids_dir /path/to/mts_dataset

# For MEGRE dataset  
nextflow run my_example_bids_pipeline.nf --bids_dir /path/to/megre_dataset
```

With additional options:
```bash
nextflow run my_example_bids_pipeline.nf \
    --bids_dir /path/to/your/dataset \
    --output_dir quantitative_maps \
    -resume
```

## Real-World Examples

### FSL-based Analysis
```groovy
process fsl_analysis {
    input:
    tuple val(grouping_key), val(data)
    
    script:
    def bids_data = data.data
    """
    # For any type of data
    if [[ "${bids_data.containsKey('MTS')}" == "true" ]]; then
        # Brain extraction on PDw image
        bet ${bids_data['MTS']['PDw']['nii']} brain_pdw.nii.gz -f 0.3 -m
        
        # Register MTw to PDw space
        flirt -in ${bids_data['MTS']['MTw']['nii']} \\
              -ref ${bids_data['MTS']['PDw']['nii']} \\
              -out mtw_registered.nii.gz \\
              -omat mtw_to_pdw.mat
    
    elif [[ "${bids_data.containsKey('MEGRE')}" == "true" ]]; then
        # Extract first echo for brain mask
        first_echo="${bids_data['MEGRE']['nii'][0]}"
        bet \$first_echo brain_mask.nii.gz -f 0.3 -m
    fi
    """
}
```

### ANTs-based Processing
```groovy
process ants_processing {
    input:
    tuple val(grouping_key), val(data)
    
    script:
    def bids_data = data.data
    """
    if [[ "${bids_data.containsKey('MTS')}" == "true" ]]; then
        # Advanced normalization between contrasts
        antsRegistration --dimensionality 3 \\
                        --float 0 \\
                        --interpolation Linear \\
                        --winsorize-image-intensities [0.005,0.995] \\
                        --use-histogram-matching 0 \\
                        --initial-moving-transform [${bids_data['MTS']['PDw']['nii']},${bids_data['MTS']['T1w']['nii']},1] \\
                        --transform Rigid[0.1] \\
                        --metric MI[${bids_data['MTS']['PDw']['nii']},${bids_data['MTS']['T1w']['nii']},1,32,Regular,0.25] \\
                        --convergence [1000x500x250x100,1e-6,10] \\
                        --output [t1w_to_pdw_,t1w_registered.nii.gz]
    fi
    """
}
```

## What You Get

bids2nf provides your processes with:
- **Organized file paths**: Automatic grouping by subject/session/run
- **Flexible access**: Simple dictionary-style access to your data
- **Metadata preservation**: JSON sidecar files automatically paired
- **Type safety**: Consistent data structures regardless of dataset complexity

## Next Steps

1. **Explore configurations**: Check the [supported BIDS suffixes](supported.md) for more examples
2. **Add quality control**: Implement checks for data completeness and quality
3. **Scale up**: Process multiple subjects in parallel with Nextflow's built-in parallelization
4. **Integrate tools**: Combine with your favorite neuroimaging software (FSL, ANTs, FreeSurfer, etc.)

For more configuration examples and supported BIDS patterns, see the [supported configurations documentation](supported.md).