include { 
    createFileMap; 
    createGroupingKey 
} from '../modules/grouping/entity_grouping_utils.nf'
include {
    validatePlainSetFiles
} from '../modules/grouping/plain_set_utils.nf'
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
            config.containsKey(row.suffix) && 
            config[row.suffix].containsKey('plain_set')
        }
        .map { row -> 
            def entityValues = loopOverEntities.collect { entity -> 
                def value = row.containsKey(entity) ? row[entity] : "NA"
                return (value == null || value == "") ? "NA" : value
            }
            tuple(entityValues + [row.suffix, row.extension], row.path)
        }

    input_pairs = input_files
        .map { groupingKeyWithSuffixExt, filePath ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffixExt[0..entityCount-1]
            def suffix = groupingKeyWithSuffixExt[entityCount]
            def extension = groupingKeyWithSuffixExt[entityCount+1]
            tuple(entityValues + [suffix], [extension, filePath])
        }
        .groupTuple()
        .map { groupingKeyWithSuffix, extFiles ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffix[0..entityCount-1]
            def suffix = groupingKeyWithSuffix[entityCount]
            def suffixConfig = config[suffix]
            
            def fileMap = createFileMap(extFiles)
            
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = entityValues[index]
            }
            
            if (validatePlainSetFiles(fileMap, entityMap.subject ?: "NA", entityMap.session ?: "NA", entityMap.run ?: "NA", suffix, suffixConfig)) {
                // Get all files from the file map
                def allFiles = [:]
                fileMap.each { extension, filePath ->
                    allFiles[extension] = filePath
                }
                tuple(entityValues + [suffix], allFiles)
            } else {
                null
            }
        }
        .filter { it != null }

    finalGroups = input_pairs
        .map { groupingKeyWithSuffix, fileMap ->
            def entityCount = loopOverEntities.size()
            def entityValues = groupingKeyWithSuffix[0..entityCount-1]
            def suffix = groupingKeyWithSuffix[entityCount]
            
            tuple(entityValues, [suffix, fileMap])
        }
        .groupTuple()
        .map { groupingKey, suffixFileMaps ->
            def entityMap = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityMap[entity] = groupingKey[index] ?: "NA"
            }
            
            def allPlainMaps = [:]
            def allFilePaths = []
            
            suffixFileMaps.each { suffix, fileMap ->
                allPlainMaps[suffix] = fileMap
                allFilePaths.addAll(fileMap.values())
            }

            tuple(groupingKey, [allPlainMaps, allFilePaths])
        }

    emit:
    finalGroups
}