# Examples

## Common Usage Patterns

### MTS (Magnetization Transfer Saturation) Processing

**Scenario**: You have a BIDS dataset with MTS sequences that require T1w, MTw, and PDw images to be processed together.

**Configuration** (`bids2nf.yaml`):
```yaml
MTS:
  named_set:
    T1w:
      description: "T1-weighted image"
      flip: "flip-02"
      mtransfer: "mt-off"
    MTw:
      description: "Magnetization transfer weighted image"
      flip: "flip-01"
      mtransfer: "mt-on"
    PDw:
      description: "Proton density weighted image"
      flip: "flip-01"
      mtransfer: "mt-off"
  required: ["T1w", "MTw", "PDw"]
```

**Expected BIDS structure**:
```
sub-01/
├── sub-01_flip-01_mt-off_T1w.nii.gz  # PDw
├── sub-01_flip-01_mt-on_T1w.nii.gz   # MTw
└── sub-01_flip-02_mt-off_T1w.nii.gz  # T1w
```

**Output**: Each subject gets one channel element containing all three images with named references.

### VFA (Variable Flip Angle) Processing

**Scenario**: You have multiple flip angle acquisitions that need to be processed as a sequence.

**Configuration** (`bids2nf.yaml`):
```yaml
VFA:
  sequential_set:
    by_entity: flip
```

**Expected BIDS structure**:
```
sub-01/
├── sub-01_flip-05_T1w.nii.gz
├── sub-01_flip-10_T1w.nii.gz
├── sub-01_flip-15_T1w.nii.gz
└── sub-01_flip-20_T1w.nii.gz
```

**Output**: Each subject gets one channel element containing an ordered array of all flip angle images.

### Multi-Session Dataset

**Scenario**: Longitudinal study with multiple sessions per subject.

**BIDS structure**:
```
sub-01/
├── ses-01/
│   ├── sub-01_ses-01_flip-01_mt-off_T1w.nii.gz
│   ├── sub-01_ses-01_flip-01_mt-on_T1w.nii.gz
│   └── sub-01_ses-01_flip-02_mt-off_T1w.nii.gz
└── ses-02/
    ├── sub-01_ses-02_flip-01_mt-off_T1w.nii.gz
    ├── sub-01_ses-02_flip-01_mt-on_T1w.nii.gz
    └── sub-01_ses-02_flip-02_mt-off_T1w.nii.gz
```

**Output**: Each session gets its own channel element: `[sub-01, ses-01]` and `[sub-01, ses-02]`.

## Pipeline Integration

### Basic Nextflow Integration

```nextflow
include { EMIT_NAMED_SETS } from './workflows/emit_named_sets.nf'

workflow {
    // Load BIDS dataset
    bids_channel = EMIT_NAMED_SETS(
        params.bids_dir,
        'MTS'  // Pattern name from bids2nf.yaml
    )
    
    // Process each group
    bids_channel.view()  // Debug: see what's in each channel element
    
    // Your processing steps
    PROCESS_MTS(bids_channel)
}
```

### Handling Different Pattern Types

```nextflow
// For named sets
include { EMIT_NAMED_SETS } from './workflows/emit_named_sets.nf'

// For sequential sets  
include { EMIT_SEQUENTIAL_SETS } from './workflows/emit_sequential_sets.nf'

workflow {
    if (params.pattern == 'MTS') {
        data_channel = EMIT_NAMED_SETS(params.bids_dir, 'MTS')
    } else if (params.pattern == 'VFA') {
        data_channel = EMIT_SEQUENTIAL_SETS(params.bids_dir, 'VFA')
    }
    
    PROCESS_DATA(data_channel)
}
```

## Real-World Scenarios

### Combining Multiple Modalities

```yaml
# Process both MTS and VFA in the same dataset
MTS:
  named_set:
    # ... MTS configuration
    
VFA:
  sequential_set:
    by_entity: flip
```

### Multi-Site Studies

For datasets with varying acquisition parameters across sites, use entity-based grouping to ensure consistent processing within each site while accommodating differences between sites.

### Quality Control

bids2nf validates that all required files exist before emitting channels, so missing files will cause the pipeline to fail early rather than during processing.