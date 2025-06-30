#!/usr/bin/env python3
"""
Generate supported.md documentation from bids2nf.yaml configuration.
"""

import yaml
import argparse
import requests
import json
from pathlib import Path


def fetch_bids_suffixes():
    """Fetch suffix information from BIDS specification."""
    url = "https://raw.githubusercontent.com/bids-standard/bids-specification/refs/heads/master/src/schema/objects/suffixes.yaml"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return yaml.safe_load(response.text)
    except Exception as e:
        print(f"Warning: Could not fetch BIDS suffixes schema: {e}")
        return {}


def generate_supported_docs(yaml_file: Path, output_file: Path):
    """Generate supported.md from bids2nf.yaml configuration."""
    
    with open(yaml_file, 'r') as f:
        config = yaml.safe_load(f)
    
    # Fetch BIDS suffixes information
    bids_suffixes = fetch_bids_suffixes()
    
    content = []
    content.append("# Supported BIDS suffixes")
    content.append("")
    content.append("This page documents the BIDS suffixes currently supported by bids2nf.")
    content.append("")
    
    # Process named sets
    named_sets = []
    sequential_sets = []
    mixed_sets = []
    
    for key, value in config.items():
        if 'named_set' in value:
            named_sets.append((key, value))
        elif 'sequential_set' in value:
            sequential_sets.append((key, value))
        elif 'mixed_set' in value:
            mixed_sets.append((key, value))
    
    if named_sets:
        content.append("## Named Sets")
        content.append("")
        content.append("Named sets define specific collections of files with predefined names and properties.")
        content.append("")
        
        for name, config_data in named_sets:
            # Get BIDS suffix information
            suffix_info = bids_suffixes.get(name, {})
            display_name = suffix_info.get('display_name', name)
            description = suffix_info.get('description', '')
            
            named_set = config_data['named_set']
            required = config_data.get('required', [])
            
            # Format required files for footer
            required_str = ', '.join([f"`{req}`" for req in required]) if required else "None"
            
            content.append("::::{card}")
            content.append(f":header: <span class=\"custom-heading\"><h4>{name}</h4></span>")
            content.append(f":footer: **Required keys:** {required_str}")
            content.append("")
            
            if description:
                if display_name != name:
                    content.append(f"**{display_name}**")
                content.append("")
                content.append(description)
                content.append("")
            
            content.append("| Key | Description | Entity-based mapping |")
            content.append("|------|-------------|------------|")
            
            for file_key, file_config in named_set.items():
                file_description = file_config.get('description', 'No description')
                
                # Extract properties (excluding description)
                properties = []
                for prop_key, prop_value in file_config.items():
                    if prop_key != 'description':
                        properties.append(f"{prop_key}: {prop_value}")
                
                properties_str = ', '.join(properties) if properties else 'None'
                content.append(f"| {file_key} | {file_description} | {properties_str} |")
            
            content.append("")
            content.append(":::{seealso} Example usage within a process")
            content.append(":class: dropdown")
            content.append("```groovy")
            
            # Try to load actual example data from JSON file
            if 'example_output' in config_data:
                example_file = Path(config_data['example_output'])
                if example_file.exists():
                    try:
                        with open(example_file, 'r') as f:
                            example_data = json.load(f)
                        
                        if 'data' in example_data and name in example_data['data']:
                            suffix_data = example_data['data'][name]
                            # Show actual structure from JSON
                            for file_key, file_data in suffix_data.items():
                                if isinstance(file_data, dict):
                                    content.append(f"  // Access {file_key} files:")
                                    content.append(f"  bids_channel['{name}']['{file_key}']['nii']")
                                    if 'nii' in file_data:
                                        content.append(f"  // → {file_data['nii']}")
                                    content.append(f"  bids_channel['{name}']['{file_key}']['json']")
                                    if 'json' in file_data:
                                        content.append(f"  // → {file_data['json']}")
                                    content.append("")
                        else:
                            # Fallback to generic example
                            for file_key in named_set.keys():
                                content.append(f"  bids_channel['{name}']['{file_key}']['nii']")
                                content.append(f"  bids_channel['{name}']['{file_key}']['json']")
                    except (json.JSONDecodeError, FileNotFoundError):
                        # Fallback to generic example
                        for file_key in named_set.keys():
                            content.append(f"  bids_channel['{name}']['{file_key}']['nii']")
                            content.append(f"  bids_channel['{name}']['{file_key}']['json']")
                else:
                    # Fallback to generic example
                    for file_key in named_set.keys():
                        content.append(f"  bids_channel['{name}']['{file_key}']['nii']")
                        content.append(f"  bids_channel['{name}']['{file_key}']['json']")
            else:
                # Fallback to generic example
                for file_key in named_set.keys():
                    content.append(f"  bids_channel['{name}']['{file_key}']['nii']")
                    content.append(f"  bids_channel['{name}']['{file_key}']['json']")
            
            content.append("```")
            content.append(":::")
            if 'example_output' in config_data:
                tmp_url = f"https://github.com/agahkarakuzu/bids2nf/blob/main/{config_data['example_output']}"
                content.append(f"{{button}}`Example channel data structure <{tmp_url}>`")
            content.append("::::")
            content.append("")
    
    if sequential_sets:
        content.append("## Sequential Sets")
        content.append("")
        content.append("Sequential sets define collections of files organized by BIDS entities.")
        content.append("")
        
        for name, config_data in sequential_sets:
            # Get BIDS suffix information
            suffix_info = bids_suffixes.get(name, {})
            display_name = suffix_info.get('display_name', name)
            description = suffix_info.get('description', '')
            
            sequential_set = config_data['sequential_set']
            required = config_data.get('required', [])
            
            # Format organization info for footer
            organization_info = []
            if 'by_entity' in sequential_set:
                entity = sequential_set['by_entity']
                organization_info.append(f"Entity: `{entity}`")
            elif 'by_entities' in sequential_set:
                entities = sequential_set['by_entities']
                order = sequential_set.get('order', 'sequential')
                organization_info.append(f"Entities: {', '.join([f'`{e}`' for e in entities])} ({order} order)")
            
            # Format required files for footer
            required_str = ', '.join([f"`{req}`" for req in required]) if required else "None"
            if organization_info:
                footer_text = f"**{organization_info[0]}**"
            else:
                footer_text = f"🐈‍⬛"
            
            content.append("::::{card}")
            content.append(f":header: <span class=\"custom-heading-2\"><h4>{name}</h4></span>")
            content.append(f":footer: {footer_text}")
            content.append("")
            
            if description:
                if display_name != name:
                    content.append(f"**{display_name}**")
                content.append("")
                content.append(description)
                content.append("")
            
            content.append("")
            
            content.append(":::{seealso} Example usage within a process")
            content.append(":class: dropdown")
            content.append("```groovy")
            
            # Try to load actual example data from JSON file
            if 'example_output' in config_data:
                example_file = Path(config_data['example_output'])
                if example_file.exists():
                    try:
                        with open(example_file, 'r') as f:
                            example_data = json.load(f)
                        
                        if 'data' in example_data and name in example_data['data']:
                            suffix_data = example_data['data'][name]
                            
                            # Check if data has arrays (sequential) or nested objects
                            if 'nii' in suffix_data and isinstance(suffix_data['nii'], list):
                                # Sequential set with arrays
                                content.append(f"  // Get number of items in sequential set")
                                content.append(f"  bids_channel['{name}']['nii'].size()  // → {len(suffix_data['nii'])}")
                                content.append(f"  // Access first item")
                                content.append(f"  bids_channel['{name}']['nii'][0]")
                                if len(suffix_data['nii']) > 0:
                                    content.append(f"  // → {suffix_data['nii'][0]}")
                                content.append(f"  bids_channel['{name}']['json'][0]")
                                if 'json' in suffix_data and len(suffix_data['json']) > 0:
                                    content.append(f"  // → {suffix_data['json'][0]}")
                                content.append("")
                                # Show a few more items if available
                                if len(suffix_data['nii']) > 1:
                                    content.append(f"  // Access second item")
                                    content.append(f"  bids_channel['{name}']['nii'][1]")
                                    content.append(f"  // → {suffix_data['nii'][1]}")
                                    content.append(f"  bids_channel['{name}']['json'][1]")
                                    if 'json' in suffix_data and len(suffix_data['json']) > 1:
                                        content.append(f"  // → {suffix_data['json'][1]}")
                                    content.append("")
                            elif 'by_entities' in sequential_set:
                                # Multiple entities - check if we have nested arrays
                                entities = sequential_set['by_entities']
                                first_entity = entities[0]
                                second_entity = entities[1] if len(entities) > 1 else None
                                content.append(f"  // Multiple entities organized by: {', '.join(entities)}")
                                content.append(f"  // First dimension: {first_entity}, Second dimension: {second_entity}")
                                content.append(f"  // Get size of first dimension ({first_entity})")
                                content.append(f"  bids_channel['{name}']['nii'].size()")
                                if second_entity:
                                    content.append(f"  // Get size of second dimension ({second_entity}) for first {first_entity}")
                                    content.append(f"  bids_channel['{name}']['nii'][0].size()")
                                content.append(f"  // Access first item")
                                content.append(f"  bids_channel['{name}']['nii'][0][0]")
                                content.append(f"  bids_channel['{name}']['json'][0][0]")
                            else:
                                # Fallback based on sequential_set structure
                                if 'by_entity' in sequential_set:
                                    content.append(f"  // Get number of items in sequential set")
                                    content.append(f"  bids_channel['{name}']['nii'].size()")
                                    content.append(f"  // Access first item")
                                    content.append(f"  bids_channel['{name}']['nii'][0]")
                                    content.append(f"  bids_channel['{name}']['json'][0]")
                                else:
                                    content.append(f"  bids_channel['{name}']['nii']")
                                    content.append(f"  bids_channel['{name}']['json']")
                        else:
                            # Fallback to original logic
                            if 'by_entity' in sequential_set:
                                content.append(f"  // Get number of items in sequential set")
                                content.append(f"  bids_channel['{name}']['nii'].size()")
                                content.append(f"  // Access first item")
                                content.append(f"  bids_channel['{name}']['nii'][0]")
                                content.append(f"  bids_channel['{name}']['json'][0]")
                            elif 'by_entities' in sequential_set:
                                entities = sequential_set['by_entities']
                                first_entity = entities[0]
                                second_entity = entities[1] if len(entities) > 1 else None
                                content.append(f"  // Multiple entities organized by: {', '.join(entities)}")
                                content.append(f"  // First dimension: {first_entity}, Second dimension: {second_entity}")
                                content.append(f"  // Get size of first dimension ({first_entity})")
                                content.append(f"  bids_channel['{name}']['nii'].size()")
                                if second_entity:
                                    content.append(f"  // Get size of second dimension ({second_entity}) for first {first_entity}")
                                    content.append(f"  bids_channel['{name}']['nii'][0].size()")
                                content.append(f"  // Access first item")
                                content.append(f"  bids_channel['{name}']['nii'][0][0]")
                                content.append(f"  bids_channel['{name}']['json'][0][0]")
                            else:
                                content.append(f"  bids_channel['{name}']['nii']")
                                content.append(f"  bids_channel['{name}']['json']")
                    except (json.JSONDecodeError, FileNotFoundError):
                        # Fallback to original logic
                        if 'by_entity' in sequential_set:
                            content.append(f"  // Get number of items in sequential set")
                            content.append(f"  bids_channel['{name}']['nii'].size()")
                            content.append(f"  // Access first item")
                            content.append(f"  bids_channel['{name}']['nii'][0]")
                            content.append(f"  bids_channel['{name}']['json'][0]")
                        elif 'by_entities' in sequential_set:
                            entities = sequential_set['by_entities']
                            first_entity = entities[0]
                            second_entity = entities[1] if len(entities) > 1 else None
                            content.append(f"  // Multiple entities organized by: {', '.join(entities)}")
                            content.append(f"  // First dimension: {first_entity}, Second dimension: {second_entity}")
                            content.append(f"  // Get size of first dimension ({first_entity})")
                            content.append(f"  bids_channel['{name}']['nii'].size()")
                            if second_entity:
                                content.append(f"  // Get size of second dimension ({second_entity}) for first {first_entity}")
                                content.append(f"  bids_channel['{name}']['nii'][0].size()")
                            content.append(f"  // Access first item")
                            content.append(f"  bids_channel['{name}']['nii'][0][0]")
                            content.append(f"  bids_channel['{name}']['json'][0][0]")
                        else:
                            content.append(f"  bids_channel['{name}']['nii']")
                            content.append(f"  bids_channel['{name}']['json']")
                else:
                    # Fallback to original logic
                    if 'by_entity' in sequential_set:
                        content.append(f"  // Get number of items in sequential set")
                        content.append(f"  bids_channel['{name}']['nii'].size()")
                        content.append(f"  // Access first item")
                        content.append(f"  bids_channel['{name}']['nii'][0]")
                        content.append(f"  bids_channel['{name}']['json'][0]")
                    elif 'by_entities' in sequential_set:
                        entities = sequential_set['by_entities']
                        first_entity = entities[0]
                        second_entity = entities[1] if len(entities) > 1 else None
                        content.append(f"  // Multiple entities organized by: {', '.join(entities)}")
                        content.append(f"  // First dimension: {first_entity}, Second dimension: {second_entity}")
                        content.append(f"  // Get size of first dimension ({first_entity})")
                        content.append(f"  bids_channel['{name}']['nii'].size()")
                        if second_entity:
                            content.append(f"  // Get size of second dimension ({second_entity}) for first {first_entity}")
                            content.append(f"  bids_channel['{name}']['nii'][0].size()")
                        content.append(f"  // Access first item")
                        content.append(f"  bids_channel['{name}']['nii'][0][0]")
                        content.append(f"  bids_channel['{name}']['json'][0][0]")
                    else:
                        content.append(f"  bids_channel['{name}']['nii']")
                        content.append(f"  bids_channel['{name}']['json']")
            else:
                # Fallback to original logic
                if 'by_entity' in sequential_set:
                    content.append(f"  // Get number of items in sequential set")
                    content.append(f"  bids_channel['{name}']['nii'].size()")
                    content.append(f"  // Access first item")
                    content.append(f"  bids_channel['{name}']['nii'][0]")
                    content.append(f"  bids_channel['{name}']['json'][0]")
                elif 'by_entities' in sequential_set:
                    entities = sequential_set['by_entities']
                    first_entity = entities[0]
                    second_entity = entities[1] if len(entities) > 1 else None
                    content.append(f"  // Multiple entities organized by: {', '.join(entities)}")
                    content.append(f"  // First dimension: {first_entity}, Second dimension: {second_entity}")
                    content.append(f"  // Get size of first dimension ({first_entity})")
                    content.append(f"  bids_channel['{name}']['nii'].size()")
                    if second_entity:
                        content.append(f"  // Get size of second dimension ({second_entity}) for first {first_entity}")
                        content.append(f"  bids_channel['{name}']['nii'][0].size()")
                    content.append(f"  // Access first item")
                    content.append(f"  bids_channel['{name}']['nii'][0][0]")
                    content.append(f"  bids_channel['{name}']['json'][0][0]")
                else:
                    content.append(f"  bids_channel['{name}']['nii']")
                    content.append(f"  bids_channel['{name}']['json']")
                
            content.append("```")
            content.append(":::")
            if 'example_output' in config_data:
                tmp_url = f"https://github.com/agahkarakuzu/bids2nf/blob/main/{config_data['example_output']}"
                content.append(f"{{button}}`Example channel data structure <{tmp_url}>`")
            content.append("::::")
            content.append("")
    
    if mixed_sets:
        content.append("## Mixed Sets")
        content.append("")
        content.append("Mixed sets combine named groups with sequential organization within each group.")
        content.append("")
        
        for name, config_data in mixed_sets:
            # Get BIDS suffix information
            suffix_info = bids_suffixes.get(name, {})
            display_name = suffix_info.get('display_name', name)
            description = suffix_info.get('description', '')
            
            mixed_set = config_data['mixed_set']
            required = config_data.get('required', [])
            
            # Format organization info for footer
            named_dimension = mixed_set.get('named_dimension', 'acquisition')
            sequential_dimension = mixed_set.get('sequential_dimension', 'echo')
            
            # Format required files for footer
            required_str = ', '.join([f"`{req}`" for req in required]) if required else "None"
            footer_text = f"**Named: `{named_dimension}`, Sequential: `{sequential_dimension}`**"
            
            content.append("::::{card}")
            content.append(f":header: <span class=\"custom-heading-3\"><h4>{name}</h4></span>")
            content.append(f":footer: {footer_text}")
            content.append("")
            
            if description:
                if display_name != name:
                    content.append(f"**{display_name}**")
                content.append("")
                content.append(description)
                content.append("")
            
            # Show named groups table
            content.append("| Named Group | Description | Entity-based mapping |")
            content.append("|-------------|-------------|------------|")
            
            named_groups = mixed_set.get('named_groups', {})
            for group_key, group_config in named_groups.items():
                group_description = group_config.get('description', 'No description')
                
                # Extract properties (excluding description)
                properties = []
                for prop_key, prop_value in group_config.items():
                    if prop_key != 'description':
                        properties.append(f"{prop_key}: {prop_value}")
                
                properties_str = ', '.join(properties) if properties else 'None'
                content.append(f"| {group_key} | {group_description} | {properties_str} |")
            
            content.append("")
            content.append(f"**Required groups:** {required_str}")
            content.append("")
            
            content.append(":::{seealso} Example usage within a process")
            content.append(":class: dropdown")
            content.append("```groovy")
            
            # Try to load actual example data from JSON file
            if 'example_output' in config_data:
                example_file = Path(config_data['example_output'])
                if example_file.exists():
                    try:
                        with open(example_file, 'r') as f:
                            example_data = json.load(f)
                        
                        if 'data' in example_data and name in example_data['data']:
                            suffix_data = example_data['data'][name]
                            
                            # Show examples for each named group
                            for group_key, group_data in suffix_data.items():
                                if isinstance(group_data, dict) and 'nii' in group_data:
                                    content.append(f"  // Access {group_key} group:")
                                    if isinstance(group_data['nii'], list):
                                        # Sequential within the named group
                                        content.append(f"  bids_channel['{name}']['{group_key}']['nii'].size()  // → {len(group_data['nii'])}")
                                        content.append(f"  bids_channel['{name}']['{group_key}']['nii'][0]")
                                        if len(group_data['nii']) > 0:
                                            content.append(f"  // → {group_data['nii'][0]}")
                                        content.append(f"  bids_channel['{name}']['{group_key}']['json'][0]")
                                        if 'json' in group_data and len(group_data['json']) > 0:
                                            content.append(f"  // → {group_data['json'][0]}")
                                        content.append("")
                                        
                                        # Show second item if available
                                        if len(group_data['nii']) > 1:
                                            content.append(f"  // Access second {sequential_dimension} in {group_key}:")
                                            content.append(f"  bids_channel['{name}']['{group_key}']['nii'][1]")
                                            content.append(f"  // → {group_data['nii'][1]}")
                                            content.append(f"  bids_channel['{name}']['{group_key}']['json'][1]")
                                            if 'json' in group_data and len(group_data['json']) > 1:
                                                content.append(f"  // → {group_data['json'][1]}")
                                            content.append("")
                                    else:
                                        # Single file in the named group
                                        content.append(f"  bids_channel['{name}']['{group_key}']['nii']")
                                        content.append(f"  // → {group_data['nii']}")
                                        content.append(f"  bids_channel['{name}']['{group_key}']['json']")
                                        if 'json' in group_data:
                                            content.append(f"  // → {group_data['json']}")
                                        content.append("")
                        else:
                            # Fallback to generic example
                            for group_key in named_groups.keys():
                                content.append(f"  // Access {group_key} group:")
                                content.append(f"  bids_channel['{name}']['{group_key}']['nii'].size()")
                                content.append(f"  bids_channel['{name}']['{group_key}']['nii'][0]")
                                content.append(f"  bids_channel['{name}']['{group_key}']['json'][0]")
                                content.append("")
                    except (json.JSONDecodeError, FileNotFoundError):
                        # Fallback to generic example
                        for group_key in named_groups.keys():
                            content.append(f"  // Access {group_key} group:")
                            content.append(f"  bids_channel['{name}']['{group_key}']['nii'].size()")
                            content.append(f"  bids_channel['{name}']['{group_key}']['nii'][0]")
                            content.append(f"  bids_channel['{name}']['{group_key}']['json'][0]")
                            content.append("")
                else:
                    # Fallback to generic example
                    for group_key in named_groups.keys():
                        content.append(f"  // Access {group_key} group:")
                        content.append(f"  bids_channel['{name}']['{group_key}']['nii'].size()")
                        content.append(f"  bids_channel['{name}']['{group_key}']['nii'][0]")
                        content.append(f"  bids_channel['{name}']['{group_key}']['json'][0]")
                        content.append("")
            else:
                # Fallback to generic example
                for group_key in named_groups.keys():
                    content.append(f"  // Access {group_key} group:")
                    content.append(f"  bids_channel['{name}']['{group_key}']['nii'].size()")
                    content.append(f"  bids_channel['{name}']['{group_key}']['nii'][0]")
                    content.append(f"  bids_channel['{name}']['{group_key}']['json'][0]")
                    content.append("")
            
            content.append("```")
            content.append(":::")
            if 'example_output' in config_data:
                tmp_url = f"https://github.com/agahkarakuzu/bids2nf/blob/main/{config_data['example_output']}"
                content.append(f"{{button}}`Example channel data structure <{tmp_url}>`")
            content.append("::::")
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