import org.yaml.snakeyaml.Yaml

/**
 * Analyze configuration file to determine which workflow types are present
 */
def analyzeConfiguration(bids2nf_config) {
    def config = new Yaml().load(new FileReader(bids2nf_config))
    
    def analysis = [
        hasNamedSets: false,
        hasSequentialSets: false,
        hasMixedSets: false,
        hasPlainSets: false,
        namedSetSuffixes: [],
        sequentialSetSuffixes: [],
        mixedSetSuffixes: [],
        plainSetSuffixes: []
    ]
    
    config.each { suffix, suffixConfig ->
        // Skip global configuration keys that are not set definitions
        if (suffix == 'loop_over') {
            return
        }
        
        if (suffixConfig.containsKey('named_set')) {
            analysis.hasNamedSets = true
            analysis.namedSetSuffixes << suffix
        }
        
        if (suffixConfig.containsKey('sequential_set')) {
            analysis.hasSequentialSets = true
            analysis.sequentialSetSuffixes << suffix
        }
        
        if (suffixConfig.containsKey('mixed_set')) {
            analysis.hasMixedSets = true
            analysis.mixedSetSuffixes << suffix
        }
        
        if (suffixConfig.containsKey('plain_set')) {
            analysis.hasPlainSets = true
            analysis.plainSetSuffixes << suffix
        }
    }
    
    return analysis
}

/**
 * Check if configuration has any named sets
 */
def hasNamedSets(bids2nf_config) {
    return analyzeConfiguration(bids2nf_config).hasNamedSets
}

/**
 * Check if configuration has any sequential sets
 */
def hasSequentialSets(bids2nf_config) {
    return analyzeConfiguration(bids2nf_config).hasSequentialSets
}

/**
 * Check if configuration has any mixed sets
 */
def hasMixedSets(bids2nf_config) {
    return analyzeConfiguration(bids2nf_config).hasMixedSets
}

/**
 * Check if configuration has any plain sets
 */
def hasPlainSets(bids2nf_config) {
    return analyzeConfiguration(bids2nf_config).hasPlainSets
}

/**
 * Get loop_over entities from configuration
 */
def getLoopOverEntities(bids2nf_config) {
    def config = new Yaml().load(new FileReader(bids2nf_config))
    return config.containsKey('loop_over') ? config.loop_over : ['subject', 'session', 'run']
}


/**
 * Get detailed configuration analysis with counts and types
 */
def getConfigurationSummary(bids2nf_config) {
    def analysis = analyzeConfiguration(bids2nf_config)
    
    def summary = [
        totalPatterns: analysis.namedSetSuffixes.size() + analysis.sequentialSetSuffixes.size() + analysis.mixedSetSuffixes.size() + analysis.plainSetSuffixes.size(),
        namedSets: [
            count: analysis.namedSetSuffixes.size(),
            suffixes: analysis.namedSetSuffixes
        ],
        sequentialSets: [
            count: analysis.sequentialSetSuffixes.size(),
            suffixes: analysis.sequentialSetSuffixes
        ],
        mixedSets: [
            count: analysis.mixedSetSuffixes.size(),
            suffixes: analysis.mixedSetSuffixes
        ],
        plainSets: [
            count: analysis.plainSetSuffixes.size(),
            suffixes: analysis.plainSetSuffixes
        ]
    ]
    
    return summary
}