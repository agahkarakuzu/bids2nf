include { ENTITY_BASED_GROUPING } from './workflows/entity_based_grouping.nf'
include { DISPLAY_FILES_BY_GROUP } from './modules/display_files_by_group.nf'

workflow {
  grouped_channel = ENTITY_BASED_GROUPING(params.bids_dir, params.libbids_sh, params.bids2nf_config)
  DISPLAY_FILES_BY_GROUP(grouped_channel)
}
