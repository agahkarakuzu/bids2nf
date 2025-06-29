include { serializeMapToJson } from '../utils/json_utils'

process vfa_process_template {
  
  publishDir "tests/new_outputs/vfa", mode: 'copy'

  input:
  tuple val(key), val(value)
  
  output:
  path "*.json", emit: output_file
  
  script:
  def (subject, session, run) = key
  def (bids, all_file_paths) = value

  println "Sequential set VFA .... ${subject} ${session} ${run}"
  
  // To write the map to a json file.
  def jsonString = serializeMapToJson(bids)

  """
  echo "Number of files in this sequential set: ${bids['VFA']['nii'].size()}"
  echo "All nifti files within the VFA set: ${bids['VFA']['nii']}"
  echo "First nifti file: ${bids['VFA']['nii'][0]}"
  echo "All json files within the VFA set: ${bids['VFA']['json']}"
  echo "The last json file: ${bids['VFA']['json'].last()}"
cat > ${subject}_${session}_${run}.json << 'EOF'
${jsonString}
EOF
  """
}