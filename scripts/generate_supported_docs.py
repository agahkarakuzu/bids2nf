#!/usr/bin/env python3
"""
Generate supported.md documentation from bids2nf.yaml configuration.
"""

import yaml
import argparse
import requests
import json
from pathlib import Path
from typing import Dict, List, Tuple, Any, Optional


def generate_plain_set_mermaid(name: str, config_data: Dict[str, Any]) -> List[str]:
    """Generate mermaid diagram for plain sets."""
    plain_set = config_data['plain_set']
    additional_extensions = plain_set.get('additional_extensions', [])
    include_cross_modal = plain_set.get('include_cross_modal', [])
    
    # Start the diagram
    lines = ["graph LR"]
    lines.append(f"    A[{name}] --> B[.nii/.nii.gz]")
    lines.append(f"    A -.-> C[.json]")  # Dotted line for optional
    
    # Add additional extensions
    node_letter = ord('D')
    for ext in additional_extensions:
        lines.append(f"    A -.-> {chr(node_letter)}[.{ext}]")  # Dotted for optional
        node_letter += 1
    
    # Add cross-modal relationships
    cross_modal_nodes = []
    for cross_modal_suffix in include_cross_modal:
        cross_modal_node = chr(node_letter)
        cross_modal_nodes.append(cross_modal_node)
        lines.append(f"    {cross_modal_node}[{cross_modal_suffix}] ==> A")  # Thick arrow for cross-modal input
        lines.append(f"    {cross_modal_node} --> {chr(node_letter + 1)}[.nii/.nii.gz]")
        lines.append(f"    {cross_modal_node} -.-> {chr(node_letter + 2)}[.json]")
        node_letter += 3
    
    # Style the nodes
    lines.append("    classDef mainNode fill:#e1f5fe")
    lines.append("    classDef fileNode fill:#f3e5f5")
    lines.append("    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5")
    lines.append("    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px")
    lines.append("    class A mainNode")
    lines.append("    class B fileNode")
    
    # Mark optional files with dashed border
    optional_nodes = ['C'] + [chr(ord('D') + i) for i in range(len(additional_extensions))]
    if optional_nodes:
        lines.append(f"    class {','.join(optional_nodes)} optionalNode")
    
    # Style cross-modal nodes
    if cross_modal_nodes:
        lines.append(f"    class {','.join(cross_modal_nodes)} crossModalNode")
    
    return lines


def generate_named_set_mermaid(name: str, config_data: Dict[str, Any]) -> List[str]:
    """Generate mermaid diagram for named sets."""
    named_set = config_data['named_set']
    required = config_data.get('required', [])
    additional_extensions = config_data.get('additional_extensions', [])
    
    lines = ["graph TD"]
    lines.append(f"    A[{name}] --> B{{Named Groups}}")
    
    # Add named groups
    node_letter = ord('C')
    for group_name in named_set.keys():
        group_node = chr(node_letter)
        lines.append(f"    B --> {group_node}[{group_name}]")
        
        # Add file types for each group
        nii_node = chr(node_letter + 1)
        json_node = chr(node_letter + 2)
        lines.append(f"    {group_node} --> {nii_node}[.nii/.nii.gz]")
        lines.append(f"    {group_node} --> {json_node}[.json]")
        
        # Add additional extensions for each group
        ext_node_offset = 3
        for ext in additional_extensions:
            ext_node = chr(node_letter + ext_node_offset)
            lines.append(f"    {group_node} -.-> {ext_node}[.{ext}]")  # Dotted for optional
            ext_node_offset += 1
        
        node_letter += 3 + len(additional_extensions)
    
    # Style the nodes
    lines.append("    classDef mainNode fill:#e1f5fe")
    lines.append("    classDef groupNode fill:#fff3e0")
    lines.append("    classDef fileNode fill:#f3e5f5")
    lines.append("    classDef requiredNode fill:#ffebee,stroke:#d32f2f,stroke-width:2px")
    
    lines.append("    class A mainNode")
    lines.append("    class B groupNode")
    
    # Mark required groups
    required_nodes = []
    all_group_nodes = []
    node_offset = 0
    
    for i, group_name in enumerate(named_set.keys()):
        group_node = chr(ord('C') + node_offset)
        all_group_nodes.append(group_node)
        if group_name in required:
            required_nodes.append(group_node)
        node_offset += 3 + len(additional_extensions)
    
    if required_nodes:
        lines.append(f"    class {','.join(required_nodes)} requiredNode")
    
    non_required = [node for node in all_group_nodes if node not in required_nodes]
    if non_required:
        lines.append(f"    class {','.join(non_required)} groupNode")
    
    # File nodes
    file_nodes = []
    optional_nodes = []
    node_offset = 0
    for i in range(len(named_set)):
        base_node = ord('C') + node_offset
        nii_node = chr(base_node + 1)
        json_node = chr(base_node + 2)
        file_nodes.extend([nii_node, json_node])
        
        # Add additional extension nodes as optional
        for j, ext in enumerate(additional_extensions):
            ext_node = chr(base_node + 3 + j)
            optional_nodes.append(ext_node)
        
        node_offset += 3 + len(additional_extensions)
    
    lines.append(f"    class {','.join(file_nodes)} fileNode")
    if optional_nodes:
        lines.append(f"    class {','.join(optional_nodes)} optionalNode")
    
    return lines


def generate_sequential_set_mermaid(name: str, config_data: Dict[str, Any]) -> List[str]:
    """Generate mermaid diagram for sequential sets."""
    sequential_set = config_data['sequential_set']
    
    lines = ["graph TD"]
    lines.append(f"    A[{name}] --> B{{Sequential Collection}}")
    
    if 'by_entity' in sequential_set:
        entity = sequential_set['by_entity']
        lines.append(f"    B --> C[Organized by {entity}]")
        lines.append("    C --> D[Index 0]")
        lines.append("    C --> E[Index 1]")
        lines.append("    C --> F[Index ...]")
        lines.append("    D --> G[.nii/.nii.gz]")
        lines.append("    D --> H[.json]")
        lines.append("    E --> I[.nii/.nii.gz]")
        lines.append("    E --> J[.json]")
        
        # Style
        lines.append("    classDef mainNode fill:#e1f5fe")
        lines.append("    classDef collectionNode fill:#fff3e0")
        lines.append("    classDef entityNode fill:#e8f5e8")
        lines.append("    classDef indexNode fill:#fce4ec")
        lines.append("    classDef fileNode fill:#f3e5f5")
        
        lines.append("    class A mainNode")
        lines.append("    class B collectionNode")
        lines.append("    class C entityNode")
        lines.append("    class D,E,F indexNode")
        lines.append("    class G,H,I,J fileNode")
        
    elif 'by_entities' in sequential_set:
        entities = sequential_set['by_entities']
        order = sequential_set.get('order', 'hierarchical')
        first_entity = entities[0] if len(entities) > 0 else 'entity1'
        second_entity = entities[1] if len(entities) > 1 else 'entity2'
        
        if order == 'hierarchical':
            lines.append(f"    B --> C[{first_entity} dimension]")
            lines.append(f"    C --> D[{first_entity}=1]")
            lines.append(f"    C --> E[{first_entity}=2]")
            lines.append(f"    D --> F[{second_entity}=1]")
            lines.append(f"    D --> G[{second_entity}=2]")
            lines.append(f"    E --> H[{second_entity}=1]")
            lines.append(f"    E --> I[{second_entity}=2]")
            lines.append("    F --> J[.nii/.nii.gz]")
            lines.append("    F --> K[.json]")
            lines.append("    G --> L[.nii/.nii.gz]")
            lines.append("    G --> M[.json]")
            
            # Style
            lines.append("    classDef mainNode fill:#e1f5fe")
            lines.append("    classDef collectionNode fill:#fff3e0")
            lines.append("    classDef entityNode fill:#e8f5e8")
            lines.append("    classDef indexNode fill:#fce4ec")
            lines.append("    classDef fileNode fill:#f3e5f5")
            
            lines.append("    class A mainNode")
            lines.append("    class B collectionNode")
            lines.append("    class C entityNode")
            lines.append("    class D,E,F,G,H,I indexNode")
            lines.append("    class J,K,L,M fileNode")
        else:
            # Flat order
            lines.append(f"    B --> C[Flat array by {', '.join(entities)}]")
            lines.append("    C --> D[Index 0]")
            lines.append("    C --> E[Index 1]")
            lines.append("    C --> F[Index ...]")
            lines.append("    D --> G[.nii/.nii.gz]")
            lines.append("    D --> H[.json]")
            
            # Style
            lines.append("    classDef mainNode fill:#e1f5fe")
            lines.append("    classDef collectionNode fill:#fff3e0")
            lines.append("    classDef entityNode fill:#e8f5e8")
            lines.append("    classDef indexNode fill:#fce4ec")
            lines.append("    classDef fileNode fill:#f3e5f5")
            
            lines.append("    class A mainNode")
            lines.append("    class B collectionNode")
            lines.append("    class C entityNode")
            lines.append("    class D,E,F indexNode")
            lines.append("    class G,H fileNode")
    
    return lines


def generate_mixed_set_mermaid(name: str, config_data: Dict[str, Any]) -> List[str]:
    """Generate mermaid diagram for mixed sets."""
    mixed_set = config_data['mixed_set']
    named_groups = mixed_set.get('named_groups', {})
    named_dimension = mixed_set.get('named_dimension', 'acquisition')
    sequential_dimension = mixed_set.get('sequential_dimension', 'echo')
    required = config_data.get('required', [])
    additional_extensions = config_data.get('additional_extensions', [])
    
    lines = ["graph TD"]
    lines.append(f"    A[{name}] --> B{{Mixed Collection}}")
    lines.append(f"    B --> C[Named: {named_dimension}]")
    lines.append(f"    B --> D[Sequential: {sequential_dimension}]")
    
    # Add named groups
    node_letter = ord('E')
    for i, group_name in enumerate(named_groups.keys()):
        group_node = chr(node_letter)
        lines.append(f"    C --> {group_node}[{group_name}]")
        
        # Each group has sequential files
        seq_node = chr(node_letter + 1)
        lines.append(f"    {group_node} --> {seq_node}[Sequential files]")
        lines.append(f"    {seq_node} --> {chr(node_letter + 2)}[Index 0]")
        lines.append(f"    {seq_node} --> {chr(node_letter + 3)}[Index 1]")
        lines.append(f"    {chr(node_letter + 2)} --> {chr(node_letter + 4)}[.nii/.nii.gz]")
        lines.append(f"    {chr(node_letter + 2)} --> {chr(node_letter + 5)}[.json]")
        
        # Add additional extensions for each index
        ext_node_offset = 6
        for ext in additional_extensions:
            ext_node = chr(node_letter + ext_node_offset)
            lines.append(f"    {chr(node_letter + 2)} -.-> {ext_node}[.{ext}]")  # Dotted for optional
            ext_node_offset += 1
        
        node_letter += 6 + len(additional_extensions)
    
    # Style
    lines.append("    classDef mainNode fill:#e1f5fe")
    lines.append("    classDef collectionNode fill:#fff3e0")
    lines.append("    classDef dimensionNode fill:#e8f5e8")
    lines.append("    classDef groupNode fill:#fce4ec")
    lines.append("    classDef requiredNode fill:#ffebee,stroke:#d32f2f,stroke-width:2px")
    lines.append("    classDef seqNode fill:#f1f8e9")
    lines.append("    classDef indexNode fill:#fce4ec")
    lines.append("    classDef fileNode fill:#f3e5f5")
    
    lines.append("    class A mainNode")
    lines.append("    class B collectionNode")
    lines.append("    class C,D dimensionNode")
    
    # Mark required groups
    required_nodes = []
    all_group_nodes = []
    node_offset = 0
    
    for i, group_name in enumerate(named_groups.keys()):
        group_node = chr(ord('E') + node_offset)
        all_group_nodes.append(group_node)
        if group_name in required:
            required_nodes.append(group_node)
        node_offset += 6 + len(additional_extensions)
    
    if required_nodes:
        lines.append(f"    class {','.join(required_nodes)} requiredNode")
    
    non_required = [node for node in all_group_nodes if node not in required_nodes]
    if non_required:
        lines.append(f"    class {','.join(non_required)} groupNode")
    
    return lines


def fetch_bids_suffixes() -> Dict[str, Any]:
    """Fetch suffix information from BIDS specification."""
    url = "https://raw.githubusercontent.com/bids-standard/bids-specification/refs/heads/master/src/schema/objects/suffixes.yaml"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return yaml.safe_load(response.text)
    except Exception as e:
        print(f"Warning: Could not fetch BIDS suffixes schema: {e}")
        return {}


def get_bids_info(name: str, bids_suffixes: Dict[str, Any]) -> Tuple[str, str]:
    """Get BIDS suffix information (display name and description)."""
    suffix_info = bids_suffixes.get(name, {})
    display_name = suffix_info.get('display_name', name)
    description = suffix_info.get('description', '')
    return display_name, description


def format_footer_text(config_data: Dict[str, Any], set_type: str) -> str:
    """Format footer text based on set type and configuration."""
    if set_type == 'special':
        suffix_maps_to = config_data.get('suffix_maps_to', '')
        additional_extensions = config_data.get('additional_extensions', [])
        
        footer_parts = [f"**Maps to:** `{suffix_maps_to}`"]
        if additional_extensions:
            extensions_str = ', '.join([f"`{ext}`" for ext in additional_extensions])
            footer_parts.append(f"**Additional extensions:** {extensions_str}")
        return " | ".join(footer_parts)
    
    elif set_type == 'plain':
        plain_set = config_data['plain_set']
        additional_extensions = plain_set.get('additional_extensions', [])
        include_cross_modal = plain_set.get('include_cross_modal', [])
        
        extensions_str = ', '.join([f"`{ext}`" for ext in additional_extensions]) if additional_extensions else "None"
        cross_modal_str = ', '.join([f"`{cm}`" for cm in include_cross_modal]) if include_cross_modal else None
        
        footer_parts = [f"**Additional extensions:** {extensions_str}"]
        if cross_modal_str:
            footer_parts.append(f"**Cross-modal includes:** {cross_modal_str}")
        return " | ".join(footer_parts)
    
    elif set_type == 'named':
        required = config_data.get('required', [])
        required_str = ', '.join([f"`{req}`" for req in required]) if required else "None"
        return f"**Required keys:** {required_str}"
    
    elif set_type == 'sequential':
        sequential_set = config_data['sequential_set']
        organization_info = []
        if 'by_entity' in sequential_set:
            entity = sequential_set['by_entity']
            organization_info.append(f"Entity: `{entity}`")
        elif 'by_entities' in sequential_set:
            entities = sequential_set['by_entities']
            order = sequential_set.get('order', 'sequential')
            organization_info.append(f"Entities: {', '.join([f'`{e}`' for e in entities])} ({order} order)")
        
        if organization_info:
            return f"**{organization_info[0]}**"
        else:
            return "🐈‍⬛"
    
    elif set_type == 'mixed':
        mixed_set = config_data['mixed_set']
        named_dimension = mixed_set.get('named_dimension', 'acquisition')
        sequential_dimension = mixed_set.get('sequential_dimension', 'echo')
        return f"**Named: `{named_dimension}`, Sequential: `{sequential_dimension}`**"
    
    return ""


def get_heading_class(set_type: str) -> str:
    """Get the appropriate heading class for the set type."""
    heading_classes = {
        'special': 'custom-heading-special',
        'plain': 'custom-heading-plain',
        'named': 'custom-heading',
        'sequential': 'custom-heading-2',
        'mixed': 'custom-heading-3'
    }
    return heading_classes.get(set_type, 'custom-heading')


def load_example_data(config_data: Dict[str, Any], name: str) -> Optional[Dict[str, Any]]:
    """Load example data from JSON file if available."""
    if 'example_output' not in config_data:
        return None
    
    example_file = Path(config_data['example_output'])
    if not example_file.exists():
        return None
    
    try:
        with open(example_file, 'r') as f:
            example_data = json.load(f)
        
        if 'data' in example_data and name in example_data['data']:
            return example_data['data'][name]
    except (json.JSONDecodeError, FileNotFoundError):
        pass
    
    return None


def generate_plain_set_example(name: str, config_data: Dict[str, Any], suffix_data: Optional[Dict[str, Any]]) -> List[str]:
    """Generate example code for plain sets."""
    content = []
    plain_set = config_data['plain_set']
    additional_extensions = plain_set.get('additional_extensions', [])
    
    if suffix_data:
        # Show actual structure from JSON
        for ext, file_path in suffix_data.items():
            content.append(f"  // Access {ext} file:")
            content.append(f"  bids_channel['{name}']['{ext}']")
            content.append(f"  // → {file_path}")
            content.append("")
    else:
        # Fallback to generic example
        if additional_extensions:
            content.append(f"  // Access files (flexible formats):")
            content.append(f"  // NIfTI file (if available):")
            content.append(f"  bids_channel['{name}']['nii']")
            content.append(f"  // JSON file (if available):")
            content.append(f"  bids_channel['{name}']['json']")
            content.append(f"  // Additional files:")
            for ext in additional_extensions:
                content.append(f"  bids_channel['{name}']['{ext}']")
        else:
            content.append(f"  // Access main files:")
            content.append(f"  bids_channel['{name}']['nii']")
            content.append(f"  bids_channel['{name}']['json']")
    
    return content


def generate_named_set_example(name: str, config_data: Dict[str, Any], suffix_data: Optional[Dict[str, Any]]) -> List[str]:
    """Generate example code for named sets."""
    content = []
    named_set = config_data['named_set']
    
    if suffix_data:
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
    
    return content


def generate_sequential_set_example(name: str, config_data: Dict[str, Any], suffix_data: Optional[Dict[str, Any]]) -> List[str]:
    """Generate example code for sequential sets."""
    content = []
    sequential_set = config_data['sequential_set']
    
    if suffix_data:
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
    
    return content


def generate_mixed_set_example(name: str, config_data: Dict[str, Any], suffix_data: Optional[Dict[str, Any]]) -> List[str]:
    """Generate example code for mixed sets."""
    content = []
    mixed_set = config_data['mixed_set']
    named_groups = mixed_set.get('named_groups', {})
    sequential_dimension = mixed_set.get('sequential_dimension', 'echo')
    
    if suffix_data:
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
    
    return content


def generate_example_code(name: str, config_data: Dict[str, Any], set_type: str) -> List[str]:
    """Generate example code based on set type."""
    suffix_data = load_example_data(config_data, name)
    
    if set_type == 'special':
        # For special cases, determine the underlying set type and use appropriate example
        if 'named_set' in config_data:
            return generate_named_set_example(name, config_data, suffix_data)
        elif 'sequential_set' in config_data:
            return generate_sequential_set_example(name, config_data, suffix_data)
        elif 'mixed_set' in config_data:
            return generate_mixed_set_example(name, config_data, suffix_data)
        else:
            # Fallback to plain set for special cases without other set types
            return generate_plain_set_example(name, config_data, suffix_data)
    elif set_type == 'plain':
        return generate_plain_set_example(name, config_data, suffix_data)
    elif set_type == 'named':
        return generate_named_set_example(name, config_data, suffix_data)
    elif set_type == 'sequential':
        return generate_sequential_set_example(name, config_data, suffix_data)
    elif set_type == 'mixed':
        return generate_mixed_set_example(name, config_data, suffix_data)
    else:
        return []


def generate_mermaid_diagram(name: str, config_data: Dict[str, Any], set_type: str) -> List[str]:
    """Generate mermaid diagram based on set type."""
    if set_type == 'special':
        # For special cases, determine the underlying set type and use appropriate diagram
        if 'named_set' in config_data:
            return generate_named_set_mermaid(name, config_data)
        elif 'sequential_set' in config_data:
            return generate_sequential_set_mermaid(name, config_data)
        elif 'mixed_set' in config_data:
            return generate_mixed_set_mermaid(name, config_data)
        else:
            # Fallback to plain set for special cases without other set types
            return generate_plain_set_mermaid(name, config_data)
    elif set_type == 'plain':
        return generate_plain_set_mermaid(name, config_data)
    elif set_type == 'named':
        return generate_named_set_mermaid(name, config_data)
    elif set_type == 'sequential':
        return generate_sequential_set_mermaid(name, config_data)
    elif set_type == 'mixed':
        return generate_mixed_set_mermaid(name, config_data)
    else:
        return []


def add_example_button(content: List[str], config_data: Dict[str, Any]) -> None:
    """Add example button if example output is available."""
    if 'example_output' in config_data:
        tmp_url = f"https://github.com/agahkarakuzu/bids2nf/blob/main/{config_data['example_output']}"
        try:
            if requests.get(tmp_url).status_code == 200:
                content.append(f"{{button}}`Example channel data structure <{tmp_url}>`")
        except:
            pass


def add_note(content: List[str], config_data: Dict[str, Any]) -> None:
    """Add note if present in configuration."""
    if 'note' in config_data:
        content.append("")
        content.append(":::{note}")
        content.append(config_data['note'])
        content.append(":::")


def generate_suffix_card(name: str, config_data: Dict[str, Any], set_type: str, bids_suffixes: Dict[str, Any]) -> List[str]:
    """Generate a complete suffix card with all components."""
    content = []
    
    # Get BIDS information
    display_name, description = get_bids_info(name, bids_suffixes)
    
    # Get configuration-specific data
    if set_type == 'plain':
        plain_set = config_data['plain_set']
        description_from_config = plain_set.get('description', '')
    elif set_type == 'special':
        description_from_config = f"Additional grouping logic for [{config_data['suffix_maps_to']}](#{config_data['suffix_maps_to']})"
    else:
        description_from_config = ''
    
    # Format footer
    footer_text = format_footer_text(config_data, set_type)
    
    # Start card
    content.append("::::{card}")
    content.append(f":header: <span class=\"{get_heading_class(set_type)}\"><h4>{name}</h4></span>")
    content.append(f":footer: {footer_text}")
    content.append("")
    
    # Add description
    if description:
        final_description = description
        if display_name != name:
            content.append(f"**{display_name}**")
            content.append("")
    else:
        final_description = description_from_config
    
    if final_description:
        content.append(final_description)
        content.append("")
    
    # Add mermaid diagram
    content.append(":::{mermaid}")
    mermaid_lines = generate_mermaid_diagram(name, config_data, set_type)
    content.extend(mermaid_lines)
    content.append(":::")
    content.append("")
    content.append("[⌬ Hover to see the diagram legend](#mermaidlegend)")
    content.append("")
    
    # Add set-specific content
    if set_type == 'special':
        # Show the underlying set type content for special cases
        if 'named_set' in config_data:
            named_set = config_data['named_set']
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
        elif 'mixed_set' in config_data:
            mixed_set = config_data['mixed_set']
            named_groups = mixed_set.get('named_groups', {})
            required = config_data.get('required', [])
            
            content.append("| Named Group | Description | Entity-based mapping |")
            content.append("|-------------|-------------|------------|")
            
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
            required_str = ', '.join([f"`{req}`" for req in required]) if required else "None"
            content.append(f"**Required groups:** {required_str}")
            content.append("")
    
    elif set_type == 'named':
        named_set = config_data['named_set']
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
    
    elif set_type == 'mixed':
        mixed_set = config_data['mixed_set']
        named_groups = mixed_set.get('named_groups', {})
        required = config_data.get('required', [])
        
        content.append("| Named Group | Description | Entity-based mapping |")
        content.append("|-------------|-------------|------------|")
        
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
        required_str = ', '.join([f"`{req}`" for req in required]) if required else "None"
        content.append(f"**Required groups:** {required_str}")
        content.append("")
    
    # Add example usage
    content.append(":::{seealso} Example usage within a process")
    content.append(":class: dropdown")
    content.append("```groovy")
    
    example_lines = generate_example_code(name, config_data, set_type)
    content.extend(example_lines)
    
    content.append("```")
    content.append(":::")
    
    # Add example button
    add_example_button(content, config_data)
    
    # Add note
    add_note(content, config_data)
    
    # End card
    content.append("::::")
    content.append("")
    
    return content


def generate_supported_docs(yaml_file: Path, output_file: Path) -> None:
    """Generate supported.md from bids2nf.yaml configuration."""
    
    with open(yaml_file, 'r') as f:
        config = yaml.safe_load(f)
    
    # Fetch BIDS suffixes information
    bids_suffixes = fetch_bids_suffixes()
    
    content = []
    content.append("# Supported BIDS Suffixes")
    content.append("")
    content.append("This page documents the BIDS suffixes currently **supported by the default configuration** of bids2nf (`bids2nf.yaml`). You can [extend the configuration](configuration.md) to support your own data structures.")
    content.append("")
    
    # Process sets by type
    set_types = {
        'plain': [],
        'named': [],
        'sequential': [],
        'mixed': [],
        'special': []
    }
    
    for key, value in config.items():
        if 'suffix_maps_to' in value:
            set_types['special'].append((key, value))
        elif 'plain_set' in value:
            set_types['plain'].append((key, value))
        elif 'named_set' in value:
            set_types['named'].append((key, value))
        elif 'sequential_set' in value:
            set_types['sequential'].append((key, value))
        elif 'mixed_set' in value:
            set_types['mixed'].append((key, value))
    
    # Section titles and descriptions
    section_info = {
        'plain': ("Plain Sets", "Plain sets define simple collections of files that do not require special grouping logic."),
        'named': ("Named Sets", "Named sets define specific collections of files with predefined names and properties."),
        'sequential': ("Sequential Sets", "Sequential sets define collections of files organized by BIDS entities."),
        'mixed': ("Mixed Sets", "Mixed sets combine named groups with sequential organization within each group."),
        'special': ("Special Sets", "Special sets are special cases that do not fit into the other categories.")
    }
    
    # Generate content for each set type
    for set_type, (section_title, section_description) in section_info.items():
        sets_list = set_types[set_type]
        if sets_list:
            content.append(f"## {section_title}")
            content.append("")
            content.append(section_description)
            content.append("")
            
            for name, config_data in sets_list:
                card_content = generate_suffix_card(name, config_data, set_type, bids_suffixes)
                content.extend(card_content)
    
    # Add comprehensive mermaid legend at the bottom
    content.append("::::{admonition} Mermaid Diagram Legend")
    content.append(":label: mermaidlegend")
    content.append(":class: tip")
    content.append("")
    content.append("Understanding the symbols and connections in the diagrams above:")
    content.append("")
    content.append(":::{mermaid}")
    content.append("graph LR")
    content.append("    A[Suffix/Node] --> B[Required File]")
    content.append("    A -.-> C[Optional File]")
    content.append("    D[Cross-modal Input] ==> A")
    content.append("    D --> E[Required File]")
    content.append("    D -.-> F[Optional File]")
    content.append("    classDef mainNode fill:#e1f5fe")
    content.append("    classDef fileNode fill:#f3e5f5")
    content.append("    classDef optionalNode fill:#f3e5f5,stroke-dasharray: 5 5")
    content.append("    classDef crossModalNode fill:#fff3e0,stroke:#ff9800,stroke-width:2px")
    content.append("    class A mainNode")
    content.append("    class B,E fileNode")
    content.append("    class C,F optionalNode")
    content.append("    class D crossModalNode")
    content.append(":::")
    content.append("")
    content.append("**Line Types:**")
    content.append("- **Solid arrows (→)**: Required files that are always expected")
    content.append("- **Dashed arrows (-.->)**: Optional files that may or may not be present")
    content.append("- **Thick arrows (==>)**: Cross-modal relationships (data from other suffixes)")
    content.append("")
    content.append("**Node Colors:**")
    content.append("- **Light blue**: Main suffix/node")
    content.append("- **Light purple**: File extensions")
    content.append("- **Light orange with orange border**: Cross-modal input nodes")
    content.append("::::")
    content.append("")
    
    content.append("---")
    content.append("")
    content.append("*This documentation is automatically generated from `bids2nf.yaml`.*")
    
    # Write to output file
    with open(output_file, 'w') as f:
        f.write('\n'.join(content))


def main() -> int:
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