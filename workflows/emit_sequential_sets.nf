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
    // tryWithContext("INPUT_VALIDATION") {
    //     validateAllInputs(bids_dir, bids2nf_config, params.libbids_sh)
    // }
    
    logProgress("emit_sequential_sets", "Input validation completed successfully")
    
    // Parse BIDS directory
    parsed_csv = tryWithContext("BIDS_PARSING") {
        libbids_sh_parse(bids_dir, params.libbids_sh)
    }
    
    // Load and validate configuration
    def config = tryWithContext("CONFIG_LOADING") {
        new Yaml().load(new FileReader(bids2nf_config))
    }
    
    // Validate multi-entity configurations
    config.each { suffix, suffixConfig ->
        if (suffixConfig.containsKey('sequential_set')) {
            def seqConfig = suffixConfig.sequential_set
            if (seqConfig.containsKey('by_entities')) {
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
            def entityValues = []
            def allEntitiesPresent = true
            
            // Debug: Log the row content
            //log.info "Row data: ${row}"
            //log.info "Entity keys to extract: ${entityKeys}"
            
            entityKeys.each { entityKey ->
                def entityValue = row[entityKey]
              //  log.info "Extracting ${entityKey}: ${entityValue}"
                if (entityValue) {
                    entityValues << entityValue
                } else {
                    allEntitiesPresent = false
                }
            }
            
            //log.info "Final entity values: ${entityValues}"
            
            if (allEntitiesPresent) {
                // Create composite key for multiple entities, or single key for single entity
                def compositeEntityKey = entityKeys.join('_')
                def compositeEntityValue = entityValues.join('_')
                tuple([row.subject, row.session, row.run, row.suffix, compositeEntityKey], [entityKeys, entityValues, orderType, row.extension, row.path])
            } else {
                null
            }
        }
        .filter { it != null }

    // Group by subject, session, run, suffix, entity
    grouped_files = input_files
        .map { subjectSessionRunSuffixEntity, entityData ->
            def (subject, session, run, suffix, compositeEntityKey) = subjectSessionRunSuffixEntity
            def (entityKeys, entityValues, orderType, extension, filePath) = entityData
            tuple([subject, session, run, suffix], [entityKeys, entityValues, orderType, extension, filePath])
        }
        .groupTuple()
        .map { subjectSessionRunSuffix, entityFiles ->
            def (subject, session, run, suffix) = subjectSessionRunSuffix
            
            // Create file lists grouped by entity values (handles both single and multiple entities)
            def fileMap = [:]
            def allFilePaths = []
            def entityKeysRef = null
            def orderTypeRef = null
            
            entityFiles.each { entityKeys, entityValues, orderType, extension, filePath ->
                if (!entityKeysRef) entityKeysRef = entityKeys
                if (!orderTypeRef) orderTypeRef = orderType
                
                // Create hierarchical key structure
                def currentMap = fileMap
                for (int i = 0; i < entityValues.size() - 1; i++) {
                    def entityValue = entityValues[i]
                    if (!currentMap.containsKey(entityValue)) {
                        currentMap[entityValue] = [:]
                    }
                    currentMap = currentMap[entityValue]
                }
                
                // At the final level, store extension-to-path mapping
                def finalEntityValue = entityValues[-1]
                if (!currentMap.containsKey(finalEntityValue)) {
                    currentMap[finalEntityValue] = [:]
                }
                currentMap[finalEntityValue][extension] = filePath
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
                        def niiFile = extMap.containsKey('nii.gz') ? extMap['nii.gz'] : extMap['nii']
                        def jsonFile = extMap['json']
                        
                        if (niiFile && jsonFile) {
                            niiGroup << niiFile
                            jsonGroup << jsonFile
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
                            def niiFile = extMap.containsKey('nii.gz') ? extMap['nii.gz'] : extMap['nii']
                            def jsonFile = extMap['json']
                            
                            if (niiFile && jsonFile) {
                                niiFiles << niiFile
                                jsonFiles << jsonFile
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