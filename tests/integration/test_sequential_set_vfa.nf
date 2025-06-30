import org.yaml.snakeyaml.Yaml
include { libbids_sh_parse } from '../../modules/parsers/lib_bids_sh_parser.nf'
include { emit_sequential_sets } from '../../subworkflows/emit_sequential_sets.nf'
include { vfa_process_template } from '../../modules/templates/vfa_process_template.nf'
include { validateAllInputs } from '../../modules/parsers/bids_validator.nf'

workflow {
  // Individual tests need to do their own parsing since they call sub-workflows directly
  validateAllInputs(params.bids_dir, params.bids2nf_config, params.libbids_sh)
  parsed_csv = libbids_sh_parse(params.bids_dir, params.libbids_sh)
  config = new Yaml().load(new FileReader(params.bids2nf_config))
  
  vfa_sequential_set = emit_sequential_sets(parsed_csv, config)
  vfa_process_template(vfa_sequential_set)
}