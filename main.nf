import org.yaml.snakeyaml.Yaml
include { libbids_sh_parse } from './modules/parsers/lib_bids_sh_parser.nf'
include { emit_named_sets } from './subworkflows/emit_named_sets.nf'
include { emit_sequential_sets } from './subworkflows/emit_sequential_sets.nf'
include { emit_mixed_sets } from './subworkflows/emit_mixed_sets.nf'
include {
    analyzeConfiguration;
    hasNamedSets;
    hasSequentialSets;
    hasMixedSets;
    getConfigurationSummary
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
    
    def summary = getConfigurationSummary(bids2nf_config)
    
    logProgress("bids2nf", "Configuration analysis complete:")
    logProgress("bids2nf", "  - Named sets: ${summary.namedSets.count} patterns (${summary.namedSets.suffixes.join(', ')})")
    logProgress("bids2nf", "  - Sequential sets: ${summary.sequentialSets.count} patterns (${summary.sequentialSets.suffixes.join(', ')})")
    logProgress("bids2nf", "  - Mixed sets: ${summary.mixedSets.count} patterns (${summary.mixedSets.suffixes.join(', ')})")
    logProgress("bids2nf", "  - Total patterns: ${summary.totalPatterns}")
    
    // Route to appropriate workflows based on configuration analysis, passing pre-processed data
    named_results = configAnalysis.hasNamedSets ? 
        tryWithContext("NAMED_SETS") {
            logProgress("bids2nf", "Processing named sets...")
            emit_named_sets(parsed_csv, config)
        } : 
        Channel.empty()
    
    sequential_results = configAnalysis.hasSequentialSets ? 
        tryWithContext("SEQUENTIAL_SETS") {
            logProgress("bids2nf", "Processing sequential sets...")
            emit_sequential_sets(parsed_csv, config)
        } : 
        Channel.empty()
    
    mixed_results = configAnalysis.hasMixedSets ? 
        tryWithContext("MIXED_SETS") {
            logProgress("bids2nf", "Processing mixed sets...")
            emit_mixed_sets(parsed_csv, config)
        } : 
        Channel.empty()
    
    // Combine all results into a unified channel and merge by grouping key
    logProgress("bids2nf", "Combining results from all workflow types...")
    
    combined_results = named_results
        .mix(sequential_results)
        .mix(mixed_results)
    
    // Group by subject/session/run and merge all data types
    unified_results = combined_results
        .groupTuple()
        .map { groupingKey, dataList ->
            def (subject, session, run) = groupingKey
            
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
                subject: subject,
                session: session ?: "NA", 
                run: run ?: "NA",
                bidsParentDir: "${bids_parent_dir}"
            ]
            
            tuple(groupingKey, enrichedData)
        }
    
    // Log final statistics
    unified_results
        .count()
        .subscribe { count ->
            logProgress("bids2nf", "Unified workflow complete: ${count} data groups processed")
        }

    emit:
    unified_results
}