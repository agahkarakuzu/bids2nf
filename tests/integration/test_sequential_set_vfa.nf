include { emit_sequential_sets } from '../../workflows/emit_sequential_sets.nf'
include { vfa_process_template } from '../../modules/templates/vfa_process_template.nf'

workflow {
  vfa_sequential_set = emit_sequential_sets(params.bids_dir, params.bids2nf_config)
  vfa_process_template(vfa_sequential_set)
}