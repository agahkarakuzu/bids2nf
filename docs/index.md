---
title: About
---

::::{aside}
:::{image} ../assets/logo.svg
:width: 200
:align: center
:::

:::{image} https://upload.wikimedia.org/wikipedia/commons/d/de/BIDS_Logo.png
:width: 150
:align: center
:::

:::{image} https://upload.wikimedia.org/wikipedia/commons/e/e1/Logo_Nextflow_%28new%29.png
:width: 150
:align: center
:::
::::

**bids2nf** is a lightweight utility that parses BIDS (Brain Imaging Data Structure) datasets and emits structured Nextflow [channels](https://www.nextflow.io/docs/latest/channel.html). These channels provide a standardized interface for building scalable, modular, and reproducible neuroimaging workflows with [Nextflow](https://nextflow.io).

::::{grid} 1 1 2 3

:::{card}
:header: 📺 Tune In

Point to your BIDS directory and get clean, organized dataflow channels instantly. Focus on stitching together your workflow, not wrestling with regex patterns and file pairings.
:::

:::{card}
:header: ⚡ Zero Bloat, All Flow
Ultra-lightweight with shell-based parsing and minimal dependencies. Built for speed, portability, and easy integration into any neuroimaging task. 
:::

:::{card}
:header: 🔧 Flexible by Design
Strict BIDS? Custom hacks? Either way, bids2nf adapts. Configure channels to match your data, your logic, your workflow.
:::
::::

:::{card} 🧠 Nextflow: A Declarative Powerhouse
Think single-subject analysis. Nextflow scales it automatically across subjects, sessions, and runs (and whatever else you need). No loops, no batch scripts, no infrastructure headaches. Your analysis code stays clean while Nextflow handles parallelization, container mediation, and compute resource maping.
:::

::::{seealso} Reference article
Implementation of `bids2nf` adheres to the design principles of modular and portable neuroimaging pipelines as described in [](https://doi.org/10.1007/s10334-025-01245-3)

::::


::::{card}
:link: https://scilus.github.io/nf-neuro/
:footer: This package is part of the nf-neuro initiative, a community effort to develop reproducible and scalable neuroimaging workflows.
:align: center

:::{image} ../nfneuro.svg
:width: 150
:align: center
:::
::::


