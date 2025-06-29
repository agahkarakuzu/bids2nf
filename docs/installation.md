# Installation

## Prerequisites

1. **Install Nextflow**  
   Follow the [Nextflow installation guide](https://www.nextflow.io/docs/stable/install.html).

## Get bids2nf

Clone this repository with its submodules:

```bash
git clone --recurse-submodules https://github.com/agahkarakuzu/bids2nf.git
```

**Submodules included:**
- [CoBrALab/libBIDS.sh](https://github.com/CoBrALab/libBIDS.sh) (for parsing BIDS)
- [bids-examples](https://github.com/bids-standard/bids-examples) (for testing purposes)

:::{warning} macOS users
The default bash version on macOS does not meet libBIDS requirements. Install a newer bash with Homebrew:

```bash
brew install bash
```

Then set `process.shell` in your `nextflow.config` to:
- Apple Silicon: `/opt/homebrew/bin/bash`
- Intel Macs: `/usr/local/bin/bash`
:::

# Quick Start

1. **Prepare your BIDS dataset** in a directory
2. **Configure** your `bids2nf.yaml` file  
3. **Run your Nextflow pipeline:**
   ```bash
   nextflow run main.nf --bids_dir /path/to/bids_dataset
   ```

# What's Next?

- Learn about [project basics](basics.md) and how bids2nf works
- Understand [configuration](configuration.md) with named sets vs sequential sets
- Explore [examples](examples.md) for common usage patterns