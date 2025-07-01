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
            tuple([row.subject, row.session, row.run, row.suffix, row.extension], row.path)
        }

    input_pairs = input_files
        .map { subjectSessionRunSuffixExt, filePath ->
            def (subject, session, run, suffix, extension) = subjectSessionRunSuffixExt
            tuple([subject, session, run, suffix], [extension, filePath])
        }
        .groupTuple()
        .map { subjectSessionRunSuffix, extFiles ->
            def (subject, session, run, suffix) = subjectSessionRunSuffix
            def suffixConfig = config[suffix]
            
            def fileMap = createFileMap(extFiles)
            
            if (validatePlainSetFiles(fileMap, subject, session, run, suffix, suffixConfig)) {
                // Get all files from the file map
                def allFiles = [:]
                fileMap.each { extension, filePath ->
                    allFiles[extension] = filePath
                }
                tuple([subject, session, run, suffix], allFiles)
            } else {
                null
            }
        }
        .filter { it != null }

    finalGroups = input_pairs
        .map { subjectSessionRunSuffix, fileMap ->
            def (subject, session, run, suffix) = subjectSessionRunSuffix
            
            def groupingKey = createGroupingKey(subject, session, run)
            tuple(groupingKey, [suffix, fileMap])
        }
        .groupTuple()
        .map { groupingKey, suffixFileMaps ->
            def subject = groupingKey[0]
            def session = groupingKey.size() > 1 ? groupingKey[1] : "NA"
            def run = groupingKey.size() > 2 ? groupingKey[2] : "NA"
            
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