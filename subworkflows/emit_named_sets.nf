include { 
    findMatchingGrouping; 
    createFileMap; 
    validateRequiredFiles;
    validateRequiredFilesWithConfig; 
    createGroupingKey;
    buildChannelData
} from '../modules/grouping/entity_grouping_utils.nf'
include {
    handleError;
    logProgress;
    logDebug;
    tryWithContext
} from '../modules/utils/error_handling.nf'

def getTargetSuffix(configKey, configValue) {
    return (configValue instanceof Map && configValue.containsKey('suffix_maps_to')) ? configValue.suffix_maps_to : configKey
}

def findMatchingVirtualConfig(row, config) {
    def candidateConfigs = config.findAll { configKey, configValue ->
        def targetSuffix = getTargetSuffix(configKey, configValue)
        return targetSuffix == row.suffix && configValue instanceof Map && configValue.containsKey('named_set')
    }
    
    // For named sets, any candidate can process the file (no strict entity requirements)
    return candidateConfigs.size() > 0 ? [configKey: candidateConfigs.entrySet().first().key, configValue: candidateConfigs.entrySet().first().value] : null
}

workflow emit_named_sets {
    take:
    parsed_csv
    config
    loopOverEntities

    main:
    
    // Input validation and parsing now done by calling workflow
    logDebug("emit_named_sets", "Creating named set channels ...")

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
            def groupName = findMatchingGrouping(row, suffixConfig)
            
            if (groupName) {
                def entityValues = loopOverEntities.collect { entity -> 
                    def value = row.containsKey(entity) ? row[entity] : "NA"
                    return (value == null || value == "") ? "NA" : value
                }
                tuple(entityValues + [virtualSuffixKey, groupName, row.extension], row.path)
            } else {
                null
            }
        }
        .filter { it != null }

    input_pairs = input_files
        .map { groupingKeyWithExtras, filePath ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithExtras[0..entityCount-1]
            def suffix = groupingKeyWithExtras[entityCount]
            def groupName = groupingKeyWithExtras[entityCount+1]
            def extension = groupingKeyWithExtras[entityCount+2]
            
            tuple(entityValues + [suffix, groupName], [extension, filePath])
        }
        .groupTuple()
        .map { groupingKeyWithSuffixGroup, extFiles ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffixGroup[0..entityCount-1]
            def suffix = groupingKeyWithSuffixGroup[entityCount]
            def groupName = groupingKeyWithSuffixGroup[entityCount+1]
            
            def fileMap = createFileMap(extFiles)
            
            def suffixConfig = config[suffix]
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = entityValues[index]
            }
            
            if (validateRequiredFilesWithConfig(fileMap, entityMap.subject ?: "NA", entityMap.session ?: "NA", entityMap.run ?: "NA", suffix, groupName, suffixConfig)) {
                def channelData = buildChannelData(fileMap, suffixConfig)
                tuple(entityValues + [suffix, groupName], channelData)
            } else {
                null
            }
        }
        .filter { it != null }

    finalGroups = input_pairs
        .map { groupingKeyWithSuffixGroup, channelData ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffixGroup[0..entityCount-1]
            def suffix = groupingKeyWithSuffixGroup[entityCount]
            def groupName = groupingKeyWithSuffixGroup[entityCount+1]
            
            tuple(entityValues, [suffix, groupName, channelData])
        }
        .groupTuple()
        .map { groupingKey, suffixGroupingFiles ->
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = groupingKey[index] ?: "NA"
            }
            
            def allGroupingMaps = [:]
            def allFilePaths = []
            
            suffixGroupingFiles.each { suffix, groupName, channelData ->
                if (!allGroupingMaps.containsKey(suffix)) {
                    allGroupingMaps[suffix] = [:]
                }
                
                allGroupingMaps[suffix][groupName] = channelData
                allFilePaths.addAll(channelData.values())
            }

            // Validate each suffix configuration independently and filter out invalid ones
            def validGroupingMaps = [:]
            def validFilePaths = []
            
            allGroupingMaps.each { suffix, groupingMap ->
                def suffixConfig = config[suffix]
                def hasAllGroupings = suffixConfig.required.every { requiredGrouping ->
                    groupingMap.containsKey(requiredGrouping)
                }
                if (hasAllGroupings) {
                    validGroupingMaps[suffix] = groupingMap
                    validFilePaths.addAll(groupingMap.values().flatten())
                } else {
                    def entityDesc = loopOverEntities.collect { entity -> "${entity}: ${entityMap[entity]}" }.join(", ")
                    log.warn "Entities ${entityDesc}, Suffix ${suffix}: Missing required groupings. Available: ${groupingMap.keySet()}, Required: ${suffixConfig.required}"
                }
            }
            
            def allComplete = validGroupingMaps.size() > 0
            
            if (allComplete) {
                tuple(groupingKey, [validGroupingMaps, validFilePaths])
            } else {
                null
            }
        }
        .filter { it != null }

    emit:
    finalGroups
}