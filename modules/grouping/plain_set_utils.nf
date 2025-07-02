def validatePlainSetFiles(fileMap, subject, session, run, suffix, suffixConfig) {
    // Default required extensions - now empty to allow more flexibility
    def defaultRequiredExtensions = []
    def defaultNiiExtensions = ['nii.gz', 'nii'] // Prefer nii.gz over nii
    
    // Get configured extensions (handle null case)
    def plainSetConfig = suffixConfig.plain_set ?: [:]
    def requiredExtensions = plainSetConfig.containsKey('required_extensions') ? 
        plainSetConfig.required_extensions : defaultRequiredExtensions
    def additionalExtensions = plainSetConfig.containsKey('additional_extensions') ? 
        plainSetConfig.additional_extensions : []
    
    // Check if we have at least one valid file type
    def hasNii = fileMap.containsKey('nii.gz') || fileMap.containsKey('nii')
    def hasJson = fileMap.containsKey('json')
    def hasAdditional = additionalExtensions.any { ext -> fileMap.containsKey(ext) }
    
    // At least one file type must be present
    if (!hasNii && !hasJson && !hasAdditional) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: No valid files found. Available: ${fileMap.keySet()}, Expected: nii/nii.gz, json, or ${additionalExtensions}"
        return false
    }
    
    // Check for explicitly required extensions
    def missingRequired = requiredExtensions.findAll { ext -> !fileMap.containsKey(ext) }
    if (missingRequired) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Missing required extensions: ${missingRequired}. Available: ${fileMap.keySet()}, Required: ${requiredExtensions}"
        return false
    }
    
    // Log what we found for debugging
    def foundFiles = []
    if (hasNii) foundFiles.add('nii')
    if (hasJson) foundFiles.add('json')
    if (hasAdditional) foundFiles.addAll(additionalExtensions.findAll { ext -> fileMap.containsKey(ext) })
    log.info "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Found valid files: ${foundFiles}"
    
    return true
}

def getExpectedExtensions(suffixConfig) {
    def plainSetConfig = suffixConfig.plain_set ?: [:]
    def defaultRequired = ['nii.gz', 'nii', 'json']
    def additional = plainSetConfig.containsKey('additional_extensions') ? 
        plainSetConfig.additional_extensions : []
    
    return defaultRequired + additional
}