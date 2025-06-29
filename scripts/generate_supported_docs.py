#!/usr/bin/env python3
"""
Generate supported.md documentation from bids2nf.yaml configuration.
"""

import yaml
import argparse
from pathlib import Path


def generate_supported_docs(yaml_file: Path, output_file: Path):
    """Generate supported.md from bids2nf.yaml configuration."""
    
    with open(yaml_file, 'r') as f:
        config = yaml.safe_load(f)
    
    content = []
    content.append("# Supported BIDS Data Types")
    content.append("")
    content.append("This page documents the BIDS data types supported by bids2nf.")
    content.append("")
    
    # Process named sets
    named_sets = []
    sequential_sets = []
    
    for key, value in config.items():
        if 'named_set' in value:
            named_sets.append((key, value))
        elif 'sequential_set' in value:
            sequential_sets.append((key, value))
    
    if named_sets:
        content.append("## Named Sets")
        content.append("")
        content.append("Named sets define specific collections of files with predefined names and properties.")
        content.append("")
        
        for name, config_data in named_sets:
            content.append(f"### {name}")
            content.append("")
            
            named_set = config_data['named_set']
            required = config_data.get('required', [])
            
            content.append(f"**Required files:** {', '.join(required)}")
            content.append("")
            
            content.append("| File | Description | Properties |")
            content.append("|------|-------------|------------|")
            
            for file_key, file_config in named_set.items():
                description = file_config.get('description', 'No description')
                
                # Extract properties (excluding description)
                properties = []
                for prop_key, prop_value in file_config.items():
                    if prop_key != 'description':
                        properties.append(f"{prop_key}: {prop_value}")
                
                properties_str = ', '.join(properties) if properties else 'None'
                content.append(f"| {file_key} | {description} | {properties_str} |")
            
            content.append("")
    
    if sequential_sets:
        content.append("## Sequential Sets")
        content.append("")
        content.append("Sequential sets define collections of files organized by BIDS entities.")
        content.append("")
        
        for name, config_data in sequential_sets:
            content.append(f"### {name}")
            content.append("")
            
            sequential_set = config_data['sequential_set']
            
            if 'by_entity' in sequential_set:
                entity = sequential_set['by_entity']
                content.append(f"**Organized by entity:** {entity}")
            elif 'by_entities' in sequential_set:
                entities = sequential_set['by_entities']
                order = sequential_set.get('order', 'sequential')
                content.append(f"**Organized by entities:** {', '.join(entities)} ({order} order)")
            
            content.append("")
    
    content.append("---")
    content.append("")
    content.append("*This documentation is automatically generated from `bids2nf.yaml`.*")
    
    # Write to output file
    with open(output_file, 'w') as f:
        f.write('\n'.join(content))


def main():
    parser = argparse.ArgumentParser(description='Generate supported.md from bids2nf.yaml')
    parser.add_argument('--yaml-file', type=Path, default='bids2nf.yaml',
                       help='Path to bids2nf.yaml file')
    parser.add_argument('--output-file', type=Path, default='docs/supported.md',
                       help='Path to output supported.md file')
    
    args = parser.parse_args()
    
    if not args.yaml_file.exists():
        print(f"Error: {args.yaml_file} not found")
        return 1
    
    # Ensure output directory exists
    args.output_file.parent.mkdir(parents=True, exist_ok=True)
    
    generate_supported_docs(args.yaml_file, args.output_file)
    print(f"Generated {args.output_file} from {args.yaml_file}")
    
    return 0


if __name__ == '__main__':
    exit(main())