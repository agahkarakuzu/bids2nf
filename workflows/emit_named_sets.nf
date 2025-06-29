import org.yaml.snakeyaml.Yaml
include { libbids_sh_parse } from '../modules/parsers/lib_bids_sh_parser.nf'
include { 
    findMatchingGrouping; 
    createFileMap; 
    validateRequiredFiles; 
    createGroupingKey 
} from '../modules/grouping/entity_grouping_utils.nf'
include { 
    validateAllInputs;
    validateBidsDirectory;
    validateBids2nfConfig;
    validateLibBidsScript
} from '../modules/parsers/bids_validator.nf'
include {
    handleError;
    logProgress;
    tryWithContext
} from '../modules/utils/error_handling.nf'

workflow emit_named_sets {
    take:
    bids_dir
    bids2nf_config

    main:
    
    // Input validation
    logProgress("emit_named_sets", "Creating named set channels ...")
    
    // Validate all inputs before processing
    tryWithContext("INPUT_VALIDATION") {
        validateAllInputs(bids_dir, bids2nf_config, params.libbids_sh)
    }
    
    logProgress("emit_named_sets", "Input validation completed successfully")
    
    // Parse BIDS directory
    parsed_csv = tryWithContext("BIDS_PARSING") {
        libbids_sh_parse(bids_dir, params.libbids_sh)
    }
    
    // Load and validate configuration
    def config = tryWithContext("CONFIG_LOADING") {
        new Yaml().load(new FileReader(bids2nf_config))
    }

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
            
            if (validateRequiredFiles(fileMap, subject, session, run, suffix, groupName)) {
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