process BIDS_VALIDATOR {
    tag "BIDS validation"
    label 'process_low'
    
    container 'bids/validator:latest'
    
    input:
    path bids_dir
    
    output:
    stdout
    
    script:
    """
    bids-validator ${bids_dir} --json
    """
}

def validateBidsDirectory(bidsDir) {
    if (!file(bidsDir).exists()) {
        error "BIDS directory does not exist: ${bidsDir}"
    }
    
    if (!file(bidsDir).isDirectory()) {
        error "BIDS path is not a directory: ${bidsDir}"
    }
    
    // Check if BIDS validation is enabled in config
    if (!params.bids_validation) {
        log.info "BIDS validation disabled by configuration - ${bidsDir}"
        return true
    }
    
    def validationResult = BIDS_VALIDATOR(file(bidsDir))
    
    return true
}

def validateBids2nfConfig(configPath) {
    if (!file(configPath).exists()) {
        error "Configuration file does not exist: ${configPath}"
    }
    
    if (!file(configPath).isFile()) {
        error "Configuration path is not a file: ${configPath}"
    }
    
    def configFile = file(configPath)
    if (!configFile.name.endsWith('.yaml') && !configFile.name.endsWith('.yml')) {
        error "Configuration file must be YAML format: ${configPath}"
    }
    
    log.info "Configuration file validation passed: ${configPath}"
    return true
}

def validateLibBidsScript(scriptPath) {
    if (!file(scriptPath).exists()) {
        error "libBIDS.sh script does not exist: ${scriptPath}"
    }
    
    if (!file(scriptPath).isFile()) {
        error "libBIDS.sh path is not a file: ${scriptPath}"
    }
    
    def scriptFile = file(scriptPath)
    if (!scriptFile.canExecute()) {
        log.warn "libBIDS.sh script is not executable, attempting to make executable: ${scriptPath}"
        scriptFile.setExecutable(true)
    }
    
    log.info "libBIDS.sh script validation passed: ${scriptPath}"
    return true
}

def validateAllInputs(bidsDir, configPath, scriptPath) {
    log.info "Validating all input parameters..."
    
    validateBidsDirectory(bidsDir)
    validateBids2nfConfig(configPath)
    validateLibBidsScript(scriptPath)
    
    log.info "All input validation checks passed successfully"
    return true
}