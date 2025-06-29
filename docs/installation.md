# Installation

::::{danger} Prerequisites
:class: dropdown
:label: prereq

## Prerequisites

## 🔀 Install Nextflow
Follow the [Nextflow installation guide](https://www.nextflow.io/docs/stable/install.html).

## 🐳 Pull Docker image for the BIDS Validator (optional)

Download a Nextflow-compatible BIDS Validator image tailored to your system architecture:

* Standard Unix systems (`amd64`)
```
docker pull agahkarakuzu/bids-validator-amd64
```

* Apple silicon (`arm64`)
```
docker pull agahkarakuzu/bids-validator-arm64
```

:::{note}
By default, `bids2nf` validates your BIDS dataset. You can configure it to use a local installation of [`bids-validator`](https://bids-validator.readthedocs.io/en/stable/), or disable validation entirely if preferred.
:::
::::

:::{warning} 🍎 Important warning for macOS users
:icon: false
:class: dropdown

The default bash version on macOS does not meet `libBIDS` requirements. Install a newer bash with Homebrew:

```bash
brew install bash
```

Then set `process.shell` in your `nextflow.config` to:
- Apple Silicon: `/opt/homebrew/bin/bash`
- Intel Macs: `/usr/local/bin/bash`
:::


## 🧠 Get bids2nf

After installing the [prerequisites](#prereq), simply clone this repository with its submodules:

```bash
git clone --recurse-submodules https://github.com/agahkarakuzu/bids2nf.git
```

### Submodules included

:::::{grid} 1 1 2 2
::::{card} `libBIDS.sh`
:link: https://github.com/CoBrALab/libBIDS.sh

A Bash library for parsing and processing BIDS datasets into CSV-like structures, enabling flexible data filtering, extraction, and iteration within shell scripts.

:::{image} https://avatars.githubusercontent.com/u/8516777?s=200&v=4
:height: 100
:align: center
:::
::::

::::{card} `BIDS examples`
:link: https://github.com/bids-standard/bids-examples
A set of BIDS compatible datasets with empty raw data files that can be used for writing lightweight software tests.

:::{image} https://upload.wikimedia.org/wikipedia/commons/d/de/BIDS_Logo.png
:height: 100
:align: center
:::

::::

:::::

# What's Next?

- Learn about [project basics](basics.md) and how bids2nf works
- Understand [configuration](configuration.md) with named sets vs sequential sets
- Explore [examples](examples.md) for common usage patterns