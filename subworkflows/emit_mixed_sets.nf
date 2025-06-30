include { 
    findMatchingGrouping; 
    createFileMap; 
    validateRequiredFiles; 
    createGroupingKey 
} from '../modules/grouping/entity_grouping_utils.nf'
include {
    handleError;
    logProgress;
    tryWithContext
} from '../modules/utils/error_handling.nf'

def findMatchingMixedGrouping(row, mixedConfig) {
    // Find matching named group based on named_dimension
    def namedDimension = mixedConfig.named_dimension
    def namedGroups = mixedConfig.named_groups
    
    for (entry in namedGroups) {
        def groupingName = entry.key
        def groupingConfig = entry.value
        
        def matches = groupingConfig.every { entity, value ->
            entity == 'description' || row[entity] == value
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

    main:
    
    // Input validation and parsing now done by calling workflow
    logProgress("emit_mixed_sets", "Creating mixed set channels ...")

    // Process files with mixed set configuration
    input_files = parsed_csv
        .splitCsv(header: true)
        .filter { row -> 
            config.containsKey(row.suffix) && 
            config[row.suffix].containsKey('mixed_set')
        }
        .map { row -> 
            def suffixConfig = config[row.suffix]
            def mixedConfig = suffixConfig.mixed_set
            def groupName = findMatchingMixedGrouping(row, mixedConfig)
            
            if (groupName) {
                // Extract sequential dimension value (e.g., echo number)
                def sequentialDimension = mixedConfig.sequential_dimension
                def sequentialValue = row[sequentialDimension]
                
                if (sequentialValue) {
                    tuple([row.subject, row.session, row.run, row.suffix, groupName, sequentialValue, row.extension], row.path)
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
        .map { subjectSessionRunSuffixGroupSeqExt, filePath ->
            def (subject, session, run, suffix, groupName, sequentialValue, extension) = subjectSessionRunSuffixGroupSeqExt
            tuple([subject, session, run, suffix, groupName, sequentialValue], [extension, filePath])
        }
        .groupTuple()
        .map { subjectSessionRunSuffixGroupSeq, extFiles ->
            def (subject, session, run, suffix, groupName, sequentialValue) = subjectSessionRunSuffixGroupSeq
            
            def fileMap = createFileMap(extFiles)
            
            if (validateRequiredFiles(fileMap, subject, session, run, suffix, "${groupName}_${sequentialValue}")) {
                def niiFile = fileMap.containsKey('nii.gz') ? fileMap['nii.gz'] : fileMap['nii']
                def jsonFile = fileMap['json']
                tuple([subject, session, run, suffix, groupName], [sequentialValue, niiFile, jsonFile])
            } else {
                null
            }
        }
        .filter { it != null }

    // Group by named groups and create sequential arrays
    named_groups = sequential_groups
        .map { subjectSessionRunSuffixGroup, seqNiiJson ->
            def (subject, session, run, suffix, groupName) = subjectSessionRunSuffixGroup
            def (sequentialValue, niiFile, jsonFile) = seqNiiJson
            
            def groupingKey = createGroupingKey(subject, session, run)
            tuple(groupingKey, [suffix, groupName, sequentialValue, niiFile, jsonFile])
        }
        .groupTuple()
        .map { groupingKey, suffixGroupingFiles ->
            def subject = groupingKey[0]
            def session = groupingKey.size() > 1 ? groupingKey[1] : "NA"
            def run = groupingKey.size() > 2 ? groupingKey[2] : "NA"
            
            // Organize by suffix and named groups
            def allGroupingMaps = [:]
            def allFilePaths = []
            
            // Group files by suffix and named group
            def suffixGroups = [:]
            suffixGroupingFiles.each { suffix, groupName, sequentialValue, niiFile, jsonFile ->
                if (!suffixGroups.containsKey(suffix)) {
                    suffixGroups[suffix] = [:]
                }
                if (!suffixGroups[suffix].containsKey(groupName)) {
                    suffixGroups[suffix][groupName] = []
                }
                suffixGroups[suffix][groupName] << [sequentialValue, niiFile, jsonFile]
                allFilePaths << niiFile
                allFilePaths << jsonFile
            }
            
            // Sort sequential files and create final structure
            suffixGroups.each { suffix, groups ->
                if (!allGroupingMaps.containsKey(suffix)) {
                    allGroupingMaps[suffix] = [:]
                }
                
                groups.each { groupName, seqFiles ->
                    // Sort by sequential value (extract numeric part)
                    def sortedFiles = seqFiles.sort { a, b ->
                        def aNum = (a[0] =~ /(\d+)$/)[0] ? Integer.parseInt((a[0] =~ /(\d+)$/)[0][1]) : 0
                        def bNum = (b[0] =~ /(\d+)$/)[0] ? Integer.parseInt((b[0] =~ /(\d+)$/)[0][1]) : 0
                        return aNum <=> bNum
                    }
                    
                    // Create arrays of nii and json files
                    def niiFiles = sortedFiles.collect { it[1] }
                    def jsonFiles = sortedFiles.collect { it[2] }
                    
                    allGroupingMaps[suffix][groupName] = [
                        'nii': niiFiles,
                        'json': jsonFiles
                    ]
                }
            }

            // Validate that all required named groups are present
            def allComplete = allGroupingMaps.every { suffix, groupingMap ->
                def suffixConfig = config[suffix]
                def mixedConfig = suffixConfig.mixed_set
                def requiredGroups = mixedConfig.containsKey('required') ? mixedConfig.required : mixedConfig.named_groups.keySet()
                
                def hasAllGroupings = requiredGroups.every { requiredGrouping ->
                    groupingMap.containsKey(requiredGrouping)
                }
                if (!hasAllGroupings) {
                    log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Missing required named groups. Available: ${groupingMap.keySet()}, Required: ${requiredGroups}"
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