import os
import argparse
from pathlib import Path

def create_phantom_structure(source_dir, phantom_root):
    source_dir = Path(source_dir).resolve()
    phantom_root = Path(phantom_root).resolve()

    for root, dirs, files in os.walk(source_dir):
        rel_path = Path(root).relative_to(source_dir)
        phantom_path = phantom_root / rel_path

        # Create the phantom directory
        phantom_path.mkdir(parents=True, exist_ok=True)

        # Create phantom files
        for file_name in files:
            phantom_file = phantom_path / file_name
            phantom_file.touch(exist_ok=True)

def main():
    parser = argparse.ArgumentParser(description="Create phantom copy of a directory structure.")
    parser.add_argument("source", help="Path to the source directory.")
    parser.add_argument("phantom", help="Path where phantom structure will be created.")
    args = parser.parse_args()

    if not os.path.isdir(args.source):
        print(f"Error: Source directory {args.source} does not exist or is not a directory.")
        return

    create_phantom_structure(args.source, args.phantom)
    print(f"Phantom structure created at {args.phantom}")

if __name__ == "__main__":
    main()
