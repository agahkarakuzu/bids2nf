include { emit_sequential_sets } from '../../workflows/emit_sequential_sets.nf'
include { emit_named_sets } from '../../workflows/emit_named_sets.nf'

workflow {
  sequential_sets = emit_sequential_sets(params.bids_dir, params.bids2nf_config).view()
  named_sets = emit_named_sets(params.bids_dir, params.bids2nf_config).view()
}