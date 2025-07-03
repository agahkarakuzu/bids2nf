include { 
    findMatchingGrouping; 
    createFileMap; 
    validateRequiredFiles;
    validateRequiredFilesWithConfig; 
    createGroupingKey 
} from '../modules/grouping/entity_grouping_utils.nf'
include {
    handleError;
    logProgress;
    tryWithContext
} from '../modules/utils/error_handling.nf'

def getTargetSuffix(configKey, configValue) {
    return (configValue instanceof Map && configValue.containsKey('suffix_maps_to')) ? configValue.suffix_maps_to : configKey
}

def findMatchingVirtualConfig(row, config) {
    def candidateConfigs = config.findAll { configKey, configValue ->
        def targetSuffix = getTargetSuffix(configKey, configValue)
        return targetSuffix == row.suffix && configValue instanceof Map && configValue.containsKey('mixed_set')
    }
    
    // For mixed sets, any candidate can process the file (no strict entity requirements)
    return candidateConfigs.size() > 0 ? [configKey: candidateConfigs.entrySet().first().key, configValue: candidateConfigs.entrySet().first().value] : null
}

def normalizeEntityValue(value) {
    // Normalize entity values to handle different zero-padding
    // e.g., "flip-02" and "flip-2" should both match
    if (value && value.contains('-')) {
        def parts = value.split('-')
        if (parts.length == 2) {
            def prefix = parts[0]
            def suffix = parts[1]
            // If suffix is numeric, remove leading zeros for comparison
            if (suffix.isNumber()) {
                def numericSuffix = Integer.parseInt(suffix)
                return "${prefix}-${numericSuffix}"
            }
        }
    }
    return value
}

def entityValuesMatch(rowValue, configValue) {
    // Compare entity values with normalization
    if (!rowValue || !configValue) {
        return rowValue == configValue
    }
    return normalizeEntityValue(rowValue) == normalizeEntityValue(configValue)
}

def findMatchingMixedGrouping(row, mixedConfig) {
    // Find matching named group based on named_dimension
    def namedDimension = mixedConfig.named_dimension
    def namedGroups = mixedConfig.named_groups
    
    for (entry in namedGroups) {
        def groupingName = entry.key
        def groupingConfig = entry.value
        
        def matches = groupingConfig.every { entity, value ->
            entity == 'description' || entityValuesMatch(row[entity], value)
        }
        
        if (matches) {
            return groupingName
        }
    }
    return null
}

workflow emit_mixed_sets {
    take:
    parsed_csv
    config
    loopOverEntities

    main:
    
    // Input validation and parsing now done by calling workflow
    logProgress("emit_mixed_sets", "Creating mixed set channels ...")

    // Process files with mixed set configuration
    input_files = parsed_csv
        .splitCsv(header: true)
        .filter { row -> 
            def matchingConfig = findMatchingVirtualConfig(row, config)
            return matchingConfig != null
        }
        .map { row -> 
            def matchingConfig = findMatchingVirtualConfig(row, config)
            def virtualSuffixKey = matchingConfig.configKey
            def suffixConfig = matchingConfig.configValue
            def mixedConfig = suffixConfig.mixed_set
            def groupName = findMatchingMixedGrouping(row, mixedConfig)
            
            if (groupName) {
                // Extract sequential dimension value (e.g., echo number)
                def sequentialDimension = mixedConfig.sequential_dimension
                def sequentialValue = row[sequentialDimension]
                
                if (sequentialValue) {
                    // Check if parts configuration exists
                    def hasPartsConfig = mixedConfig.containsKey('parts')
                    def partValue = hasPartsConfig ? (row.part ?: "NA") : "NA"
                    
                    // Create dynamic grouping key based on loop_over entities
                    def entityValues = loopOverEntities.collect { entity -> 
                        def value = row.containsKey(entity) ? row[entity] : "NA"
                        return (value == null || value == "") ? "NA" : value
                    }
                    tuple(entityValues + [virtualSuffixKey, groupName, sequentialValue, row.extension], [row.path, partValue, hasPartsConfig])
                } else {
                    null
                }
            } else {
                null
            }
        }
        .filter { it != null }

    // Group by sequential dimension within each named group
    sequential_groups = input_files
        .map { groupingKeyWithExtras, fileData ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithExtras[0..entityCount-1]
            def virtualSuffixKey = groupingKeyWithExtras[entityCount]
            def groupName = groupingKeyWithExtras[entityCount+1]
            def sequentialValue = groupingKeyWithExtras[entityCount+2]
            def extension = groupingKeyWithExtras[entityCount+3]
            def (filePath, partValue, hasPartsConfig) = fileData
            
            tuple(entityValues + [virtualSuffixKey, groupName, sequentialValue], [extension, filePath, partValue, hasPartsConfig])
        }
        .groupTuple()
        .map { groupingKeyWithGroupSeq, extFiles ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithGroupSeq[0..entityCount-1]
            def virtualSuffixKey = groupingKeyWithGroupSeq[entityCount]
            def groupName = groupingKeyWithGroupSeq[entityCount+1]
            def sequentialValue = groupingKeyWithGroupSeq[entityCount+2]
            
            def suffixConfig = config[virtualSuffixKey]
            def mixedConfig = suffixConfig.mixed_set
            def hasPartsConfig = mixedConfig.containsKey('parts')
            def partsConfig = hasPartsConfig ? mixedConfig.parts : null
            
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = entityValues[index]
            }
            
            if (hasPartsConfig) {
                // Handle parts logic for mixed sets
                def filesByExtAndPart = [:]
                
                extFiles.each { extension, filePath, partValue, hasPartsConfigFile ->
                    if (partValue && partValue != "NA") {
                        def key = "${extension}_${partValue}"
                        filesByExtAndPart[key] = filePath
                    } else {
                        filesByExtAndPart[extension] = filePath
                    }
                }
                
                // Validate using regular file map
                def regularFileMap = [:]
                filesByExtAndPart.each { key, path ->
                    if (!key.contains('_')) {
                        regularFileMap[key] = path
                    }
                }
                
                if (validateRequiredFilesWithConfig(regularFileMap, entityMap.subject ?: "NA", entityMap.session ?: "NA", entityMap.run ?: "NA", virtualSuffixKey, "${groupName}_${sequentialValue}", suffixConfig)) {
                    // Create parts structure
                    def jsonFile = filesByExtAndPart.get('json')
                    
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
                        tuple(entityValues + [virtualSuffixKey, groupName], [sequentialValue, niiPartsMap, jsonFile])
                    } else {
                        // Fall back to regular processing if not all parts are present
                        def regularNiiFiles = filesByExtAndPart.findAll { key, path -> 
                            key == 'nii' || key == 'nii.gz' 
                        }
                        if (regularNiiFiles.size() > 0) {
                            def niiFile = regularNiiFiles.values().first()
                            tuple(entityValues + [virtualSuffixKey, groupName], [sequentialValue, niiFile, jsonFile])
                        } else {
                            null
                        }
                    }
                } else {
                    null
                }
            } else {
                // Regular processing without parts
                def fileMap = [:]
                extFiles.each { extension, filePath, partValue, hasPartsConfigFile ->
                    fileMap[extension] = filePath
                }
                
                if (validateRequiredFilesWithConfig(fileMap, entityMap.subject ?: "NA", entityMap.session ?: "NA", entityMap.run ?: "NA", virtualSuffixKey, "${groupName}_${sequentialValue}", suffixConfig)) {
                    def niiFile = fileMap.containsKey('nii.gz') ? fileMap['nii.gz'] : fileMap['nii']
                    def jsonFile = fileMap['json']
                    tuple(entityValues + [virtualSuffixKey, groupName], [sequentialValue, niiFile, jsonFile])
                } else {
                    null
                }
            }
        }
        .filter { it != null }

    // Group by named groups and create sequential arrays
    named_groups = sequential_groups
        .map { groupingKeyWithSuffixGroup, seqNiiJson ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffixGroup[0..entityCount-1]
            def virtualSuffixKey = groupingKeyWithSuffixGroup[entityCount]
            def groupName = groupingKeyWithSuffixGroup[entityCount+1]
            def (sequentialValue, niiFile, jsonFile) = seqNiiJson
            
            // Use only entity values as grouping key
            tuple(entityValues, [virtualSuffixKey, groupName, sequentialValue, niiFile, jsonFile])
        }
        .groupTuple()
        .map { groupingKey, suffixGroupingFiles ->
            // Create entity map from grouping key
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = groupingKey[index] ?: "NA"
            }
            
            // Organize by suffix and named groups
            def allGroupingMaps = [:]
            def allFilePaths = []
            
            // Group files by suffix and named group
            def suffixGroups = [:]
            suffixGroupingFiles.each { virtualSuffixKey, groupName, sequentialValue, niiData, jsonFile ->
                if (!suffixGroups.containsKey(virtualSuffixKey)) {
                    suffixGroups[virtualSuffixKey] = [:]
                }
                if (!suffixGroups[virtualSuffixKey].containsKey(groupName)) {
                    suffixGroups[virtualSuffixKey][groupName] = []
                }
                suffixGroups[virtualSuffixKey][groupName] << [sequentialValue, niiData, jsonFile]
                
                // Add file paths for tracking
                if (niiData instanceof Map) {
                    // Parts structure: add all part files
                    niiData.each { partName, filePath -> allFilePaths << filePath }
                } else {
                    // Regular structure: add single nii file
                    allFilePaths << niiData
                }
                allFilePaths << jsonFile
            }
            
            // Sort sequential files and create final structure
            suffixGroups.each { virtualSuffixKey, groups ->
                if (!allGroupingMaps.containsKey(virtualSuffixKey)) {
                    allGroupingMaps[virtualSuffixKey] = [:]
                }
                
                groups.each { groupName, seqFiles ->
                    // Sort by sequential value (extract numeric part)
                    def sortedFiles = seqFiles.sort { a, b ->
                        def aNum = (a[0] =~ /(\d+)$/)[0] ? Integer.parseInt((a[0] =~ /(\d+)$/)[0][1]) : 0
                        def bNum = (b[0] =~ /(\d+)$/)[0] ? Integer.parseInt((b[0] =~ /(\d+)$/)[0][1]) : 0
                        return aNum <=> bNum
                    }
                    
                    // Create arrays of nii and json files
                    def niiData = sortedFiles.collect { it[1] }
                    def jsonFiles = sortedFiles.collect { it[2] }
                    
                    allGroupingMaps[virtualSuffixKey][groupName] = [
                        'nii': niiData,
                        'json': jsonFiles
                    ]
                }
            }

            // Validate that all required named groups are present
            def allComplete = allGroupingMaps.every { virtualSuffixKey, groupingMap ->
                def suffixConfig = config[virtualSuffixKey]
                def mixedConfig = suffixConfig.mixed_set
                def requiredGroups = mixedConfig.containsKey('required') ? mixedConfig.required : mixedConfig.named_groups.keySet()
                
                def hasAllGroupings = requiredGroups.every { requiredGrouping ->
                    groupingMap.containsKey(requiredGrouping)
                }
                if (!hasAllGroupings) {
                    def entityDesc = loopOverEntities.collect { entity -> "${entity}: ${entityMap[entity]}" }.join(", ")
                    log.warn "Entities ${entityDesc}, Suffix ${virtualSuffixKey}: Missing required named groups. Available: ${groupingMap.keySet()}, Required: ${requiredGroups}"
                    return false
                }
                return true
            }
            
            if (allComplete) {
                tuple(groupingKey, [allGroupingMaps, allFilePaths])
            } else {
                null
            }
        }
        .filter { it != null }

    emit:
    named_groups
}