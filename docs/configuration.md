# Configuration Guide

## Overview

The `bids2nf.yaml` file is the heart of bids2nf configuration, defining how your BIDS dataset is parsed, grouped, and processed. This file determines which files belong together and how they should be organized for downstream analysis.

## Global Configuration

### `loop_over`

The `loop_over` setting specifies which BIDS entities will be used as looping/crawling entities by Nextflow. These entities define the primary grouping level for your data.

```yaml
loop_over: [subject, session, run, task]
```

**What this means:**
- Files are grouped by these entities first
- Each unique combination of these entities creates a separate processing group
- For example, `sub-01_ses-01_run-01_task-rest` would be one group, `sub-02_ses-02` would be another with no `run` or `task` definitions available (`run-NA_task-NA`)
- This key is ignored by subworkflows when determining suffixes


**Common patterns:**
- `[subject, session]` - Group by subject and session only
- `[subject, session, run]` - Include run-level grouping
- `[subject, session, run, task]` - Full entity grouping (default)
- `[subject, another-entity]` see full list of entities [here](https://github.com/bids-standard/bids-specification/blob/master/src/schema/rules/entities.yaml).

## Set Types

bids2nf supports five different set types for organizing your data:

### 1. Plain Sets

**Plain sets** are the simplest configuration for inputs that don't require complex grouping logic. Files are collected as-is without special organization.

```yaml
plain_set:
  additional_extensions: ["extension1", "extension2"]  # Optional
  include_cross_modal: ["suffix1", "suffix2"]         # Optional
```

**Example:**
```yaml
dwi:
  plain_set:
    additional_extensions: ["bval", "bvec"]

T1w:
  plain_set: {}

aslcontext:
  plain_set:
    additional_extensions: ["tsv"]
```

**Key features:**
- **`additional_extensions`**: Include additional file extensions (e.g., `.bval`, `.bvec` for DWI)
- **`include_cross_modal`**: Include files from other suffixes that might not share all loop entities (otherwise not emitted in the same channel by nextflow)


**Use cases:**
- Simple nii/json pairs such as T1w 
- Files that don't require special pairing or sequencing
- Single-file-per-group scenarios

### 2. Named Sets

**Named sets** define specific combinations of entities that must exist together. Each element in the set has a descriptive name and specific entity values.

```yaml
named_set:
  custom_grouping_key_1:
    description: "Description of this grouping"
    entity1: "value1"
    entity2: "value2"
  custom_grouping_key_2:
    description: "Description of this grouping"
    entity1: "value3"
    entity2: "value4"
required: ["custom_grouping_key_1", "custom_grouping_key_2"]  # Optional
```

**Example:**
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

**Key features:**
- **Custom grouping keys**: Define meaningful names for each file type
- **Entity constraints**: Each grouping key specifies required entity values
- **Required validation**: Ensure all necessary files are present
- **Descriptive naming**: Each group can have a human-readable description

**Use cases:**
- Entity-linked file collections typically defined by `echo`, `inversion`, `flip`, `part`, and `mtransfer` entities. 
- Collecting together the files marked by the `direction` entity for distortion correction.
- Any protocol requiring specific parameter combinations

See more about [entity-linked file collections](https://bids-specification.readthedocs.io/en/stable/appendices/file-collections.html).

### 3. Sequential Sets

**Sequential sets** group files that vary by one or more entities, maintaining a consecutive order. Files are organized as flat or nested lists based on entity values.

#### Single Entity Sequential Sets
```yaml
sequential_set:
  by_entity: entity_name
```

**Example:**
```yaml
VFA:
  sequential_set:
    by_entity: flip

MEGRE:
  sequential_set:
    by_entity: echo
```

#### Multi-Entity Sequential Sets
```yaml
sequential_set:
  by_entities: [entity1, entity2]
  order: hierarchical  # or flat
```

**Example:**
```yaml
TB1SRGE:
  sequential_set:
    by_entities: [flip, inversion]
    order: hierarchical

TB1EPI:
  sequential_set:
    by_entities: [echo, flip]
    order: hierarchical
```

**Key features:**
- **Single entity**: `by_entity` creates a flat list ordered by entity values
- **Multiple entities**: `by_entities` creates nested structures
- **Order control**: `hierarchical` vs `flat` organization
- **Preserved sequence**: Entity order is maintained in the output

**Use cases:**
- Variable Flip Angle (VFA) sequences
- Multi-echo acquisitions (MEGRE, MESE)
- Inversion recovery sequences (IRT1)
- Complex multi-parameter sequences

### 4. Mixed Sets

**Mixed sets** combine named and sequential grouping for complex data structures. They first group files by named categories, then within each category, organize files sequentially.

```yaml
mixed_set:
  named_dimension: "entity_name"
  sequential_dimension: "entity_name"
  named_groups:
    group_name_1:
      description: "Description"
      entity1: "value1"
      entity2: "value2"
    group_name_2:
      description: "Description"
      entity1: "value3"
      entity2: "value4"
  required: ["group_name_1", "group_name_2"]  # Optional
```

**Example:**
```yaml
MPM:
  mixed_set:
    named_dimension: "acquisition"
    sequential_dimension: "echo"
    named_groups:
      MTw:
        description: "Magnetization transfer weighted images"
        acquisition: "acq-MTw"
        flip: "flip-1"
        mtransfer: "mt-on"
      PDw:
        description: "Proton density weighted images"
        acquisition: "acq-PDw"
        flip: "flip-1"
        mtransfer: "mt-off"
      T1w:
        description: "T1-weighted images"
        acquisition: "acq-T1w"
        flip: "flip-2"
        mtransfer: "mt-off"
    required: ["MTw", "PDw", "T1w"]
```

**Key features:**
- **Two-level organization**: Named groups containing sequential files
- **Flexible dimensions**: Choose which entities define grouping vs sequencing
- **Complex validation**: Ensure both named groups and sequential completeness
- **Hierarchical output**: `{group_name: {nii: [file1, file2, ...], json: [...]}}`

**Use cases:**
- Multi-Parameter Mapping (MPM) with multiple echoes per contrast
- Complex quantitative imaging protocols
- Any scenario requiring both categorical and sequential organization

### 5. Special Cases

#### Virtual Suffixes
Some configurations map one suffix to another using `suffix_maps_to`:

```yaml
MP2RAGE_multiecho:
  suffix_maps_to: "MP2RAGE"
  sequential_set:
    by_entities: [inversion, echo]
    parts: ["mag", "phase"]
```

#### Parts-based Organization
For data with magnitude and phase components:

```yaml
MP2RAGE:
  sequential_set:
    by_entity: inversion
    parts: ["mag", "phase"]
```

## Configuration Structure

### Basic Pattern
Each configuration entry follows this structure:

```yaml
SUFFIX_NAME:
  # Required: ONE of these set types
  plain_set: { ... }
  # OR
  named_set: { ... }
  # OR
  sequential_set: { ... }
  # OR
  mixed_set: { ... }
  
  # Optional: additional constraints
  required: [ ... ]
  additional_extensions: [ ... ]
  example_output: "path/to/example.json"
  
  # Special cases
  suffix_maps_to: "other_suffix"
  note: "Documentation note"
```

### Configuration Options

#### Common Options (all set types)
- **`additional_extensions`**: Include additional file extensions
- **`example_output`**: Path to example output for documentation
- **`note`**: Human-readable documentation

#### Named and Mixed Sets
- **`required`**: List of required grouping keys
- **`description`**: Human-readable description for each group

#### Sequential Sets
- **`by_entity`**: Single entity for flat sequential organization
- **`by_entities`**: Multiple entities for nested organization
- **`order`**: `hierarchical` or `flat` organization
- **`parts`**: For magnitude/phase data organization

#### Mixed Sets
- **`named_dimension`**: Entity used for named grouping
- **`sequential_dimension`**: Entity used for sequential organization
- **`named_groups`**: Named group definitions (same as named_set)

## Workflow Integration

bids2nf provides specialized workflows for each pattern type:

- **`emit_plain_sets.nf`**: Handles plain set patterns
- **`emit_named_sets.nf`**: Handles named set patterns
- **`emit_sequential_sets.nf`**: Handles sequential set patterns
- **`emit_mixed_sets.nf`**: Handles mixed set patterns
- **`bids2nf.nf`**: **Unified workflow** (recommended)

### Unified Workflow (Recommended)

```nextflow
include { bids2nf } from './workflows/bids2nf.nf'

workflow {
    unified_results = bids2nf(params.bids_dir)
    my_analysis_process(unified_results)
}
```

The unified workflow automatically:
1. Analyzes your configuration
2. Detects pattern types
3. Routes to appropriate workflows
4. Combines results

## Best Practices

### Choosing Set Types

1. **Use plain_set for:**
   - Single files per group
   - Standard neuroimaging data
   - Simple data collection

2. **Use named_set for:**
   - Fixed combinations of acquisitions
   - Multi-contrast protocols
   - Quality control requiring specific files

3. **Use sequential_set for:**
   - Variable parameters (flip angles, echo times)
   - Ordered acquisitions
   - Parameter mapping sequences

4. **Use mixed_set for:**
   - Complex multi-parameter protocols
   - Combinations of the above patterns
   - Multi-echo multi-contrast data

### Entity Hierarchy

- **Core entities** (`subject`, `session`, `run`, `task`): Define grouping level
- **Pattern entities** (`flip`, `echo`, `mtransfer`): Define variations within groups

### Validation

- Use `required` fields to ensure data completeness
- Test configurations with example datasets
- Validate output structures match expectations

## Troubleshooting

### Common Issues

1. **Missing files**: Check `required` field and entity matching
2. **Incorrect grouping**: Verify `loop_over` entities
3. **Wrong file types**: Check `additional_extensions`
4. **Complex hierarchies**: Consider mixed sets instead of nested sequential sets

### Debugging Tips

- Use `example_output` files to understand expected structure
- Test with small datasets first
- Check entity consistency across files
- Validate BIDS compliance of input data