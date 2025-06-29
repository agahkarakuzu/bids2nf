include { readJsonFromFile } from './json_utils'

process COMPARE_JSON_FILES {
input:
tuple val(relative_path), path(expected_json, stageAs: 'expected_*'), path(new_json, stageAs: 'new_*')

output:
stdout emit: result

script:
"""
python3 -c "
import json
import sys
try:
    with open('${expected_json}', 'r') as f:
        expected = json.load(f)
    with open('${new_json}', 'r') as f:
        new = json.load(f)
    if expected == new:
        print('✅ ${relative_path}: JSON files match')
        sys.exit(0)
    else:
        print('❌ ${relative_path}: JSON files differ')
        print('Expected:', expected)
        print('New:', new)
        sys.exit(1)
except Exception as e:
    print('❌ ${relative_path}: Error comparing files -', str(e))
    sys.exit(1)
"
"""
}