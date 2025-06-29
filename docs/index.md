---
title: About
---

::::{aside}
:::{image} ../logo.png
:width: 200
:align: center
:::

:::{image} ../nfneuro.svg
:width: 150
:align: center
:background-color: black
:::
::::

**bids2nf** is a Nextflow-native utility that ingests BIDS (Brain Imaging Data Structure) datasets and emits Nextflow channels for seamless integration into your neuroimaging pipelines. For parsing, it leverages [libBIDS.sh](https://github.com/CoBrALab/libBIDS.sh), a lightweight, shell-based BIDS parser.

::::{grid} 1 1 2 3

:::{card}
:header: 🪶 Lightweight
Minimal dependencies with [shell-based BIDS parsing](https://github.com/CoBrALab/libBIDS.sh) for fast, efficient processing.
:::

:::{card}
:header: 🔀 Nextflow native
Built with [Nextflow](https://nextflow.io) DSL2 modularity in mind, enabling neuroimaging researchers to leverage scalable, reproducible workflows.
:::

:::{card}
:header: 🧩 Customizable
Though [BIDS-first](https://bids-specification.readthedocs.io/en/stable/), bids2nf is highly configurable and can be adapted to work with custom dataset structures beyond strict BIDS compliance.
:::
::::

:::{seealso} Reference
Implementation of `bids2nf` adheres to the design principles of modular and portable neuroimaging pipelines as described in [](https://doi.org/10.1007/s10334-025-01245-3)

Built with [nf-neuro](https://scilus.github.io/nf-neuro) in mind.
:::