include { emit_named_sets } from '../../workflows/emit_named_sets.nf'
include { mts_process_template } from '../../modules/templates/mts_process_template.nf'

workflow {
  mts_named_set = emit_named_sets(params.bids_dir, params.bids2nf_config)
  mts_process_template(mts_named_set)
}