include { bids2nf } from '../../main.nf'
include { unified_process_template } from '../../modules/templates/unified_process_template.nf'

workflow {
  // Use the unified workflow that handles all configuration types
  unified_results = bids2nf(params.bids_dir)
  
  // Extract basename from bids_dir path for dynamic output directory
  def bids_basename = new File(params.bids_dir).getName()
  
  // Add basename to each result for template use
  unified_results_with_basename = unified_results.map { groupingKey, enrichedData ->
    def updatedData = enrichedData + [bidsBasename: bids_basename]
    tuple(groupingKey, updatedData)
  }
  
  // Process all results with a unified template
  unified_process_template(unified_results_with_basename)
}