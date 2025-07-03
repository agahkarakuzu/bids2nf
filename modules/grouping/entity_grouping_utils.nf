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
    
    // At least one file type must be present
    if (!hasNii && !hasJson) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: No valid files found. Available: ${fileMap.keySet()}, Expected: nii/nii.gz or json"
        return false
    }
    return true
}

def validateRequiredFilesWithConfig(fileMap, subject, session, run, suffix, groupName, suffixConfig) {
    // Check for available file types
    def hasNii = fileMap.containsKey('nii') || fileMap.containsKey('nii.gz')
    def hasJson = fileMap.containsKey('json')
    
    // Check for additional extensions
    def hasAdditional = false
    def additionalExtensions = []
    if (suffixConfig.containsKey('additional_extensions')) {
        additionalExtensions = suffixConfig.additional_extensions
        hasAdditional = additionalExtensions.any { ext -> fileMap.containsKey(ext) }
    }
    
    // At least one valid file type must be present
    if (!hasNii && !hasJson && !hasAdditional) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: No valid files found. Available: ${fileMap.keySet()}, Expected: nii/nii.gz, json, or ${additionalExtensions}"
        return false
    }
    
    // Log what we found for debugging
    def foundFiles = []
    if (hasNii) foundFiles.add('nii')
    if (hasJson) foundFiles.add('json')
    if (hasAdditional) foundFiles.addAll(additionalExtensions.findAll { ext -> fileMap.containsKey(ext) })
    log.info "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: Found valid files: ${foundFiles}"
    
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

