include { serializeMapToJson } from '../utils/json_utils'

process unified_process_template {
  
  input:
  tuple val(key), val(value)
  val(includeBidsParentDir)
  
  output:
  path "*.json", emit: output_file
  
  publishDir { "tests/new_outputs/${value.bidsBasename}" }, mode: 'copy'
  
  script:
  def enrichedData = value
  def data = enrichedData.data
  def filePaths = enrichedData.filePaths
  def bidsParentDir = enrichedData.bidsParentDir
  
  // Create dynamic entity values and filename based on actual entities in enrichedData
  def entityValues = []
  def entityFields = []
  ['subject', 'session', 'run', 'task', 'acquisition'].each { entity ->
    if (enrichedData.containsKey(entity)) {
      def value = enrichedData[entity] ?: "null"
      entityValues.add(value)
      entityFields.add("\"${entity}\": \"${value}\"")
    }
  }
  
  def filename = entityValues.join('_') + '_unified.json'
  def entityJson = entityFields.join(',\n  ')

  println "Unified processing .... ${entityValues.join(' ')}"
  
  def jsonString = serializeMapToJson(data)
  
  """
  echo "=== Unified bids2nf Processing ==="
  ${['subject', 'session', 'run', 'task', 'acquisition'].findAll { enrichedData.containsKey(it) }.collect { entity ->
    "echo \"${entity.capitalize()}: ${enrichedData[entity]}\""
  }.join('\n  ')}
  ${includeBidsParentDir ? "echo \"BIDS parent directory: ${bidsParentDir}\"" : ""}
  echo "Data types found: ${data.keySet()}"
  echo "Total file paths: ${filePaths.size()}"
  echo ""
  
  # Process each data type dynamically
  ${data.collect { suffix, suffixData ->
    // Determine the structure of this specific suffix data
    if (suffixData.containsKey('nii') && suffixData['nii'] instanceof List) {
      // Sequential set structure: {nii: [files], json: [files]}
      def niiFiles = suffixData['nii'] ?: []
      def numFiles = niiFiles.size()
      def firstFile = numFiles > 0 ? niiFiles[0] : 'N/A'
      def lastFile = numFiles > 0 ? niiFiles[numFiles-1] : 'N/A'
      
      return """
  echo "--- Sequential Set: ${suffix} ---"
  echo "Number of files: ${numFiles}"
  echo "First file: ${firstFile}"
  echo "Last file: ${lastFile}"
  echo ""
      """
    } else {
      // Named or Mixed set structure: check first group
      def sampleKey = suffixData.keySet().first()
      def sampleData = suffixData[sampleKey]
      
      if (sampleData instanceof Map && sampleData.containsKey('nii')) {
        if (sampleData['nii'] instanceof String) {
          // Named set: {T1w: {nii: "path", json: "path"}}
          def groupInfo = suffixData.collect { groupName, groupData ->
            if (groupData instanceof Map && groupData.containsKey('nii')) {
              return "echo \"  ${groupName}: ${groupData['nii']}\""
            }
            return ""
          }.findAll { it != "" }.join('\n  ')
          
          return """
  echo "--- Named Set: ${suffix} ---"
  echo "Available groups: ${suffixData.keySet()}"
  ${groupInfo}
  echo ""
          """
        } else if (sampleData['nii'] instanceof List) {
          // Mixed set: {MTw: {nii: [files], json: [files]}}
          def groupInfo = suffixData.collect { groupName, groupData ->
            if (groupData instanceof Map && groupData.containsKey('nii') && groupData['nii'] instanceof List) {
              def files = groupData['nii']
              def numFiles = files.size()
              def firstFile = numFiles > 0 ? files[0] : 'N/A'
              def lastFile = numFiles > 0 ? files[numFiles-1] : 'N/A'
              return "echo \"  ${groupName}: ${numFiles} files (${firstFile} ... ${lastFile})\""
            }
            return ""
          }.findAll { it != "" }.join('\n  ')
          
          return """
  echo "--- Mixed Set: ${suffix} ---"
  echo "Named groups: ${suffixData.keySet()}"
  ${groupInfo}
  echo ""
          """
        }
      }
    }
    return ""
  }.findAll { it != "" }.join('\n')}
  
cat > ${filename} << 'EOF'
{
  ${entityJson},
  "totalFiles": ${filePaths.size()},${includeBidsParentDir ? "\n  \"bidsParentDir\": \"${bidsParentDir}\"," : ""}
  "data": ${jsonString}
}
EOF
  """
}