include {
    handleError;
    logProgress;
    logDebug;
    tryWithContext
} from '../modules/utils/error_handling.nf'

def getTargetSuffix(configKey, configValue) {
    // Return the actual BIDS suffix this config targets
    return (configValue instanceof Map && configValue.containsKey('suffix_maps_to')) ? configValue.suffix_maps_to : configKey
}

def canProcessFileWithConfig(row, configValue) {
    // Check if this file can be processed by this configuration
    if (configValue instanceof Map && configValue.containsKey('sequential_set')) {
        def seqConfig = configValue.sequential_set
        def entityKeys = seqConfig.containsKey('by_entities') ? 
            seqConfig.by_entities : [seqConfig.by_entity]
        
        // Check if this file has all required entities
        return entityKeys.every { entityKey ->
            def entityValue = row[entityKey]
            return entityValue && entityValue != "NA"
        }
    }
    return true
}

def findMatchingVirtualConfig(row, config) {
    // Find all configs that target this suffix
    def candidateConfigs = config.findAll { configKey, configValue ->
        def targetSuffix = getTargetSuffix(configKey, configValue)
        return targetSuffix == row.suffix && configValue instanceof Map && configValue.containsKey('sequential_set')
    }
    
    // Test each candidate to see which one can actually process this file
    def matchingConfig = candidateConfigs.find { entry ->
        canProcessFileWithConfig(row, entry.value)
    }
    
    return matchingConfig ? [configKey: matchingConfig.key, configValue: matchingConfig.value] : null
}

workflow emit_sequential_sets {
    take:
    parsed_csv
    config
    loopOverEntities

    main:
    
    // Input validation and parsing now done by calling workflow  
    logDebug("emit_sequential_sets", "Starting list collection workflow")
    
    // Validate multi-entity configurations
    config.each { suffix, suffixConfig ->
        if (suffixConfig instanceof Map && suffixConfig.containsKey('sequential_set')) {
            def seqConfig = suffixConfig.sequential_set
            if (seqConfig instanceof Map && seqConfig.containsKey('by_entities')) {
                def entities = seqConfig.by_entities
                if (!entities || entities.size() < 1) {
                    throw new IllegalArgumentException("Sequential_set for ${suffix} must specify at least 1 entity in 'by_entities' array")
                }
                if (entities.size() > 1) {
                    logDebug("emit_sequential_sets", "Validated multi-entity configuration for ${suffix}: ${entities.join(', ')}")
                } else {
                    logDebug("emit_sequential_sets", "Validated single-entity configuration for ${suffix}: ${entities[0]}")
                }
            }
        }
    }

    input_files = parsed_csv
        .splitCsv(header: true)
        .filter { row -> 
            // Check if there's any config (direct or virtual) that can handle this suffix
            def matchingConfig = findMatchingVirtualConfig(row, config)
            return matchingConfig != null
        }
        .map { row -> 
            // Find the matching virtual configuration for this row
            def matchingConfig = findMatchingVirtualConfig(row, config)
            if (!matchingConfig) {
                return null
            }
            
            def virtualSuffixKey = matchingConfig.configKey
            def suffixConfig = matchingConfig.configValue.sequential_set
            
            // Handle both single entity (by_entity) and multiple entities (by_entities)
            def entityKeys = suffixConfig.containsKey('by_entities') ? 
                suffixConfig.by_entities : [suffixConfig.by_entity]
            
            // Get ordering preference (hierarchical vs flat)
            def orderType = suffixConfig.containsKey('order') ? suffixConfig.order : 'hierarchical'
            
            // Check if parts configuration exists
            def hasPartsConfig = suffixConfig.containsKey('parts')
            def partsConfig = hasPartsConfig ? suffixConfig.parts : null
            
            // Extract entity values for all specified entities
            def sequentialEntityValues = []
            def allEntitiesPresent = true
            
            entityKeys.each { entityKey ->
                def entityValue = row[entityKey]
                if (entityValue && entityValue != "NA") {
                    sequentialEntityValues << entityValue
                } else {
                    allEntitiesPresent = false
                }
            }
            
            if (allEntitiesPresent) {
                // Create composite key for multiple entities, or single key for single entity
                def compositeEntityKey = entityKeys.join('_')
                def entityGroupValues = loopOverEntities.collect { entity -> 
                    def value = row.containsKey(entity) ? row[entity] : "NA"
                    return (value == null || value == "") ? "NA" : value
                }
                
                // Include part value in the row data for parts processing
                def partValue = hasPartsConfig ? (row.part ?: "NA") : "NA"
                
                // Use virtual suffix key instead of actual suffix
                tuple(entityGroupValues + [virtualSuffixKey, compositeEntityKey], [entityKeys, sequentialEntityValues, orderType, row.extension, row.path, partValue, partsConfig])
            } else {
                null
            }
        }
        .filter { it != null }

    // Group by loop_over entities and suffix
    grouped_files = input_files
        .map { groupingKeyWithSuffixEntity, entityData ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffixEntity[0..entityCount-1]
            def suffix = groupingKeyWithSuffixEntity[entityCount]
            def (entityKeys, sequentialEntityValues, orderType, extension, filePath, partValue, partsConfig) = entityData
            tuple(entityValues + [suffix], [entityKeys, sequentialEntityValues, orderType, extension, filePath, partValue, partsConfig])
        }
        .groupTuple()
        .map { groupingKeyWithSuffix, entityFiles ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffix[0..entityCount-1]
            def suffix = groupingKeyWithSuffix[entityCount]
            
            // Create file lists grouped by entity values (handles both single and multiple entities)
            def fileMap = [:]
            def allFilePaths = []
            def entityKeysRef = null
            def orderTypeRef = null
            
            // Check if this is a parts-enabled sequential set
            def hasPartsConfig = false
            def partsConfigRef = null
            
            entityFiles.each { entityKeys, sequentialEntityValues, orderType, extension, filePath, partValue, partsConfig ->
                if (!entityKeysRef) entityKeysRef = entityKeys
                if (!orderTypeRef) orderTypeRef = orderType
                if (partsConfig && !hasPartsConfig) {
                    hasPartsConfig = true
                    partsConfigRef = partsConfig
                }
                
                // Create hierarchical key structure
                def currentMap = fileMap
                (0..<sequentialEntityValues.size() - 1).each { i ->
                    def entityValue = sequentialEntityValues[i]
                    if (!currentMap.containsKey(entityValue)) {
                        currentMap[entityValue] = [:]
                    }
                    currentMap = currentMap[entityValue]
                }
                
                // At the final level, store files grouped by entity and part (if applicable)
                def finalEntityValue = sequentialEntityValues[-1]
                if (!currentMap.containsKey(finalEntityValue)) {
                    currentMap[finalEntityValue] = [:]
                }
                
                if (hasPartsConfig && partValue && partValue != "NA") {
                    // For parts: group by extension and part
                    def key = "${extension}_${partValue}"
                    currentMap[finalEntityValue][key] = filePath
                } else {
                    // Regular processing: group by extension only
                    if (!currentMap[finalEntityValue].containsKey(extension)) {
                        currentMap[finalEntityValue][extension] = []
                    }
                    currentMap[finalEntityValue][extension] << filePath
                }
                allFilePaths << filePath
            }
            
            // Create separate lists for nii and json files with hierarchical ordering
            def niiFiles = []
            def jsonFiles = []
            
            // Create nested array structure for multi-dimensional access
            def createNestedArrays
            createNestedArrays = { currentMap, depth ->
                if (depth == entityKeysRef.size() - 1) {
                    // At final entity level, collect files
                    def sortedFinalKeys = currentMap.keySet().sort { a, b ->
                        def aNum = (a =~ /(\d+)$/)[0] ? Integer.parseInt((a =~ /(\d+)$/)[0][1]) : 0
                        def bNum = (b =~ /(\d+)$/)[0] ? Integer.parseInt((b =~ /(\d+)$/)[0][1]) : 0
                        return aNum <=> bNum
                    }
                    
                    def niiGroup = []
                    def jsonGroup = []
                    
                    sortedFinalKeys.each { finalKey ->
                        def extMap = currentMap[finalKey]
                        
                        // Always check for JSON file first
                        def jsonFile = null
                        def jsonList = extMap.get('json', [])
                        if (jsonList && jsonList.size() > 0) {
                            jsonFile = jsonList instanceof List ? jsonList[0] : jsonList
                        } else {
                            // Look for json files with part extensions
                            def jsonKey = extMap.keySet().find { it.startsWith('json_') }
                            if (jsonKey) jsonFile = extMap[jsonKey]
                        }
                        
                        if (jsonFile) {
                            if (hasPartsConfig && partsConfigRef) {
                                // Try parts logic first
                                def partFilesMap = [:]
                                partsConfigRef.each { partValue ->
                                    def niiKey = extMap.keySet().find { it == "nii_part-${partValue}" || it == "nii.gz_part-${partValue}" }
                                    if (niiKey) {
                                        partFilesMap[partValue] = extMap[niiKey]
                                    }
                                }
                                
                                // If we have all required parts, use parts structure
                                if (partFilesMap.size() == partsConfigRef.size()) {
                                    niiGroup << partFilesMap  // Add the map of part files: {mag: file, phase: file}
                                    jsonGroup << jsonFile
                                } else {
                                    // Fall back to regular processing if not all parts are present
                                    def niiFileList = extMap.get('nii', []) + extMap.get('nii.gz', [])
                                    if (niiFileList.size() > 0) {
                                        niiGroup << niiFileList[0]  // Take first nii file
                                        jsonGroup << jsonFile
                                    }
                                }
                            } else {
                                // Regular processing for sequential sets without parts config
                                def niiFileList = extMap.get('nii', []) + extMap.get('nii.gz', [])
                                if (niiFileList.size() > 0) {
                                    niiGroup << niiFileList[0]  // Take first nii file
                                    jsonGroup << jsonFile
                                }
                            }
                        }
                    }
                    
                    return [nii: niiGroup, json: jsonGroup]
                } else {
                    // At intermediate level, create nested arrays
                    def sortedKeys = currentMap.keySet().sort { a, b ->
                        def aNum = (a =~ /(\d+)$/)[0] ? Integer.parseInt((a =~ /(\d+)$/)[0][1]) : 0
                        def bNum = (b =~ /(\d+)$/)[0] ? Integer.parseInt((b =~ /(\d+)$/)[0][1]) : 0
                        return aNum <=> bNum
                    }
                    
                    def niiNestedArray = []
                    def jsonNestedArray = []
                    
                    sortedKeys.each { key ->
                        def result = createNestedArrays.call(currentMap[key], depth + 1)
                        niiNestedArray << result.nii
                        jsonNestedArray << result.json
                    }
                    
                    return [nii: niiNestedArray, json: jsonNestedArray]
                }
            }
            
            // Create structure based on order type and entity count
            if (entityKeysRef.size() == 1 || orderTypeRef == 'flat') {
                // Single entity or flat ordering - create flat structure
                def collectFlat
                collectFlat = { currentMap, depth ->
                    if (depth == entityKeysRef.size() - 1) {
                        def sortedFinalKeys = currentMap.keySet().sort { a, b ->
                            def aNum = (a =~ /(\d+)$/)[0] ? Integer.parseInt((a =~ /(\d+)$/)[0][1]) : 0
                            def bNum = (b =~ /(\d+)$/)[0] ? Integer.parseInt((b =~ /(\d+)$/)[0][1]) : 0
                            return aNum <=> bNum
                        }
                        sortedFinalKeys.each { finalKey ->
                            def extMap = currentMap[finalKey]
                            
                            // Always check for JSON file first
                            def jsonFile = null
                            def jsonList = extMap.get('json', [])
                            if (jsonList && jsonList.size() > 0) {
                                jsonFile = jsonList instanceof List ? jsonList[0] : jsonList
                            } else {
                                // Look for json files with part extensions
                                def jsonKey = extMap.keySet().find { it.startsWith('json_') }
                                if (jsonKey) jsonFile = extMap[jsonKey]
                            }
                            
                            if (jsonFile) {
                                if (hasPartsConfig && partsConfigRef) {
                                    // Try parts logic first
                                    def partFilesMap = [:]
                                    partsConfigRef.each { partValue ->
                                        def niiKey = extMap.keySet().find { it == "nii_part-${partValue}" || it == "nii.gz_part-${partValue}" }
                                        if (niiKey) {
                                            partFilesMap[partValue] = extMap[niiKey]
                                        }
                                    }
                                    
                                    // If we have all required parts, use parts structure
                                    if (partFilesMap.size() == partsConfigRef.size()) {
                                        niiFiles << partFilesMap  // Add the map of part files: {mag: file, phase: file}
                                        jsonFiles << jsonFile
                                    } else {
                                        // Fall back to regular processing if not all parts are present
                                        def niiFileList = extMap.get('nii', []) + extMap.get('nii.gz', [])
                                        if (niiFileList.size() > 0) {
                                            niiFiles << niiFileList[0]  // Take first nii file
                                            jsonFiles << jsonFile
                                        }
                                    }
                                } else {
                                    // Regular processing for sequential sets without parts config
                                    def niiFileList = extMap.get('nii', []) + extMap.get('nii.gz', [])
                                    if (niiFileList.size() > 0) {
                                        niiFiles << niiFileList[0]  // Take first nii file
                                        jsonFiles << jsonFile
                                    }
                                }
                            }
                        }
                    } else {
                        def sortedKeys = currentMap.keySet().sort { a, b ->
                            def aNum = (a =~ /(\d+)$/)[0] ? Integer.parseInt((a =~ /(\d+)$/)[0][1]) : 0
                            def bNum = (b =~ /(\d+)$/)[0] ? Integer.parseInt((b =~ /(\d+)$/)[0][1]) : 0
                            return aNum <=> bNum
                        }
                        sortedKeys.each { key ->
                            collectFlat.call(currentMap[key], depth + 1)
                        }
                    }
                }
                collectFlat.call(fileMap, 0)
            } else {
                // Multi-entity with hierarchical ordering - create nested array structure
                def nestedResult = createNestedArrays.call(fileMap, 0)
                niiFiles = nestedResult.nii
                jsonFiles = nestedResult.json
            }
            
            def validPairs = ['nii': niiFiles, 'json': jsonFiles]
            
            if (niiFiles.size() > 0) {
                def suffixMap = [:]
                suffixMap[suffix] = validPairs
                tuple(entityValues, [suffixMap, allFilePaths])
            } else {
                def entityMap = [:]
                loopOverEntities.eachWithIndex { entity, index ->
                    entityMap[entity] = entityValues[index] ?: "NA"
                }
                def entityDesc = loopOverEntities.collect { entity -> "${entity}: ${entityMap[entity]}" }.join(", ")
                log.warn "Entities ${entityDesc}, Suffix ${suffix}: No valid file pairs found"
                null
            }
        }
        .filter { it != null }

    emit:
    grouped_files
}