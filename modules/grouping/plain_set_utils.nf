def validatePlainSetFiles(fileMap, subject, session, run, suffix, suffixConfig) {
    // Default required extensions for BIDS data
    def defaultRequiredExtensions = ['json']
    def defaultNiiExtensions = ['nii.gz', 'nii'] // Prefer nii.gz over nii
    
    // Get configured extensions
    def plainSetConfig = suffixConfig.plain_set
    def requiredExtensions = plainSetConfig.containsKey('required_extensions') ? 
        plainSetConfig.required_extensions : defaultRequiredExtensions
    def additionalExtensions = plainSetConfig.containsKey('additional_extensions') ? 
        plainSetConfig.additional_extensions : []
    
    // Check for NIfTI files (nii.gz preferred over nii)
    def hasNii = fileMap.containsKey('nii.gz') || fileMap.containsKey('nii')
    if (!hasNii) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Missing NIfTI file. Available: ${fileMap.keySet()}, Required: nii/nii.gz"
        return false
    }
    
    // Check for required extensions
    def missingRequired = requiredExtensions.findAll { ext -> !fileMap.containsKey(ext) }
    if (missingRequired) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Missing required extensions: ${missingRequired}. Available: ${fileMap.keySet()}, Required: ${requiredExtensions}"
        return false
    }
    
    // Additional extensions are optional, so we just log if they're missing
    def missingAdditional = additionalExtensions.findAll { ext -> !fileMap.containsKey(ext) }
    if (missingAdditional) {
        log.info "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Optional additional extensions not found: ${missingAdditional}. Available: ${fileMap.keySet()}"
    }
    
    return true
}

def getExpectedExtensions(suffixConfig) {
    def plainSetConfig = suffixConfig.plain_set
    def defaultRequired = ['nii.gz', 'nii', 'json']
    def additional = plainSetConfig.containsKey('additional_extensions') ? 
        plainSetConfig.additional_extensions : []
    
    return defaultRequired + additional
}