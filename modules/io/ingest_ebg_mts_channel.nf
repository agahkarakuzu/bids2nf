process INGEST_EBG_MTS_CHANNEL {
  
  publishDir "tests/new_outputs/mts", mode: 'copy'

  input:
  tuple val(key), val(value)
  
  output:
  path "*.txt", emit: output_file
  
  script:
  def (subject, session, run) = key
  def (ebg_map, all_file_paths) = value

  // This is defined in the bids2nf.yaml file 
  // By modifying it you can change it to 
  def cur_pdw_nii = ebg_map['MTS']['PDw']['nii']
  def cur_pdw_json = ebg_map['MTS']['PDw']['json']

  def cur_t1w_nii = ebg_map['MTS']['T1w']['nii']
  def cur_t1w_json = ebg_map['MTS']['T1w']['json']

  def cur_mtw_nii = ebg_map['MTS']['MTw']['nii']
  def cur_mtw_json = ebg_map['MTS']['MTw']['json']

  println "Entity based grouping for MTS .... ${subject} ${session} ${run}"
  
  // This is the parent directory of the bids_dir
  // Use if you need to work with absolute paths
  
  //def parentDir = new File(params.bids_dir_parent).absolutePath
  //println "Parent directory: ${params.bids_dir_parent}"

  //def fullPath = new File(parentDir, cur_pdw_nii).absolutePath
  //println "Example absolute path: ${fullPath}"

  def output_content = 
  """Entity based grouping .... ${subject} ${session} ${run}
=================================
  - PDw
    - NII: ${cur_pdw_nii}
    - JSON: ${cur_pdw_json}
----------------------------------
  - T1w
    - NII: ${cur_t1w_nii}
    - JSON: ${cur_t1w_json}
----------------------------------
  - MTw
    - NII: ${cur_mtw_nii}
    - JSON: ${cur_mtw_json}
================================="""

  """
  echo '${output_content}' > ${subject}_${session}_${run}.txt
  """
}