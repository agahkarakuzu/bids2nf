include { 
    createFileMap; 
    createGroupingKey;
    buildChannelData
} from '../modules/grouping/entity_grouping_utils.nf'
include {
    validatePlainSetFiles
} from '../modules/grouping/plain_set_utils.nf'

def getTargetSuffix(configKey, configValue) {
    return (configValue instanceof Map && configValue.containsKey('suffix_maps_to')) ? configValue.suffix_maps_to : configKey
}

def findMatchingVirtualConfig(row, config) {
    def candidateConfigs = config.findAll { configKey, configValue ->
        def targetSuffix = getTargetSuffix(configKey, configValue)
        return targetSuffix == row.suffix && configValue instanceof Map && configValue.containsKey('plain_set')
    }
    
    // For plain sets, any candidate can process the file (no entity requirements)
    return candidateConfigs.size() > 0 ? [configKey: candidateConfigs.entrySet().first().key, configValue: candidateConfigs.entrySet().first().value] : null
}
include {
    handleError;
    logProgress;
    tryWithContext
} from '../modules/utils/error_handling.nf'

workflow emit_plain_sets {
    take:
    parsed_csv
    config
    loopOverEntities

    main:
    
    // Input validation and parsing now done by calling workflow
    logProgress("emit_plain_sets", "Creating plain set channels ...")

    input_files = parsed_csv
        .splitCsv(header: true)
        .filter { row -> 
            def matchingConfig = findMatchingVirtualConfig(row, config)
            return matchingConfig != null
        }
        .map { row -> 
            def entityValues = loopOverEntities.collect { entity -> 
                def value = row.containsKey(entity) ? row[entity] : "NA"
                return (value == null || value == "") ? "NA" : value
            }
            
            // Find the matching virtual configuration
            def matchingConfig = findMatchingVirtualConfig(row, config)
            def virtualSuffixKey = matchingConfig.configKey
            def suffixConfig = matchingConfig.configValue
            
            // Check if parts configuration exists
            def hasPartsConfig = suffixConfig.containsKey('plain_set') && 
                               suffixConfig.plain_set.containsKey('parts')
            def partValue = hasPartsConfig ? (row.part ?: "NA") : "NA"
            
            tuple(entityValues + [virtualSuffixKey, row.extension], [row.path, partValue, hasPartsConfig])
        }

    input_pairs = input_files
        .map { groupingKeyWithSuffixExt, fileData ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffixExt[0..entityCount-1]
            def suffix = groupingKeyWithSuffixExt[entityCount]
            def extension = groupingKeyWithSuffixExt[entityCount+1]
            def (filePath, partValue, hasPartsConfig) = fileData
            tuple(entityValues + [suffix], [extension, filePath, partValue, hasPartsConfig])
        }
        .groupTuple()
        .map { groupingKeyWithSuffix, extFiles ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffix[0..entityCount-1]
            def virtualSuffixKey = groupingKeyWithSuffix[entityCount]
            def suffixConfig = config[virtualSuffixKey]
            
            // Check if this is a parts-enabled plain set
            def hasPartsConfig = false
            def partsConfig = null
            if (suffixConfig.containsKey('plain_set') && suffixConfig.plain_set.containsKey('parts')) {
                hasPartsConfig = true
                partsConfig = suffixConfig.plain_set.parts
            }
            
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = entityValues[index]
            }
            
            if (hasPartsConfig) {
                // Handle parts logic for plain sets
                def filesByExtAndPart = [:]
                
                extFiles.each { extension, filePath, partValue, hasPartsConfigFile ->
                    if (partValue && partValue != "NA") {
                        def key = "${extension}_${partValue}"
                        filesByExtAndPart[key] = filePath
                    } else {
                        filesByExtAndPart[extension] = filePath
                    }
                }
                
                // Validate that we have the required files
                def regularFileMap = [:]
                filesByExtAndPart.each { key, path ->
                    if (!key.contains('_')) {
                        regularFileMap[key] = path
                    }
                }
                
                if (validatePlainSetFiles(regularFileMap, entityMap.subject ?: "NA", entityMap.session ?: "NA", entityMap.run ?: "NA", virtualSuffixKey, suffixConfig)) {
                    // Create parts structure: nii: {mag: file, phase: file}, json: file
                    def allFiles = [:]
                    
                    // Add JSON file
                    def jsonFile = filesByExtAndPart.get('json')
                    if (jsonFile) {
                        allFiles['json'] = jsonFile
                    }
                    
                    // Create nii parts map
                    def niiPartsMap = [:]
                    partsConfig.each { partValue ->
                        def niiKey = filesByExtAndPart.keySet().find { it == "nii_${partValue}" || it == "nii.gz_${partValue}" }
                        if (niiKey) {
                            niiPartsMap[partValue] = filesByExtAndPart[niiKey]
                        }
                    }
                    
                    if (niiPartsMap.size() == partsConfig.size()) {
                        // All parts present - use parts structure
                        allFiles['nii'] = niiPartsMap
                        tuple(entityValues + [virtualSuffixKey], allFiles)
                    } else {
                        // Fall back to regular processing if not all parts are present
                        def regularNiiFiles = filesByExtAndPart.findAll { key, path -> 
                            key == 'nii' || key == 'nii.gz' 
                        }
                        if (regularNiiFiles.size() > 0) {
                            // Always use 'nii' key for consistency
                            allFiles['nii'] = regularNiiFiles.values().first()
                            tuple(entityValues + [virtualSuffixKey], allFiles)
                        } else {
                            null
                        }
                    }
                } else {
                    null
                }
            } else {
                // Regular plain set processing
                def fileMap = [:]
                extFiles.each { extension, filePath, partValue, hasPartsConfigFile ->
                    fileMap[extension] = filePath
                }
                
                if (validatePlainSetFiles(fileMap, entityMap.subject ?: "NA", entityMap.session ?: "NA", entityMap.run ?: "NA", virtualSuffixKey, suffixConfig)) {
                    def allFiles = buildChannelData(fileMap, suffixConfig)
                    tuple(entityValues + [virtualSuffixKey], allFiles)
                } else {
                    null
                }
            }
        }
        .filter { it != null }

    finalGroups = input_pairs
        .map { groupingKeyWithSuffix, fileMap ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffix[0..entityCount-1]
            def virtualSuffixKey = groupingKeyWithSuffix[entityCount]
            
            tuple(entityValues, [virtualSuffixKey, fileMap])
        }
        .groupTuple()
        .map { groupingKey, suffixFileMaps ->
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = groupingKey[index] ?: "NA"
            }
            
            def allPlainMaps = [:]
            def allFilePaths = []
            
            suffixFileMaps.each { virtualSuffixKey, fileMap ->
                allPlainMaps[virtualSuffixKey] = fileMap
                allFilePaths.addAll(fileMap.values())
            }

            tuple(groupingKey, [allPlainMaps, allFilePaths])
        }

    emit:
    finalGroups
}