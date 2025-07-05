process BIDS_VALIDATOR {
    tag "BIDS validation"
    label 'process_low'
    
    container 'agahkarakuzu/bids-validatorx:latest'
    
    input:
    path bids_dir
    val ignore_codes
    
    output:
    stdout
    
    script:
    def ignore_args = ignore_codes ? ignore_codes.collect { "--config.ignore=${it}" }.join(' ') : ''
    """
    bids-validator ${ignore_args} ${bids_dir}
    """
}

def validateBidsDirectory(bidsDir) {
    if (!file(bidsDir).exists()) {
        error "[bids2nf] ☹︎ BIDS directory does not exist: ${bidsDir}"
    }
    
    if (!file(bidsDir).isDirectory()) {
        error "[bids2nf] ☹︎ BIDS path is not a directory: ${bidsDir}"
    }
    
    // Check if BIDS validation is enabled in config
    if (!params.bids_validation) {
        log.info "[bids2nf] ✌︎ BIDS validation disabled by configuration - ${bidsDir}"
        return true
    }
    
    return true
}

def validateBids2nfConfig(configPath) {
    if (!file(configPath).exists()) {
        error "[bids2nf] ☹︎ Configuration file does not exist: ${configPath}"
    }
    
    if (!file(configPath).isFile()) {
        error "[bids2nf] ☹︎ Configuration path is not a file: ${configPath}"
    }
    
    def configFile = file(configPath)
    if (!configFile.name.endsWith('.yaml') && !configFile.name.endsWith('.yml')) {
        error "[bids2nf] ☹︎ Configuration file must be YAML format: ${configPath}"
    }
    
    log.info "[bids2nf] ✌︎ Configuration file validation passed: ${configPath}"
    return true
}

def validateLibBidsScript(scriptPath) {
    if (!file(scriptPath).exists()) {
        error "[bids2nf] ☹︎ libBIDS.sh script does not exist: ${scriptPath}"
    }
    
    if (!file(scriptPath).isFile()) {
        error "[bids2nf] ☹︎ libBIDS.sh path is not a file: ${scriptPath}"
    }
    
    def scriptFile = file(scriptPath)
    if (!scriptFile.canExecute()) {
        log.warn "[bids2nf] ☹︎ libBIDS.sh script is not executable, attempting to make executable: ${scriptPath}"
        scriptFile.setExecutable(true)
    }
    
    log.info "[bids2nf] ✌︎ libBIDS.sh script validation passed: ${scriptPath}"
    return true
}

def preFlightChecks(bidsDir, configPath, scriptPath) {
    log.info "[bids2nf] ✈︎✈︎✈︎ Pre-flight checks started..."
    
    validateBidsDirectory(bidsDir)
    validateBids2nfConfig(configPath)
    validateLibBidsScript(scriptPath)
    
    log.info "[bids2nf] ✓✓✓ All pre-flight checks passed successfully"
    return true
}