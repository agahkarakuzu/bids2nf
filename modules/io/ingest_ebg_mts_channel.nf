include { serializeMapToJson } from '../utils/json_utils'

process INGEST_EBG_MTS_CHANNEL {
  
  publishDir "tests/new_outputs/mts", mode: 'copy'

  input:
  tuple val(key), val(value)
  
  output:
  path "*.json", emit: output_file
  
  script:
  def (subject, session, run) = key
  def (ebg_map, all_file_paths) = value

  println "Entity based grouping for MTS .... ${subject} ${session} ${run}"
  
  def jsonString = serializeMapToJson(ebg_map)
  
  // Let your inner OCD rest easy, do not indent 
  // the code below.
  """
cat > ${subject}_${session}_${run}.json << 'EOF'
${jsonString}
EOF
  """
}