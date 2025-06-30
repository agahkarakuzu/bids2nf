# Configuration Guide

## bids2nf.yaml Overview

The `bids2nf.yaml` file controls how your BIDS dataset is parsed and grouped. It defines patterns that determine which files belong together and how they should be processed.

## Named Sets vs Sequential Sets

### Named Sets

**Named sets** define specific combinations of entities that must exist together. Each element in the set has a descriptive name and specific entity values.

**Use case**: When you need specific combinations of acquisition parameters, like MTS (Magnetization Transfer Saturation) sequences.

```yaml
MTS:
  named_set:
    T1w:
      description: "T1-weighted image assuming flip-02 is the larger flip angle"
      flip: "flip-02"
      mtransfer: "mt-off"
    MTw:
      description: "Magnetization transfer weighted image of the PD pair"
      flip: "flip-01"
      mtransfer: "mt-on"
    PDw:
      description: "Proton density weighted image assuming flip-01 is the lower flip angle"
      flip: "flip-01"
      mtransfer: "mt-off"
  required: ["T1w", "MTw", "PDw"]
```

**What this means:**
- For MTS processing, you need exactly 3 images per group
- Each image has specific acquisition parameters (flip angle and MT state)
- All three must be present or the group is invalid
- The output channel will contain named references to each image type

### Sequential Sets  

**Sequential sets** group files that vary by a single entity, maintaining the sequence order.

**Use case**: When you need all variations of a parameter, like Variable Flip Angle (VFA) sequences with different flip angles.

```yaml
VFA:
  sequential_set:
    by_entity: flip
```

**What this means:**
- Group all files that have different flip angles but are otherwise identical
- Preserve the order of flip angles
- The output channel will contain an array of files ordered by the entity values

### Multi-Entity Sequential Sets

You can also create sequential sets based on multiple entities:

```yaml
VFA:
  sequential_set:
    by_entities: [flip, echo]
    order: hierarchical
```

This groups files by both flip angle and echo time, organizing them hierarchically.

### Mixed Sets

**Mixed sets** combine both named and sequential grouping for complex data structures. They first group files by named categories, then within each category, organize files sequentially by another entity.

**Use case**: Multi-Parameter Mapping (MPM) data where you have multiple acquisition types (MTw, PDw, T1w), each with multiple echoes.

```yaml
MPM:
  mixed_set:
    named_dimension: "acq"
    sequential_dimension: "echo"
    named_groups:
      MTw:
        description: "Magnetization transfer weighted images"
        acq: "MTw"
        flip: "flip-01"
        mt: "mt-on"
      PDw:
        description: "Proton density weighted images"  
        acq: "PDw"
        flip: "flip-01"
        mt: "mt-off"
      T1w:
        description: "T1-weighted images"
        acq: "T1w"
        flip: "flip-02"
        mt: "mt-off"
    required: ["MTw", "PDw", "T1w"]
```

**What this means:**
- First, group files by acquisition type (MTw, PDw, T1w) using named grouping
- Within each acquisition type, group files sequentially by echo number
- Each acquisition type must have specific entity constraints (flip, mt, etc.)
- The output channel will contain named groups, each with arrays of sequential files
- Final structure: `{MPM: {MTw: {nii: [echo1, echo2, ...], json: [...]}, PDw: {...}, T1w: {...}}}`

## Configuration Structure

### Basic Pattern

Each pattern in `bids2nf.yaml` follows this structure:

```yaml
PATTERN_NAME:
  # One of: named_set, sequential_set, or mixed_set
  named_set: { ... }
  # OR
  sequential_set: { ... }
  # OR
  mixed_set: { ... }
  
  # Optional: additional constraints
  required: [ ... ]
```

### Pattern Names

Pattern names (like `MTS`, `VFA`) become:
- Workflow identifiers in your Nextflow pipeline
- Output channel names
- Process template references

## How Patterns Relate to Workflows

bids2nf includes workflows that handle each pattern type:

- **`emit_named_sets.nf`**: Processes named set patterns
- **`emit_sequential_sets.nf`**: Processes sequential set patterns  
- **`emit_mixed_sets.nf`**: Processes mixed set patterns
- **`bids2nf.nf`**: **Unified workflow** that automatically detects and processes all pattern types

### Unified Workflow (Recommended)

The **unified workflow** (`bids2nf.nf`) is the recommended entry point. It:

1. **Automatically analyzes** your configuration file
2. **Detects** which pattern types are present (named, sequential, mixed)
3. **Routes** to the appropriate specialized workflows
4. **Combines** all results into a single output channel

```nextflow
include { bids2nf } from './workflows/bids2nf.nf'

workflow {
    // Single call handles all pattern types in your config
    unified_results = bids2nf(params.bids_dir)
    
    // Process all results regardless of their pattern type
    my_analysis_process(unified_results)
}
```

**Benefits:**
- **Single entry point** - no need to know which patterns your config contains
- **Mixed configurations** - handle datasets with multiple pattern types
- **Future-proof** - automatically supports new pattern types
- **Unified output** - all results in the same channel format

### Individual Workflows

You can still use individual workflows for specific use cases:

```nextflow
// For configurations with only named sets
named_only = emit_named_sets(params.bids_dir, params.bids2nf_config)

// For configurations with only sequential sets  
sequential_only = emit_sequential_sets(params.bids_dir, params.bids2nf_config)

// For configurations with only mixed sets
mixed_only = emit_mixed_sets(params.bids_dir, params.bids2nf_config)
```

Your `bids2nf.yaml` configuration determines which workflow is used for each pattern.

## Entity Hierarchy

Remember that core entities (`sub`, `ses`, `run`) define the grouping level, while pattern-specific entities (`flip`, `echo`, `mtransfer`) define the variations within each group.

For example, with MTS:
```
sub-01/
├── sub-01_flip-01_mt-off_T1w.nii.gz  (PDw)
├── sub-01_flip-01_mt-on_T1w.nii.gz   (MTw)  
└── sub-01_flip-02_mt-off_T1w.nii.gz  (T1w)
```

All three files belong to the same group (subject 01) but have different roles in the named set.