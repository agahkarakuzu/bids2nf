# Supported BIDS suffixes

This page documents the BIDS suffixes currently supported by bids2nf.

## Plain Sets

Plain sets define simple collections of files that do not require special grouping logic.

::::{card}
:header: <span class="custom-heading-plain"><h4>dwi</h4></span>
:footer: **Additional extensions:** `bval`, `bvec`

**Diffusion-weighted image**

Diffusion-weighted imaging contrast (specialized T2 weighting).


:::{mermaid}
graph LR
    A[dwi] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    A -.-> D[.bval]
    A -.-> E[.bvec]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C,D,E optionalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access bval file:
  bids_channel['dwi']['bval']
  // → ds-dwi/sub-01/dwi/sub-01_dwi.bval

  // Access bvec file:
  bids_channel['dwi']['bvec']
  // → ds-dwi/sub-01/dwi/sub-01_dwi.bvec

  // Access json file:
  bids_channel['dwi']['json']
  // → ds-dwi/sub-01/dwi/sub-01_dwi.json

  // Access nii file:
  bids_channel['dwi']['nii']
  // → ds-dwi/sub-01/dwi/sub-01_dwi.nii

```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/ds-dwi/sub-01_NA_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-plain"><h4>T1w</h4></span>
:footer: **Additional extensions:** None

**T1-weighted image**

In arbitrary units (arbitrary).
The contrast of these images is mainly determined by spatial variations in
the longitudinal relaxation time of the imaged specimen.
In spin-echo sequences this contrast is achieved at relatively short
repetition and echo times.
To achieve this weighting in gradient-echo images, again, short repetition
and echo times are selected; however, at relatively large flip angles.
Another common approach to increase T1 weighting in gradient-echo images is
to add an inversion preparation block to the beginning of the imaging
sequence (for example, `TurboFLASH` or `MP-RAGE`).


:::{mermaid}
graph LR
    A[T1w] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C optionalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access json file:
  bids_channel['T1w']['json']
  // → ds-dwi/sub-01/anat/sub-01_T1w.json

  // Access nii.gz file:
  bids_channel['T1w']['nii.gz']
  // → ds-dwi/sub-01/anat/sub-01_T1w.nii.gz

```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/ds-dwi/sub-01_NA_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-plain"><h4>asl</h4></span>
:footer: **Additional extensions:** None

**Arterial Spin Labeling**

The complete ASL time series stored as a 4D NIfTI file in the original
acquisition order, with possible volume types including: control, label,
m0scan, deltam, cbf.


:::{mermaid}
graph LR
    A[asl] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C optionalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access main files:
  bids_channel['asl']['nii']
  bids_channel['asl']['json']
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/asl003/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-plain"><h4>aslcontext</h4></span>
:footer: **Additional extensions:** `tsv`

**Arterial Spin Labeling Context**

A TSV file defining the image types for volumes in an associated ASL file.


:::{mermaid}
graph LR
    A[aslcontext] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    A -.-> D[.tsv]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C,D optionalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access files (flexible formats):
  // NIfTI file (if available):
  bids_channel['aslcontext']['nii']
  // JSON file (if available):
  bids_channel['aslcontext']['json']
  // Additional files:
  bids_channel['aslcontext']['tsv']
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/asl003/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-plain"><h4>m0scan</h4></span>
:footer: **Additional extensions:** None

**M0 image**

The M0 image is a calibration image, used to estimate the equilibrium
magnetization of blood.


:::{mermaid}
graph LR
    A[m0scan] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C optionalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access main files:
  bids_channel['m0scan']['nii']
  bids_channel['m0scan']['json']
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/asl003/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-plain"><h4>mrsref</h4></span>
:footer: **Additional extensions:** None | **Cross-modal includes:** `T1w`

**MRS reference acquisition**

An MRS acquisition collected to serve as a concentration reference for absolute quantification
or as a calibration reference for preprocessing (for example, eddy-current correction).


:::{mermaid}
graph LR
    A[mrsref] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    D[T1w] ==> A
    D --> E[.nii/.nii.gz]
    D -.-> F[.json]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C optionalNode
    class D crossModalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access json file:
  bids_channel['mrsref']['json']
  // → ds-mrs_fmrs/sub-01/mrs/sub-01_task-baseline_mrsref.json

  // Access nii.gz file:
  bids_channel['mrsref']['nii.gz']
  // → ds-mrs_fmrs/sub-01/mrs/sub-01_task-baseline_mrsref.nii.gz

```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/ds-mrs_fmrs/sub-01_NA_NA_task-baseline_unified.json>`

:::{note}
Input (MRS-MRF related) files (under the `mrs` directory) for this example dataset are:
  - `sub-01_task-baseline_mrsref.nii.gz`
  - `sub-01_task-pain_mrsref.nii.gz`

On the other hand, the `T1w` file is under the `anat` directory: `sub-01_T1w.nii.gz`.

By default, **bids2nf** is configured to loop over [`subject`, `session`, `run`, `task`] entities (see [`loop_over`](#global-configuration)). Given that the
`T1w` file does not have a `task` entity shared with either of these MRS-MRF files, Nextflow
will emit it as a separate channel by default. 

However, there may be a need to have all these files in
the same channel. To do so, you can use the `include_cross_modal` option to include the `T1w` file in one 
of the suffixes (`mrsref`, in this case) to merge `T1w` channel (or some other suffix) onto it, as implemented in this example.
> Alternatively you can customize `loop_over` to exclude the `task` entity and define `named sets`, assuming that the task values are known beforehand.

:::
::::

::::{card}
:header: <span class="custom-heading-plain"><h4>svs</h4></span>
:footer: **Additional extensions:** None

**Single-voxel spectroscopy**

MRS acquisitions where the detected MR signal is spatially localized to a single volume.


:::{mermaid}
graph LR
    A[svs] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C optionalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access json file:
  bids_channel['svs']['json']
  // → ds-mrs_fmrs/sub-01/mrs/sub-01_task-pain_svs.json

  // Access nii.gz file:
  bids_channel['svs']['nii.gz']
  // → ds-mrs_fmrs/sub-01/mrs/sub-01_task-pain_svs.nii.gz

```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/ds-mrs_fmrs/sub-01_NA_NA_task-pain_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-plain"><h4>events</h4></span>
:footer: **Additional extensions:** `tsv`

**Events**

Event timing information from a behavioral task.


:::{mermaid}
graph LR
    A[events] --> B[.nii/.nii.gz]
    A -.-> C[.json]
    A -.-> D[.tsv]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B fileNode
    class C,D optionalNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access tsv file:
  bids_channel['events']['tsv']
  // → ds-mrs_fmrs/sub-01/mrs/sub-01_task-pain_events.tsv

```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/ds-mrs_fmrs/sub-01_NA_NA_task-pain_unified.json>`
::::

## Named Sets

Named sets define specific collections of files with predefined names and properties.

::::{card}
:header: <span class="custom-heading"><h4>MTS</h4></span>
:footer: **Required keys:** `T1w`, `MTw`, `PDw`

**Magnetization transfer saturation**

This method is to calculate a semi-quantitative magnetization transfer
saturation index map.
The MTS method involves three sets of anatomical images that differ in terms
of application of a magnetization transfer RF pulse (MTon or MToff) and flip
angle ([Helms et al. 2008](https://doi.org/10.1002/mrm.21732)).


:::{mermaid}
graph TD
    A[MTS] --> B{Named Groups}
    B --> C[T1w]
    C --> D[.nii/.nii.gz]
    C --> E[.json]
    B --> F[MTw]
    F --> G[.nii/.nii.gz]
    F --> H[.json]
    B --> I[PDw]
    I --> J[.nii/.nii.gz]
    I --> K[.json]
    classDef mainNode fill:#e1f5fe
    classDef groupNode fill:#fff3e0
    classDef fileNode fill:#f3e5f5
    classDef requiredNode fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    class A mainNode
    class B groupNode
    class C,F,I requiredNode
    class D,E,G,H,J,K fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

| Key | Description | Entity-based mapping |
|------|-------------|------------|
| T1w | T1-weighted image assuming flip-02 is the larger flip angle | flip: flip-02, mtransfer: mt-off |
| MTw | Magnetization transfer weighted image of the PD pair. | flip: flip-01, mtransfer: mt-on |
| PDw | Proton density weighted image assuming flip-01 is the lower flip angle | flip: flip-01, mtransfer: mt-off |

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  bids_channel['MTS']['T1w']['nii']
  bids_channel['MTS']['T1w']['json']
  bids_channel['MTS']['MTw']['nii']
  bids_channel['MTS']['MTw']['json']
  bids_channel['MTS']['PDw']['nii']
  bids_channel['MTS']['PDw']['json']
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/ds-mtsat/sub-phantom_ses-rth750rev_run-01_unified.json>`
::::

::::{card}
:header: <span class="custom-heading"><h4>TB1TFL</h4></span>
:footer: **Required keys:** `anat`, `famp`


The result of a Siemens `tfl_b1_map` product sequence.
This sequence produces two images.
The first image appears like an anatomical image and the second output is a
scaled flip angle map.


:::{mermaid}
graph TD
    A[TB1TFL] --> B{Named Groups}
    B --> C[anat]
    C --> D[.nii/.nii.gz]
    C --> E[.json]
    B --> F[famp]
    F --> G[.nii/.nii.gz]
    F --> H[.json]
    classDef mainNode fill:#e1f5fe
    classDef groupNode fill:#fff3e0
    classDef fileNode fill:#f3e5f5
    classDef requiredNode fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    class A mainNode
    class B groupNode
    class C,F requiredNode
    class D,E,G,H fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

| Key | Description | Entity-based mapping |
|------|-------------|------------|
| anat | Anatomical-like image generated by the tfl_b1_map product sequence | acquisition: acq-anat |
| famp | scaled flip angle map | acquisition: acq-famp |

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  bids_channel['TB1TFL']['anat']['nii']
  bids_channel['TB1TFL']['anat']['json']
  bids_channel['TB1TFL']['famp']['nii']
  bids_channel['TB1TFL']['famp']['json']
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_tb1tfl/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading"><h4>TB1AFI</h4></span>
:footer: **Required keys:** `tr1`, `tr2`


This method ([Yarnykh 2007](https://doi.org/10.1002/mrm.21120))
calculates a B1<sup>+</sup> map from two images acquired at interleaved (two)
TRs with identical RF pulses using a steady-state sequence.


:::{mermaid}
graph TD
    A[TB1AFI] --> B{Named Groups}
    B --> C[tr1]
    C --> D[.nii/.nii.gz]
    C --> E[.json]
    B --> F[tr2]
    F --> G[.nii/.nii.gz]
    F --> H[.json]
    classDef mainNode fill:#e1f5fe
    classDef groupNode fill:#fff3e0
    classDef fileNode fill:#f3e5f5
    classDef requiredNode fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    class A mainNode
    class B groupNode
    class C,F requiredNode
    class D,E,G,H fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

| Key | Description | Entity-based mapping |
|------|-------------|------------|
| tr1 | Image from the first interleaved TR of the AFI sequence | acquisition: acq-tr1 |
| tr2 | Image from the second interleaved TR of the AFI sequence | acquisition: acq-tr2 |

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  bids_channel['TB1AFI']['tr1']['nii']
  bids_channel['TB1AFI']['tr1']['json']
  bids_channel['TB1AFI']['tr2']['nii']
  bids_channel['TB1AFI']['tr2']['json']
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_vfa/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading"><h4>RB1COR</h4></span>
:footer: **Required keys:** `bodyMTw`, `bodyT1w`, `bodyPDw`, `headMTw`, `headT1w`, `headPDw`


Low resolution images acquired by the body coil
(in the gantry of the scanner) and the head coil using identical acquisition
parameters to generate a combined sensitivity map as described in
[Papp et al. (2016)](https://doi.org/10.1002/mrm.26058).


:::{mermaid}
graph TD
    A[RB1COR] --> B{Named Groups}
    B --> C[bodyMTw]
    C --> D[.nii/.nii.gz]
    C --> E[.json]
    B --> F[bodyT1w]
    F --> G[.nii/.nii.gz]
    F --> H[.json]
    B --> I[bodyPDw]
    I --> J[.nii/.nii.gz]
    I --> K[.json]
    B --> L[headMTw]
    L --> M[.nii/.nii.gz]
    L --> N[.json]
    B --> O[headT1w]
    O --> P[.nii/.nii.gz]
    O --> Q[.json]
    B --> R[headPDw]
    R --> S[.nii/.nii.gz]
    R --> T[.json]
    classDef mainNode fill:#e1f5fe
    classDef groupNode fill:#fff3e0
    classDef fileNode fill:#f3e5f5
    classDef requiredNode fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    class A mainNode
    class B groupNode
    class C,F,I,L,O,R requiredNode
    class D,E,G,H,J,K,M,N,P,Q,S,T fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

| Key | Description | Entity-based mapping |
|------|-------------|------------|
| bodyMTw | MTw B1- field from the body coil | acquisition: acq-bodyMTw |
| bodyT1w | T1w B1- field from the body coil | acquisition: acq-bodyT1w |
| bodyPDw | PDw B1- field from the body coil | acquisition: acq-bodyPDw |
| headMTw | MTw B1- field from the head coil | acquisition: acq-headMTw |
| headT1w | T1w B1- field from the head coil | acquisition: acq-headT1w |
| headPDw | PDw B1- field from the head coil | acquisition: acq-headPDw |

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  bids_channel['RB1COR']['bodyMTw']['nii']
  bids_channel['RB1COR']['bodyMTw']['json']
  bids_channel['RB1COR']['bodyT1w']['nii']
  bids_channel['RB1COR']['bodyT1w']['json']
  bids_channel['RB1COR']['bodyPDw']['nii']
  bids_channel['RB1COR']['bodyPDw']['json']
  bids_channel['RB1COR']['headMTw']['nii']
  bids_channel['RB1COR']['headMTw']['json']
  bids_channel['RB1COR']['headT1w']['nii']
  bids_channel['RB1COR']['headT1w']['json']
  bids_channel['RB1COR']['headPDw']['nii']
  bids_channel['RB1COR']['headPDw']['json']
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_mpm/sub-01_NA_NA_unified.json>`
::::

## Sequential Sets

Sequential sets define collections of files organized by BIDS entities.

::::{card}
:header: <span class="custom-heading-2"><h4>VFA</h4></span>
:footer: **Entity: `flip`**

**Variable flip angle**

The VFA method involves at least two spoiled gradient echo (SPGR) of
steady-state free precession (SSFP) images acquired at different flip angles.
Depending on the provided metadata fields and the sequence type,
data may be eligible for DESPOT1, DESPOT2 and their variants
([Deoni et al. 2005](https://doi.org/10.1002/mrm.20314)).


:::{mermaid}
graph TD
    A[VFA] --> B{Sequential Collection}
    B --> C[Organized by flip]
    C --> D[Index 0]
    C --> E[Index 1]
    C --> F[Index ...]
    D --> G[.nii/.nii.gz]
    D --> H[.json]
    E --> I[.nii/.nii.gz]
    E --> J[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef entityNode fill:#e8f5e8
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C entityNode
    class D,E,F indexNode
    class G,H,I,J fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Get number of items in sequential set
  bids_channel['VFA']['nii'].size()
  // Access first item
  bids_channel['VFA']['nii'][0]
  bids_channel['VFA']['json'][0]
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_vfa/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-2"><h4>IRT1</h4></span>
:footer: **Entity: `inversion`**

**Inversion recovery T1 mapping**

The IRT1 method involves multiple inversion recovery spin-echo images
acquired at different inversion times
([Barral et al. 2010](https://doi.org/10.1002/mrm.22497)).


:::{mermaid}
graph TD
    A[IRT1] --> B{Sequential Collection}
    B --> C[Organized by inversion]
    C --> D[Index 0]
    C --> E[Index 1]
    C --> F[Index ...]
    D --> G[.nii/.nii.gz]
    D --> H[.json]
    E --> I[.nii/.nii.gz]
    E --> J[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef entityNode fill:#e8f5e8
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C entityNode
    class D,E,F indexNode
    class G,H,I,J fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Get number of items in sequential set
  bids_channel['IRT1']['nii'].size()
  // Access first item
  bids_channel['IRT1']['nii'][0]
  bids_channel['IRT1']['json'][0]
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_irt1/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-2"><h4>TB1DAM</h4></span>
:footer: **Entity: `flip`**


The double-angle B1<sup>+</sup> method
([Insko and Bolinger 1993](https://doi.org/10.1006/jmra.1993.1133)) is based
on the calculation of the actual angles from signal ratios,
collected by two acquisitions at different nominal excitation flip angles.
Common sequence types for this application include spin echo and echo planar
imaging.


:::{mermaid}
graph TD
    A[TB1DAM] --> B{Sequential Collection}
    B --> C[Organized by flip]
    C --> D[Index 0]
    C --> E[Index 1]
    C --> F[Index ...]
    D --> G[.nii/.nii.gz]
    D --> H[.json]
    E --> I[.nii/.nii.gz]
    E --> J[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef entityNode fill:#e8f5e8
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C entityNode
    class D,E,F indexNode
    class G,H,I,J fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Get number of items in sequential set
  bids_channel['TB1DAM']['nii'].size()
  // Access first item
  bids_channel['TB1DAM']['nii'][0]
  bids_channel['TB1DAM']['json'][0]
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_mtsat/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-2"><h4>MEGRE</h4></span>
:footer: **Entity: `echo`**

**Multi-echo Gradient Recalled Echo**

Anatomical gradient echo images acquired at different echo times.
Please note that this suffix is not intended for the logical grouping of
images acquired using an Echo Planar Imaging (EPI) readout.


:::{mermaid}
graph TD
    A[MEGRE] --> B{Sequential Collection}
    B --> C[Organized by echo]
    C --> D[Index 0]
    C --> E[Index 1]
    C --> F[Index ...]
    D --> G[.nii/.nii.gz]
    D --> H[.json]
    E --> I[.nii/.nii.gz]
    E --> J[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef entityNode fill:#e8f5e8
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C entityNode
    class D,E,F indexNode
    class G,H,I,J fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Get number of items in sequential set
  bids_channel['MEGRE']['nii'].size()
  // Access first item
  bids_channel['MEGRE']['nii'][0]
  bids_channel['MEGRE']['json'][0]
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_megre/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-2"><h4>MESE</h4></span>
:footer: **Entity: `echo`**

**Multi-echo Spin Echo**

The MESE method involves multiple spin echo images acquired at different echo
times and is primarily used for T2 mapping.
Please note that this suffix is not intended for the logical grouping of
images acquired using an Echo Planar Imaging (EPI) readout.


:::{mermaid}
graph TD
    A[MESE] --> B{Sequential Collection}
    B --> C[Organized by echo]
    C --> D[Index 0]
    C --> E[Index 1]
    C --> F[Index ...]
    D --> G[.nii/.nii.gz]
    D --> H[.json]
    E --> I[.nii/.nii.gz]
    E --> J[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef entityNode fill:#e8f5e8
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C entityNode
    class D,E,F indexNode
    class G,H,I,J fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Get number of items in sequential set
  bids_channel['MESE']['nii'].size()
  // Access first item
  bids_channel['MESE']['nii'][0]
  bids_channel['MESE']['json'][0]
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_mese/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-2"><h4>TB1SRGE</h4></span>
:footer: **Entities: `flip`, `inversion` (hierarchical order)**


Saturation-prepared with 2 rapid gradient echoes (SA2RAGE) uses a ratio of
two saturation recovery images with different time delays,
and a simulated look-up table to estimate B1+
([Eggenschwiler et al. 2011](https://doi.org/10.1002/mrm.23145)).
This sequence can also be used in conjunction with MP2RAGE T1 mapping to
iteratively improve B1+ and T1 map estimation
([Marques & Gruetter 2013](https://doi.org/10.1371/journal.pone.0069294)).


:::{mermaid}
graph TD
    A[TB1SRGE] --> B{Sequential Collection}
    B --> C[flip dimension]
    C --> D[flip=1]
    C --> E[flip=2]
    D --> F[inversion=1]
    D --> G[inversion=2]
    E --> H[inversion=1]
    E --> I[inversion=2]
    F --> J[.nii/.nii.gz]
    F --> K[.json]
    G --> L[.nii/.nii.gz]
    G --> M[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef entityNode fill:#e8f5e8
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C entityNode
    class D,E,F,G,H,I indexNode
    class J,K,L,M fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Multiple entities organized by: flip, inversion
  // First dimension: flip, Second dimension: inversion
  // Get size of first dimension (flip)
  bids_channel['TB1SRGE']['nii'].size()
  // Get size of second dimension (inversion) for first flip
  bids_channel['TB1SRGE']['nii'][0].size()
  // Access first item
  bids_channel['TB1SRGE']['nii'][0][0]
  bids_channel['TB1SRGE']['json'][0][0]
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_sa2rage/sub-01_NA_NA_unified.json>`
::::

::::{card}
:header: <span class="custom-heading-2"><h4>TB1EPI</h4></span>
:footer: **Entities: `echo`, `flip` (hierarchical order)**


This B1<sup>+</sup> mapping method
([Jiru and Klose 2006](https://doi.org/10.1002/mrm.21083)) is based on two
EPI readouts to acquire spin echo (SE) and stimulated echo (STE) images at
multiple flip angles in one sequence, used in the calculation of deviations
from the nominal flip angle.


:::{mermaid}
graph TD
    A[TB1EPI] --> B{Sequential Collection}
    B --> C[echo dimension]
    C --> D[echo=1]
    C --> E[echo=2]
    D --> F[flip=1]
    D --> G[flip=2]
    E --> H[flip=1]
    E --> I[flip=2]
    F --> J[.nii/.nii.gz]
    F --> K[.json]
    G --> L[.nii/.nii.gz]
    G --> M[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef entityNode fill:#e8f5e8
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C entityNode
    class D,E,F,G,H,I indexNode
    class J,K,L,M fileNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Multiple entities organized by: echo, flip
  // First dimension: echo, Second dimension: flip
  // Get size of first dimension (echo)
  bids_channel['TB1EPI']['nii'].size()
  // Get size of second dimension (flip) for first echo
  bids_channel['TB1EPI']['nii'][0].size()
  // Access first item
  bids_channel['TB1EPI']['nii'][0][0]
  bids_channel['TB1EPI']['json'][0][0]
```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_mpm/sub-01_NA_NA_unified.json>`
::::

## Mixed Sets

Mixed sets combine named groups with sequential organization within each group.

::::{card}
:header: <span class="custom-heading-3"><h4>MPM</h4></span>
:footer: **Named: `acquisition`, Sequential: `echo`**

**Multi-parametric Mapping**

The MPM approaches (a.k.a hMRI) involves the acquisition of highly-similar
anatomical images that differ in terms of application of a magnetization
transfer RF pulse (MTon or MToff), flip angle and (optionally) echo time and
magnitue/phase parts
([Weiskopf et al. 2013](https://doi.org/10.3389/fnins.2013.00095)).
See [here](https://owncloud.gwdg.de/index.php/s/iv2TOQwGy4FGDDZ) for
suggested MPM acquisition protocols.


:::{mermaid}
graph TD
    A[MPM] --> B{Mixed Collection}
    B --> C[Named: acquisition]
    B --> D[Sequential: echo]
    C --> E[MTw]
    E --> F[Sequential files]
    F --> G[Index 0]
    F --> H[Index 1]
    G --> I[.nii/.nii.gz]
    G --> J[.json]
    C --> K[PDw]
    K --> L[Sequential files]
    L --> M[Index 0]
    L --> N[Index 1]
    M --> O[.nii/.nii.gz]
    M --> P[.json]
    C --> Q[T1w]
    Q --> R[Sequential files]
    R --> S[Index 0]
    R --> T[Index 1]
    S --> U[.nii/.nii.gz]
    S --> V[.json]
    classDef mainNode fill:#e1f5fe
    classDef collectionNode fill:#fff3e0
    classDef dimensionNode fill:#e8f5e8
    classDef groupNode fill:#fce4ec
    classDef requiredNode fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    classDef seqNode fill:#f1f8e9
    classDef indexNode fill:#fce4ec
    classDef fileNode fill:#f3e5f5
    class A mainNode
    class B collectionNode
    class C,D dimensionNode
    class E,K,Q groupNode
:::

[⌬ Hover to see the diagram legend](#mermaidlegend)

| Named Group | Description | Entity-based mapping |
|-------------|-------------|------------|
| MTw | Magnetization transfer weighted images | acquisition: acq-MTw, flip: flip-1, mtransfer: mt-on |
| PDw | Proton density weighted images | acquisition: acq-PDw, flip: flip-1, mtransfer: mt-off |
| T1w | T1-weighted images | acquisition: acq-T1w, flip: flip-2, mtransfer: mt-off |

**Required groups:** None

:::{seealso} Example usage within a process
:class: dropdown
```groovy
  // Access MTw group:
  bids_channel['MPM']['MTw']['nii'].size()
  bids_channel['MPM']['MTw']['nii'][0]
  bids_channel['MPM']['MTw']['json'][0]

  // Access PDw group:
  bids_channel['MPM']['PDw']['nii'].size()
  bids_channel['MPM']['PDw']['nii'][0]
  bids_channel['MPM']['PDw']['json'][0]

  // Access T1w group:
  bids_channel['MPM']['T1w']['nii'].size()
  bids_channel['MPM']['T1w']['nii'][0]
  bids_channel['MPM']['T1w']['json'][0]

```
:::
{button}`Example channel data structure <https://github.com/agahkarakuzu/bids2nf/blob/main/tests/expected_outputs/qmri_mpm/sub-01_NA_NA_unified.json>`
::::

::::{admonition} Mermaid Diagram Legend
:label: mermaidlegend
:class: tip

Understanding the symbols and connections in the diagrams above:

:::{mermaid}
graph LR
    A[Suffix/Node] --> B[Required File]
    A -.-> C[Optional File]
    D[Cross-modal Input] ==> A
    D --> E[Required File]
    D -.-> F[Optional File]
    classDef mainNode fill:#e1f5fe
    classDef fileNode fill:#f3e5f5
    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5
    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px
    class A mainNode
    class B,E fileNode
    class C,F optionalNode
    class D crossModalNode
:::

**Line Types:**
- **Solid arrows (→)**: Required files that are always expected
- **Dashed arrows (-.->)**: Optional files that may or may not be present
- **Thick arrows (==>)**: Cross-modal relationships (data from other suffixes)

**Node Colors:**
- **Light blue**: Main suffix/node
- **Light purple**: File extensions
- **Light orange with orange border**: Cross-modal input nodes
::::

---

*This documentation is automatically generated from `bids2nf.yaml`.*