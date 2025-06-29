include { serializeMapToJson } from '../utils/json_utils'

process mts_process_template {
  
  publishDir "tests/new_outputs/mts", mode: 'copy'

  input:
  tuple val(key), val(value)
  
  output:
  path "*.json", emit: output_file
  
  script:
  def (subject, session, run) = key
  def (bids, all_file_paths) = value

  println "Named set MTS .... ${subject} ${session} ${run}"
  
  def jsonString = serializeMapToJson(bids)
  
  """
  echo "Number of namespaces: ${bids['MTS'].size()}"
  echo "All namespaces: ${bids['MTS'].keySet()}"
  echo "Nifti from the T1w namespace: ${bids['MTS']['T1w']['nii']}"
  echo "Json from the MTw namespace: ${bids['MTS']['MTw']['json']}"
  echo "Implicit access to the PDw (second) namespace: ${bids['MTS'][bids['MTS'].keySet()[1]]}"
cat > ${subject}_${session}_${run}.json << 'EOF'
${jsonString}
EOF
  """
}