include {
    handleError;
    logProgress;
    tryWithContext
} from '../modules/utils/error_handling.nf'
include {
    handlePartsLogic
} from '../modules/grouping/plain_set_utils.nf'

workflow emit_sequential_sets {
    take:
    parsed_csv
    config
    loopOverEntities

    main:
    
    // Input validation and parsing now done by calling workflow  
    logProgress("emit_sequential_sets", "Starting list collection workflow")
    
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
                    logProgress("emit_sequential_sets", "Validated multi-entity configuration for ${suffix}: ${entities.join(', ')}")
                } else {
                    logProgress("emit_sequential_sets", "Validated single-entity configuration for ${suffix}: ${entities[0]}")
                }
            }
        }
    }

    input_files = parsed_csv
        .splitCsv(header: true)
        .filter { row -> 
            config.containsKey(row.suffix) && 
            config[row.suffix].containsKey('sequential_set')
        }
        .map { row -> 
            def suffixConfig = config[row.suffix].sequential_set
            
            // Handle both single entity (by_entity) and multiple entities (by_entities)
            def entityKeys = suffixConfig.containsKey('by_entities') ? 
                suffixConfig.by_entities : [suffixConfig.by_entity]
            
            // Get ordering preference (hierarchical vs flat)
            def orderType = suffixConfig.containsKey('order') ? suffixConfig.order : 'hierarchical'
            
            // Extract entity values for all specified entities
            def sequentialEntityValues = []
            def allEntitiesPresent = true
            
            // Debug: Log the row content
            //log.info "Row data: ${row}"
            //log.info "Entity keys to extract: ${entityKeys}"
            
            entityKeys.each { entityKey ->
                def entityValue = row[entityKey]
              //  log.info "Extracting ${entityKey}: ${entityValue}"
                if (entityValue) {
                    sequentialEntityValues << entityValue
                } else {
                    allEntitiesPresent = false
                }
            }
            
            //log.info "Final entity values: ${sequentialEntityValues}"
            
            if (allEntitiesPresent) {
                // Create composite key for multiple entities, or single key for single entity
                def compositeEntityKey = entityKeys.join('_')
                def compositeEntityValue = sequentialEntityValues.join('_')
                def entityGroupValues = loopOverEntities.collect { entity -> 
                    def value = row.containsKey(entity) ? row[entity] : "NA"
                    return (value == null || value == "") ? "NA" : value
                }
                tuple(entityGroupValues + [row.suffix, compositeEntityKey], [entityKeys, sequentialEntityValues, orderType, row.extension, row.path])
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
            def compositeEntityKey = groupingKeyWithSuffixEntity[entityCount+1]
            def (entityKeys, sequentialEntityValues, orderType, extension, filePath) = entityData
            tuple(entityValues + [suffix], [entityKeys, sequentialEntityValues, orderType, extension, filePath])
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
            
            entityFiles.each { entityKeys, sequentialEntityValues, orderType, extension, filePath ->
                if (!entityKeysRef) entityKeysRef = entityKeys
                if (!orderTypeRef) orderTypeRef = orderType
                
                // Create hierarchical key structure
                def currentMap = fileMap
                for (int i = 0; i < sequentialEntityValues.size() - 1; i++) {
                    def entityValue = sequentialEntityValues[i]
                    if (!currentMap.containsKey(entityValue)) {
                        currentMap[entityValue] = [:]
                    }
                    currentMap = currentMap[entityValue]
                }
                
                // At the final level, store extension-to-path mapping
                def finalEntityValue = sequentialEntityValues[-1]
                if (!currentMap.containsKey(finalEntityValue)) {
                    currentMap[finalEntityValue] = [:]
                }
                if (!currentMap[finalEntityValue].containsKey(extension)) {
                    currentMap[finalEntityValue][extension] = []
                }
                currentMap[finalEntityValue][extension] << filePath
                allFilePaths << filePath
            }
            
            // Create separate lists for nii and json files with hierarchical ordering
            def niiFiles = []
            def jsonFiles = []
            
            // Create nested array structure for multi-dimensional access
            def createNestedArrays
            createNestedArrays = { currentMap, depth ->
                if (depth == entityKeysRef.size() - 1) {
                    // At final entity level, collect extension files as arrays
                    def sortedFinalKeys = currentMap.keySet().sort { a, b ->
                        def aNum = (a =~ /(\d+)$/)[0] ? Integer.parseInt((a =~ /(\d+)$/)[0][1]) : 0
                        def bNum = (b =~ /(\d+)$/)[0] ? Integer.parseInt((b =~ /(\d+)$/)[0][1]) : 0
                        return aNum <=> bNum
                    }
                    
                    def niiGroup = []
                    def jsonGroup = []
                    
                    sortedFinalKeys.each { finalKey ->
                        def extMap = currentMap[finalKey]
                        
                        // Apply parts logic if configured
                        def suffixConfig = config[suffix]
                        def hasPartsConfig = suffixConfig.containsKey('sequential_set') && 
                                           suffixConfig.sequential_set.containsKey('parts')
                        
                        if (hasPartsConfig) {
                            // Handle parts logic for sequential sets
                            def partsConfig = suffixConfig.sequential_set.parts
                            def localJsonFiles = extMap.get('json', [])
                            def localNiiFiles = extMap.get('nii', []) + extMap.get('nii.gz', [])
                            
                            if (localJsonFiles.size() > 0) {
                                def jsonFile = localJsonFiles[0]  // Take the first JSON file
                                
                                // Find corresponding part files
                                def partFiles = []
                                partsConfig.each { partValue ->
                                    def matchingFile = localNiiFiles.find { niiPath ->
                                        new File(niiPath).name.contains("_part-${partValue}")
                                    }
                                    if (matchingFile) {
                                        partFiles << matchingFile
                                    }
                                }
                                
                                // If we have all required parts, add them as an array
                                if (partFiles.size() == partsConfig.size()) {
                                    niiGroup << partFiles  // Add the array of part files
                                    jsonGroup << jsonFile
                                }
                            }
                        } else {
                            // Regular processing for sequential sets without parts
                            def localNiiFiles = extMap.get('nii', []) + extMap.get('nii.gz', [])
                            def localJsonFiles = extMap.get('json', [])
                            
                            if (localNiiFiles.size() > 0 && localJsonFiles.size() > 0) {
                                niiGroup << localNiiFiles[0]  // Take first nii file
                                jsonGroup << localJsonFiles[0]  // Take first json file
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
                        def result = createNestedArrays(currentMap[key], depth + 1)
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
                            
                            // Apply parts logic if configured
                            def suffixConfig = config[suffix]
                            def hasPartsConfig = suffixConfig.containsKey('sequential_set') && 
                                               suffixConfig.sequential_set.containsKey('parts')
                            
                            if (hasPartsConfig) {
                                // Handle parts logic for sequential sets
                                def partsConfig = suffixConfig.sequential_set.parts
                                def localJsonFileList = extMap.get('json', [])
                                def localNiiFileList = extMap.get('nii', []) + extMap.get('nii.gz', [])
                                
                                if (localJsonFileList.size() > 0) {
                                    def jsonFile = localJsonFileList[0]  // Take the first JSON file
                                    
                                    // Find corresponding part files
                                    def partFiles = []
                                    partsConfig.each { partValue ->
                                        def matchingFile = localNiiFileList.find { niiPath ->
                                            new File(niiPath).name.contains("_part-${partValue}")
                                        }
                                        if (matchingFile) {
                                            partFiles << matchingFile
                                        }
                                    }
                                    
                                    // If we have all required parts, add them as an array
                                    if (partFiles.size() == partsConfig.size()) {
                                        niiFiles << partFiles  // Add the array of part files
                                        jsonFiles << jsonFile
                                    }
                                }
                            } else {
                                // Regular processing for sequential sets without parts
                                def localNiiFileList = extMap.get('nii', []) + extMap.get('nii.gz', [])
                                def localJsonFileList = extMap.get('json', [])
                                
                                if (localNiiFileList.size() > 0 && localJsonFileList.size() > 0) {
                                    niiFiles << localNiiFileList[0]  // Take first nii file
                                    jsonFiles << localJsonFileList[0]  // Take first json file
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
                            collectFlat(currentMap[key], depth + 1)
                        }
                    }
                }
                collectFlat(fileMap, 0)
            } else {
                // Multi-entity with hierarchical ordering - create nested array structure
                def nestedResult = createNestedArrays(fileMap, 0)
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