def findMatchingGrouping(row, suffixConfig) {
    if (!suffixConfig.containsKey('named_set')) {
        return null
    }
    
    for (entry in suffixConfig.named_set) {
        def groupingName = entry.key
        def groupingConfig = entry.value
        
        def matches = groupingConfig.every { entity, value ->
            entity == 'description' || row[entity] == value
        }
        
        if (matches) {
            return groupingName
        }
    }
    return null
}

def createFileMap(extFiles) {
    def fileMap = [:]
    extFiles.each { extension, filePath ->
        fileMap[extension] = filePath
    }
    return fileMap
}

def validateRequiredFiles(fileMap, subject, session, run, suffix, groupName) {
    def hasNii = fileMap.containsKey('nii') || fileMap.containsKey('nii.gz')
    def hasJson = fileMap.containsKey('json')
    
    if (!hasNii || !hasJson) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: Missing required extensions. Available: ${fileMap.keySet()}, Required: nii/nii.gz and json"
        return false
    }
    return true
}

def validateRequiredFilesWithConfig(fileMap, subject, session, run, suffix, groupName, suffixConfig) {
    // Check NIfTI files (required)
    def hasNii = fileMap.containsKey('nii') || fileMap.containsKey('nii.gz')
    if (!hasNii) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: Missing NIfTI file. Available: ${fileMap.keySet()}, Required: nii/nii.gz"
        return false
    }
    
    // Check JSON file (required by default)
    def hasJson = fileMap.containsKey('json')
    if (!hasJson) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: Missing JSON file. Available: ${fileMap.keySet()}, Required: json"
        return false
    }
    
    // Check additional extensions if specified (optional by default)
    if (suffixConfig.containsKey('additional_extensions')) {
        def additionalExtensions = suffixConfig.additional_extensions
        def missingAdditional = additionalExtensions.findAll { ext -> !fileMap.containsKey(ext) }
        if (missingAdditional) {
            log.info "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: Optional additional extensions not found: ${missingAdditional}. Available: ${fileMap.keySet()}"
        }
    }
    
    return true
}

def createGroupingKey(subject, session, run) {
    def key = [subject]
    if (session && session != "NA") {
        key << session
    }
    if (run && run != "NA") {
        key << run
    }
    return key
}