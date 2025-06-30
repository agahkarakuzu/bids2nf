include { serializeMapToJson } from '../utils/json_utils'

process mpm_process_template {
  
  publishDir "tests/new_outputs/mpm", mode: 'copy'

  input:
  tuple val(key), val(value)
  
  output:
  path "*.json", emit: output_file
  
  script:
  def (subject, session, run) = key
  def (bids, all_file_paths) = value

  println "Mixed set MPM .... ${subject} ${session} ${run}"
  
  def jsonString = serializeMapToJson(bids)
  
  """
  echo "Number of acquisition types: ${bids['MPM'].size()}"
  echo "All acquisition types: ${bids['MPM'].keySet()}"
  echo "Number of MTw echoes: ${bids['MPM']['MTw']['nii'].size()}"
  echo "Number of PDw echoes: ${bids['MPM']['PDw']['nii'].size()}"
  echo "Number of T1w echoes: ${bids['MPM']['T1w']['nii'].size()}"
  echo "First MTw echo: ${bids['MPM']['MTw']['nii'][0]}"
  echo "Last T1w echo: ${bids['MPM']['T1w']['nii'][-1]}"
  echo "All MTw echoes: ${bids['MPM']['MTw']['nii']}"
cat > ${subject}_${session}_${run}.json << 'EOF'
${jsonString}
EOF
  """
}