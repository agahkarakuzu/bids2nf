import org.yaml.snakeyaml.Yaml
include { libbids_sh_parse } from '../modules/parsers/lib_bids_sh_parser.nf'
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

workflow emit_sequential_sets {
    take:
    bids_dir
    bids2nf_config

    main:
    
    // Input validation
    logProgress("emit_sequential_sets", "Starting list collection workflow")
    
    // Validate all inputs before processing
    tryWithContext("INPUT_VALIDATION") {
        validateAllInputs(bids_dir, bids2nf_config, params.libbids_sh)
    }
    
    logProgress("emit_sequential_sets", "Input validation completed successfully")
    
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
        .filter { row -> 
            config.containsKey(row.suffix) && 
            config[row.suffix].containsKey('sequential_set')
        }
        .map { row -> 
            def suffixConfig = config[row.suffix].sequential_set
            def entityKey = suffixConfig.by_entity
            def entityValue = row[entityKey]
            
            if (entityValue) {
                tuple([row.subject, row.session, row.run, row.suffix, entityKey], [entityValue, row.extension, row.path])
            } else {
                null
            }
        }
        .filter { it != null }

    // Group by subject, session, run, suffix, entity
    grouped_files = input_files
        .map { subjectSessionRunSuffixEntity, entityExtPath ->
            def (subject, session, run, suffix, entityKey) = subjectSessionRunSuffixEntity
            def (entityValue, extension, filePath) = entityExtPath
            tuple([subject, session, run, suffix], [entityKey, entityValue, extension, filePath])
        }
        .groupTuple()
        .map { subjectSessionRunSuffix, entityFiles ->
            def (subject, session, run, suffix) = subjectSessionRunSuffix
            
            // Create file lists grouped by entity values
            def fileMap = [:]
            def allFilePaths = []
            
            entityFiles.each { entityKey, entityValue, extension, filePath ->
                if (!fileMap.containsKey(entityValue)) {
                    fileMap[entityValue] = [:]
                }
                fileMap[entityValue][extension] = filePath
                allFilePaths << filePath
            }
            
            // Create separate lists for nii and json files
            def niiFiles = []
            def jsonFiles = []
            fileMap.each { entityValue, extMap ->
                def niiFile = extMap.containsKey('nii.gz') ? extMap['nii.gz'] : extMap['nii']
                def jsonFile = extMap['json']
                
                if (niiFile && jsonFile) {
                    niiFiles << niiFile
                    jsonFiles << jsonFile
                }
            }
            def validPairs = ['nii': niiFiles, 'json': jsonFiles]
            
            if (niiFiles.size() > 0) {
                def groupingKey = [subject, session, run].findAll { it != null && it != "NA" }
                def suffixMap = [:]
                suffixMap[suffix] = validPairs
                tuple(groupingKey, [suffixMap, allFilePaths])
            } else {
                log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: No valid file pairs found"
                null
            }
        }
        .filter { it != null }

    emit:
    grouped_files
}