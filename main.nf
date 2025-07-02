import org.yaml.snakeyaml.Yaml
include { libbids_sh_parse } from './modules/parsers/lib_bids_sh_parser.nf'
include { emit_named_sets } from './subworkflows/emit_named_sets.nf'
include { emit_sequential_sets } from './subworkflows/emit_sequential_sets.nf'
include { emit_mixed_sets } from './subworkflows/emit_mixed_sets.nf'
include { emit_plain_sets } from './subworkflows/emit_plain_sets.nf'
include {
    analyzeConfiguration;
    hasNamedSets;
    hasSequentialSets;
    hasMixedSets;
    hasPlainSets;
    getConfigurationSummary;
    getLoopOverEntities
} from './modules/utils/config_analyzer.nf'
include { 
    validateAllInputs;
    validateBidsDirectory;
    validateBids2nfConfig;
    validateLibBidsScript
} from './modules/parsers/bids_validator.nf'
include {
    handleError;
    logProgress;
    tryWithContext
} from './modules/utils/error_handling.nf'

workflow bids2nf {
    take:
    bids_dir

    main:
    
    // Use the built-in configuration
    bids2nf_config = "${params.bids2nf_config}"
    
    // Perform shared validation and parsing once
    logProgress("bids2nf", "Starting unified bids2nf workflow...")
    logProgress("bids2nf", "Performing input validation and BIDS parsing...")
    
    // Validate all inputs before processing (done once)
    tryWithContext("INPUT_VALIDATION") {
        validateAllInputs(bids_dir, bids2nf_config, params.libbids_sh)
    }
    
    logProgress("bids2nf", "Input validation completed successfully")
    
    // Calculate parent directory once
    def bids_parent_dir = file(bids_dir).parent.toString()
    
    // Parse BIDS directory once
    parsed_csv = tryWithContext("BIDS_PARSING") {
        libbids_sh_parse(bids_dir, params.libbids_sh)
    }
    
    // Load and validate configuration once
    def config = tryWithContext("CONFIG_LOADING") {
        new Yaml().load(new FileReader(bids2nf_config))
    }
    
    // Analyze configuration to determine workflow types needed
    logProgress("bids2nf", "Analyzing configuration to determine workflow types...")
    
    def configAnalysis = tryWithContext("CONFIG_ANALYSIS") {
        analyzeConfiguration(bids2nf_config)
    }
    
    // Get loop over entities from configuration
    def loopOverEntities = tryWithContext("LOOP_OVER_CONFIG") {
        getLoopOverEntities(bids2nf_config)
    }
    
    
    def summary = getConfigurationSummary(bids2nf_config)
    
    logProgress("bids2nf", "Configuration analysis complete:")
    logProgress("bids2nf", "  - Loop over entities: ${loopOverEntities.join(', ')}")
    logProgress("bids2nf", "  - Named sets: ${summary.namedSets.count} patterns (${summary.namedSets.suffixes.join(', ')})")
    logProgress("bids2nf", "  - Sequential sets: ${summary.sequentialSets.count} patterns (${summary.sequentialSets.suffixes.join(', ')})")
    logProgress("bids2nf", "  - Mixed sets: ${summary.mixedSets.count} patterns (${summary.mixedSets.suffixes.join(', ')})")
    logProgress("bids2nf", "  - Plain sets: ${summary.plainSets.count} patterns (${summary.plainSets.suffixes.join(', ')})")
    logProgress("bids2nf", "  - Total patterns: ${summary.totalPatterns}")
    
    // Route to appropriate workflows based on configuration analysis, passing pre-processed data
    named_results = configAnalysis.hasNamedSets ? 
        tryWithContext("NAMED_SETS") {
            logProgress("bids2nf", "Processing named sets...")
            emit_named_sets(parsed_csv, config, loopOverEntities)
        } : 
        Channel.empty()
    
    sequential_results = configAnalysis.hasSequentialSets ? 
        tryWithContext("SEQUENTIAL_SETS") {
            logProgress("bids2nf", "Processing sequential sets...")
            emit_sequential_sets(parsed_csv, config, loopOverEntities)
        } : 
        Channel.empty()
    
    mixed_results = configAnalysis.hasMixedSets ? 
        tryWithContext("MIXED_SETS") {
            logProgress("bids2nf", "Processing mixed sets...")
            emit_mixed_sets(parsed_csv, config, loopOverEntities)
        } : 
        Channel.empty()
    
    plain_results = configAnalysis.hasPlainSets ? 
        tryWithContext("PLAIN_SETS") {
            logProgress("bids2nf", "Processing plain sets...")
            emit_plain_sets(parsed_csv, config, loopOverEntities)
        } : 
        Channel.empty()
    
    // Combine all results into a unified channel and merge by grouping key
    logProgress("bids2nf", "Combining results from all workflow types...")
    
    combined_results = named_results
        .mix(sequential_results)
        .mix(mixed_results)
        .mix(plain_results)
    
    // Group by loop_over entities and merge all data types
    unified_results = combined_results
        .groupTuple()
        .map { groupingKey, dataList ->
            // Dynamically unpack grouping key based on loop_over entities
            def entityValues = [:]
            loopOverEntities.eachWithIndex { entity, index ->
                entityValues[entity] = groupingKey[index] ?: "NA"
            }
            
            // Merge all data maps and file paths
            def mergedDataMap = [:]
            def allFilePaths = []
            
            dataList.each { data ->
                def (dataMap, filePaths) = data
                
                // Merge data maps
                dataMap.each { suffix, suffixData ->
                    mergedDataMap[suffix] = suffixData
                }
                
                // Collect all file paths
                allFilePaths.addAll(filePaths)
            }
            
            def enrichedData = [
                data: mergedDataMap,
                filePaths: allFilePaths.unique(),
                bidsParentDir: "${bids_parent_dir}"
            ]
            
            // Add dynamic entity values to enrichedData
            entityValues.each { entity, value ->
                enrichedData[entity] = value
            }
            
            tuple(groupingKey, enrichedData)
        }
    
    // Apply demand-driven cross-modal broadcasting
    final_results = unified_results
        .toList()
        .map { dataList ->
            // Group data by non-task entities for cross-modal broadcasting
            def groupedData = [:]
            def crossModalData = [:]
            
            dataList.each { groupingKey, enrichedData ->
                // Extract entity values
                def entityValues = [:]
                loopOverEntities.eachWithIndex { entity, index ->
                    entityValues[entity] = groupingKey[index] ?: "NA"
                }
                
                // Create grouping key without task entity
                def nonTaskEntities = loopOverEntities.findAll { it != 'task' }
                def nonTaskKey = nonTaskEntities.collect { entity ->
                    entityValues[entity] ?: "NA"
                }
                
                def nonTaskKeyStr = nonTaskKey.join('_')
                
                // Collect available cross-modal data (data with task="NA")
                if (entityValues.task == "NA") {
                    if (!crossModalData.containsKey(nonTaskKeyStr)) {
                        crossModalData[nonTaskKeyStr] = [:]
                    }
                    
                    // Store all suffixes from task="NA" channels as potential cross-modal data
                    enrichedData.data.each { suffix, suffixData ->
                        crossModalData[nonTaskKeyStr][suffix] = suffixData
                    }
                }
                
                // Group all data for later processing
                if (!groupedData.containsKey(nonTaskKeyStr)) {
                    groupedData[nonTaskKeyStr] = []
                }
                groupedData[nonTaskKeyStr] << [groupingKey, enrichedData, entityValues]
            }
            
            // Apply demand-driven broadcasting
            def broadcastedResults = []
            
            groupedData.each { nonTaskKeyStr, groupEntries ->
                def availableCrossModalData = crossModalData[nonTaskKeyStr] ?: [:]
                
                groupEntries.each { groupingKey, enrichedData, entityValues ->
                    def shouldKeepChannel = true
                    def enhancedData = enrichedData.clone()
                    enhancedData.data = enhancedData.data.clone()
                    
                    // For task-specific channels, check if they request cross-modal data
                    if (entityValues.task != "NA") {
                        enrichedData.data.each { suffix, suffixData ->
                            // Check if this suffix has include_cross_modal configuration
                            def suffixConfig = config[suffix]
                            if (suffixConfig) {
                                def setCfg = suffixConfig.plain_set ?: suffixConfig.named_set ?: 
                                           suffixConfig.sequential_set ?: suffixConfig.mixed_set
                                
                                if (setCfg && setCfg.include_cross_modal) {
                                    // Add requested cross-modal data to this channel
                                    setCfg.include_cross_modal.each { requestedSuffix ->
                                        if (availableCrossModalData.containsKey(requestedSuffix)) {
                                            enhancedData.data[requestedSuffix] = availableCrossModalData[requestedSuffix]
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // For task="NA" channels, check if their data was requested by other suffixes
                    if (entityValues.task == "NA") {
                        def dataWasRequested = false
                        
                        // Check if any suffix in this channel was requested by task-specific suffixes
                        enrichedData.data.each { suffix, suffixData ->
                            // Look through all suffix configs to see if any request this suffix
                            config.each { otherSuffix, otherSuffixConfig ->
                                if (otherSuffix != suffix && otherSuffixConfig instanceof Map) {
                                    def otherSetCfg = otherSuffixConfig.plain_set ?: otherSuffixConfig.named_set ?: 
                                                     otherSuffixConfig.sequential_set ?: otherSuffixConfig.mixed_set
                                    
                                    if (otherSetCfg && otherSetCfg.include_cross_modal && 
                                        otherSetCfg.include_cross_modal.contains(suffix)) {
                                        dataWasRequested = true
                                    }
                                }
                            }
                        }
                        
                        // Only keep task="NA" channels if their data wasn't successfully included elsewhere
                        // OR if they contain non-requested data
                        def hasNonRequestedData = enrichedData.data.any { suffix, suffixData ->
                            def wasRequested = false
                            config.each { otherSuffix, otherSuffixConfig ->
                                if (otherSuffix != suffix && otherSuffixConfig instanceof Map) {
                                    def otherSetCfg = otherSuffixConfig.plain_set ?: otherSuffixConfig.named_set ?: 
                                                     otherSuffixConfig.sequential_set ?: otherSuffixConfig.mixed_set
                                    
                                    if (otherSetCfg && otherSetCfg.include_cross_modal && 
                                        otherSetCfg.include_cross_modal.contains(suffix)) {
                                        wasRequested = true
                                    }
                                }
                            }
                            return !wasRequested
                        }
                        
                        shouldKeepChannel = hasNonRequestedData
                    }
                    
                    if (shouldKeepChannel) {
                        broadcastedResults << tuple(groupingKey, enhancedData)
                    }
                }
            }
            
            return broadcastedResults
        }
        .flatMap()
    
    // Log final statistics
    final_results
        .count()
        .subscribe { count ->
            logProgress("bids2nf", "Unified workflow complete: ${count} data groups processed")
        }

    emit:
    final_results
}