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

    main:
    
    // Input validation and parsing now done by calling workflow
    logProgress("emit_named_sets", "Creating named set channels ...")

    input_files = parsed_csv
        .splitCsv(header: true)
        .filter { row -> config.containsKey(row.suffix) }
        .map { row -> 
            def suffixConfig = config[row.suffix]
            def groupName = findMatchingGrouping(row, suffixConfig)
            
            if (groupName) {
                tuple([row.subject, row.session, row.run, row.suffix, groupName, row.extension], row.path)
            } else {
                null
            }
        }
        .filter { it != null }

    input_pairs = input_files
        .map { subjectSessionRunSuffixGroupExt, filePath ->
            def (subject, session, run, suffix, groupName, extension) = subjectSessionRunSuffixGroupExt
            tuple([subject, session, run, suffix, groupName], [extension, filePath])
        }
        .groupTuple()
        .map { subjectSessionRunSuffixGroup, extFiles ->
            def (subject, session, run, suffix, groupName) = subjectSessionRunSuffixGroup
            
            def fileMap = createFileMap(extFiles)
            
            def suffixConfig = config[suffix]
            if (validateRequiredFilesWithConfig(fileMap, subject, session, run, suffix, groupName, suffixConfig)) {
                def niiFile = fileMap.containsKey('nii.gz') ? fileMap['nii.gz'] : fileMap['nii']
                def jsonFile = fileMap['json']
                tuple([subject, session, run, suffix, groupName], [niiFile, jsonFile])
            } else {
                null
            }
        }
        .filter { it != null }

    finalGroups = input_pairs
        .map { subjectSessionRunSuffixGroup, niiJsonPair ->
            def (subject, session, run, suffix, groupName) = subjectSessionRunSuffixGroup
            def (niiFile, jsonFile) = niiJsonPair
            
            def groupingKey = createGroupingKey(subject, session, run)
            tuple(groupingKey, [suffix, groupName, niiFile, jsonFile])
        }
        .groupTuple()
        .map { groupingKey, suffixGroupingFiles ->
            def subject = groupingKey[0]
            def session = groupingKey.size() > 1 ? groupingKey[1] : "NA"
            def run = groupingKey.size() > 2 ? groupingKey[2] : "NA"
            
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
                    log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Missing required groupings. Available: ${groupingMap.keySet()}, Required: ${suffixConfig.required}"
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