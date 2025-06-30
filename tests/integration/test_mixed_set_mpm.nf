import org.yaml.snakeyaml.Yaml
include { libbids_sh_parse } from '../../modules/parsers/lib_bids_sh_parser.nf'
include { emit_mixed_sets } from '../../subworkflows/emit_mixed_sets.nf'
include { mpm_process_template } from '../../modules/templates/mpm_process_template.nf'
include { validateAllInputs } from '../../modules/parsers/bids_validator.nf'

workflow {
  // Individual tests need to do their own parsing since they call sub-workflows directly
  validateAllInputs(params.bids_dir, params.bids2nf_config, params.libbids_sh)
  parsed_csv = libbids_sh_parse(params.bids_dir, params.libbids_sh)
  config = new Yaml().load(new FileReader(params.bids2nf_config))
  
  mpm_mixed_set = emit_mixed_sets(parsed_csv, config)
  mpm_process_template(mpm_mixed_set)
}