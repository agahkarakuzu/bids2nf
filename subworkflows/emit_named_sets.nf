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

workflow emit_named_sets {
    take:
    parsed_csv
    config
    loopOverEntities

    main:
    
    // Input validation and parsing now done by calling workflow
    logProgress("emit_named_sets", "Creating named set channels ...")

    input_files = parsed_csv
        .splitCsv(header: true)
        .filter { row -> 
            config.containsKey(row.suffix) && 
            config[row.suffix].containsKey('named_set')
        }
        .map { row -> 
            def suffixConfig = config[row.suffix]
            def groupName = findMatchingGrouping(row, suffixConfig)
            
            if (groupName) {
                def entityValues = loopOverEntities.collect { entity -> 
                    def value = row.containsKey(entity) ? row[entity] : "NA"
                    return (value == null || value == "") ? "NA" : value
                }
                tuple(entityValues + [row.suffix, groupName, row.extension], row.path)
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
                def niiFile = fileMap.containsKey('nii.gz') ? fileMap['nii.gz'] : fileMap['nii']
                def jsonFile = fileMap['json']
                tuple(entityValues + [suffix, groupName], [niiFile, jsonFile])
            } else {
                null
            }
        }
        .filter { it != null }

    finalGroups = input_pairs
        .map { groupingKeyWithSuffixGroup, niiJsonPair ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffixGroup[0..entityCount-1]
            def suffix = groupingKeyWithSuffixGroup[entityCount]
            def groupName = groupingKeyWithSuffixGroup[entityCount+1]
            def (niiFile, jsonFile) = niiJsonPair
            
            tuple(entityValues, [suffix, groupName, niiFile, jsonFile])
        }
        .groupTuple()
        .map { groupingKey, suffixGroupingFiles ->
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = groupingKey[index] ?: "NA"
            }
            
            def allGroupingMaps = [:]
            def allFilePaths = []
            
            suffixGroupingFiles.each { suffix, groupName, niiFile, jsonFile ->
                if (!allGroupingMaps.containsKey(suffix)) {
                    allGroupingMaps[suffix] = [:]
                }
                allGroupingMaps[suffix][groupName] = [
                    'nii': niiFile,
                    'json': jsonFile
                ]
                allFilePaths << niiFile
                allFilePaths << jsonFile
            }

            def allComplete = allGroupingMaps.every { suffix, groupingMap ->
                def suffixConfig = config[suffix]
                def hasAllGroupings = suffixConfig.required.every { requiredGrouping ->
                    groupingMap.containsKey(requiredGrouping)
                }
                if (!hasAllGroupings) {
                    def entityDesc = loopOverEntities.collect { entity -> "${entity}: ${entityMap[entity]}" }.join(", ")
                    log.warn "Entities ${entityDesc}, Suffix ${suffix}: Missing required groupings. Available: ${groupingMap.keySet()}, Required: ${suffixConfig.required}"
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
    finalGroups
}