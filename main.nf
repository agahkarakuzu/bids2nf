include { libbids_sh_parse } from './modules/parsers/lib_bids_sh_parser.nf'
include { emit_named_sets } from './subworkflows/emit_named_sets.nf'
include { emit_sequential_sets } from './subworkflows/emit_sequential_sets.nf'
include { emit_mixed_sets } from './subworkflows/emit_mixed_sets.nf'
include { emit_plain_sets } from './subworkflows/emit_plain_sets.nf'
include { BIDS_VALIDATOR } from './modules/parsers/bids_validator.nf'
include {
    analyzeConfiguration;
    getConfigurationSummary;
    getLoopOverEntities
} from './modules/utils/config_analyzer.nf'
include { 
    preFlightChecks;
} from './modules/parsers/bids_validator.nf'
include {
    logProgress;
    tryWithContext
} from './modules/utils/error_handling.nf'

workflow bids2nf {
    take:
    bids_dir

    main:
    
    bids2nf_config = "${params.bids2nf_config}"
    
    preFlightChecks(bids_dir, bids2nf_config, params.libbids_sh)


    if (params.bids_validation) {
        BIDS_VALIDATOR(file(bids_dir), [99, 36])
    } else {
        logProgress("bids2nf", "---------------------------\n" + "[bids2nf] ⚠︎⚠︎⚠︎ BIDS validation disabled by configuration ⚠︎⚠︎⚠︎\n" + "[bids2nf] ---------------------------\n")
    }
    
    def bids_parent_dir = file(bids_dir).parent.toString()
    
    parsed_csv = libbids_sh_parse(bids_dir, params.libbids_sh)
    
    def config = tryWithContext("CONFIG_LOADING") {
        new org.yaml.snakeyaml.Yaml().load(new FileReader(bids2nf_config))
    }
    
    def configAnalysis = tryWithContext("CONFIG_ANALYSIS") {
        analyzeConfiguration(bids2nf_config)
    }
    
    // Get loop over entities from configuration
    def loopOverEntities = tryWithContext("LOOP_OVER_CONFIG") {
        getLoopOverEntities(bids2nf_config)
    }
    
    
    def summary = getConfigurationSummary(bids2nf_config)
    
    logProgress("bids2nf", "┌─ ✓ Configuration analysis complete:")
    logProgress("bids2nf", "├─ ↬ Loop over entities: ${loopOverEntities.join(', ')}")
    logProgress("bids2nf", "├─ ⑆ Named sets: ${summary.namedSets.count} patterns (${summary.namedSets.suffixes.join(', ')})")
    logProgress("bids2nf", "├─ ⑇ Sequential sets: ${summary.sequentialSets.count} patterns (${summary.sequentialSets.suffixes.join(', ')})")
    logProgress("bids2nf", "├─ ⑈ Mixed sets: ${summary.mixedSets.count} patterns (${summary.mixedSets.suffixes.join(', ')})")
    logProgress("bids2nf", "├─ ⑉ Plain sets: ${summary.plainSets.count} patterns (${summary.plainSets.suffixes.join(', ')})")
    logProgress("bids2nf", "├─ = TOTAL patterns: ${summary.totalPatterns}")
    
    // Route to appropriate workflows based on configuration analysis, passing pre-processed data
    if (configAnalysis.hasNamedSets) {
        logProgress("bids2nf", "├─ ⑆ Processing named sets >>>")
        named_results = emit_named_sets(parsed_csv, config, loopOverEntities)
    } else {
        named_results = Channel.empty()
    }
    
    if (configAnalysis.hasSequentialSets) {
        logProgress("bids2nf", "├─ ⑇ Processing sequential sets ...")
        sequential_results = emit_sequential_sets(parsed_csv, config, loopOverEntities)
    } else {
        sequential_results = Channel.empty()
    }
    
    if (configAnalysis.hasMixedSets) {
        logProgress("bids2nf", "├─ ⑈ Processing mixed sets ...")
        mixed_results = emit_mixed_sets(parsed_csv, config, loopOverEntities)
    } else {
        mixed_results = Channel.empty()
    }
    
    if (configAnalysis.hasPlainSets) {
        logProgress("bids2nf", "├─ ⑉ Processing plain sets ...")
        plain_results = emit_plain_sets(parsed_csv, config, loopOverEntities)
    } else {
        plain_results = Channel.empty()
    }
    
    // Combine all results into a unified channel and merge by grouping key
    logProgress("bids2nf", "├─ ⎌ Combining results from all workflow types ...")
    
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
                    enrichedData.data.each { suffix, _suffixData ->
                        crossModalData[nonTaskKeyStr][suffix] = _suffixData
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
                        enrichedData.data.each { suffix, _suffixData ->
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
                        enrichedData.data.each { suffix, _suffixData ->
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
                        def hasNonRequestedData = enrichedData.data.any { suffix, _suffixData ->
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
    
    // Log final statistics and validate results
    final_results
        .count()
        .subscribe { count ->
            if (count == 0) {
                throw new Exception("├─ ⛔️ ERROR\n" + "[bids2nf] └─ No data groups were processed! This could indicate:\n" +
                    "  - No files match the configured patterns in bids2nf.yaml\n" +
                    "  - Incorrect BIDS directory structure\n" +
                    "  - Configuration issues with entity matching\n" +
                    "  - Missing required files for complete groupings")
            }
            logProgress("bids2nf", "├─ ✅ SUCCESS\n" + "[bids2nf] └─ Bids2nf workflow complete: ${count} data groups processed]")
        }

    emit:
    final_results
}