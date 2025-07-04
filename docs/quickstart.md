# Quick Start

:::{danger}
This documentation page has not been tested thoroughly yet.
:::

Get started with bids2nf in 3 simple steps. This guide shows you how to quickly explore your BIDS dataset and generate JSON outputs to understand the data structure.

## Step 1: Get bids2nf

Follow the [installation](installation.md) instructions.

## Step 2: Test with Your BIDS Dataset

Use the built-in test workflow to explore your BIDS data. Choose the appropriate profile for your system:

### For Apple Silicon Macs:
```bash
nextflow run tests/integration/test_unified_bids2nf.nf --bids_dir /path/to/your/bids/dataset -profile arm64_test
```

### For Intel/AMD systems:
```bash
nextflow run tests/integration/test_unified_bids2nf.nf --bids_dir /path/to/your/bids/dataset -profile amd64_test
```

### Skip BIDS validation (faster):
```bash
nextflow run tests/integration/test_unified_bids2nf.nf --bids_dir /path/to/your/bids/dataset -profile arm64_test --bids_validation false
```

### Use custom configuration:
```bash
nextflow run tests/integration/test_unified_bids2nf.nf --bids_dir /path/to/your/bids/dataset --bids2nf_config /path/to/your/config.yaml -profile arm64_test
```

This will:
- Parse your BIDS dataset using the configuration (default: `bids2nf.yaml`)
- Validate your BIDS dataset using Docker containers (unless `--bids_validation false`)
- Generate JSON files showing the organized data structure
- Save outputs to `tests/new_outputs/[dataset_name]/`

## Step 3: Examine the Results

The test generates JSON files for each subject/session/run combination, showing:
- Available data types (MTS, MEGRE, VFA, etc.)
- File paths for each data type
- Metadata structure

Example output (`sub-01_ses-01_run-01_unified.json`):
```json
{
  "subject": "sub-01",
  "session": "ses-01", 
  "run": "run-01",
  "totalFiles": 6,
  "data": {
    "MTS": {
      "T1w": {
        "nii": "/path/to/sub-01_ses-01_run-01_T1w.nii.gz",
        "json": "/path/to/sub-01_ses-01_run-01_T1w.json"
      },
      "MTw": {
        "nii": "/path/to/sub-01_ses-01_run-01_MTw.nii.gz", 
        "json": "/path/to/sub-01_ses-01_run-01_MTw.json"
      },
      "PDw": {
        "nii": "/path/to/sub-01_ses-01_run-01_PDw.nii.gz",
        "json": "/path/to/sub-01_ses-01_run-01_PDw.json"
      }
    }
  }
}
```

## Common BIDS Patterns

bids2nf automatically detects common neuroimaging patterns:

- **MTS**: Magnetization Transfer Saturation (T1w, MTw, PDw)
- **MEGRE**: Multi-Echo Gradient Echo (organized by echo)
- **VFA**: Variable Flip Angle (organized by flip angle)
- **MPM**: Multi-Parameter Mapping 
- **And many more...**

## Available Profiles

- **arm64_test**: For Apple Silicon (M1/M2) Macs with test settings
- **amd64_test**: For Intel/AMD systems with test settings  
- **arm64_user**: For Apple Silicon with user-friendly settings
- **amd64_user**: For Intel/AMD systems with user-friendly settings

## Configuration Options

- `--bids_dir`: Path to your BIDS dataset (required)
- `--bids2nf_config`: Path to custom configuration file (default: `bids2nf.yaml`)
- `--bids_validation`: Enable/disable BIDS validation (default: true)
- `--includeBidsParentDir`: Include parent directory in output paths (default: false)

## Next Steps

1. **Explore your results**: Check the JSON files in `tests/new_outputs/`
2. **Build your pipeline**: Use the [workflow guide](workflow.md) to create a full processing pipeline
3. **Customize configuration**: See [supported configurations](supported.md) for advanced options

Ready to build a complete pipeline? Check out the [workflow documentation](workflow.md)!