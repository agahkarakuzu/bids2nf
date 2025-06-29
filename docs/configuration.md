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

## Configuration Structure

### Basic Pattern

Each pattern in `bids2nf.yaml` follows this structure:

```yaml
PATTERN_NAME:
  # Either named_set OR sequential_set
  named_set: { ... }
  # OR
  sequential_set: { ... }
  
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