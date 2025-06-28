include { ENTITY_BASED_GROUPING } from '../../workflows/entity_based_grouping.nf'
include { INGEST_EBG_MTS_CHANNEL } from '../../modules/io/ingest_ebg_mts_channel.nf'

workflow {
  ebg_mts_channel = ENTITY_BASED_GROUPING(params.bids_dir, params.bids2nf_config)
  INGEST_EBG_MTS_CHANNEL(ebg_mts_channel)
}