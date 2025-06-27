process DISPLAY_FILES_BY_GROUP {
  
  input:
  tuple val(key), val(value)
  
  script:
  def (subject, session) = key
  def (all_grouped_files, all_file_paths) = value

  def pdw_nii_files = all_grouped_files['MTS']['PDw']['nii']
  def pdw_json_files = all_grouped_files['MTS']['PDw']['json']

  def t1w_nii_files = all_grouped_files['MTS']['T1w']['nii']
  def t1w_json_files = all_grouped_files['MTS']['T1w']['json']

  def mtw_nii_files = all_grouped_files['MTS']['MTw']['nii']
  def mtw_json_files = all_grouped_files['MTS']['MTw']['json']

  println "Entity based grouping .... ${subject} ${session}"

  """
  echo "================================="
  echo "  - PDw"
  echo "    - NII: ${pdw_nii_files}"
  echo "    - JSON: ${pdw_json_files}"
  echo "---------------------------------"
  echo "  - T1w"
  echo "    - NII: ${t1w_nii_files}"
  echo "    - JSON: ${t1w_json_files}"
  echo "---------------------------------"
  echo "  - MTw"
  echo "    - NII: ${mtw_nii_files}"
  echo "    - JSON: ${mtw_json_files}"
  echo "================================="
  """
}