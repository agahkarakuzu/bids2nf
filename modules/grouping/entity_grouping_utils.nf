def normalizeEntityValue(value) {
    // Normalize entity values to handle different zero-padding
    // e.g., "flip-02" and "flip-2" should both match
    if (value && value.contains('-')) {
        def parts = value.split('-')
        if (parts.length == 2) {
            def prefix = parts[0]
            def suffix = parts[1]
            // If suffix is numeric, remove leading zeros for comparison
            if (suffix.isNumber()) {
                def numericSuffix = Integer.parseInt(suffix)
                return "${prefix}-${numericSuffix}"
            }
        }
    }
    return value
}

def entityValuesMatch(rowValue, configValue) {
    // Compare entity values with normalization
    if (!rowValue || !configValue) {
        return rowValue == configValue
    }
    return normalizeEntityValue(rowValue) == normalizeEntityValue(configValue)
}

def findMatchingGrouping(row, suffixConfig) {
    if (!suffixConfig.containsKey('named_set')) {
        return null
    }
    
    for (entry in suffixConfig.named_set) {
        def groupingName = entry.key
        def groupingConfig = entry.value
        
        def matches = groupingConfig.every { entity, value ->
            entity == 'description' || entityValuesMatch(row[entity], value)
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

def normalizeNiiExtension(extension) {
    // Normalize NIfTI extensions to use 'nii' consistently
    return (extension == 'nii.gz') ? 'nii' : extension
}

def extractAdditionalFiles(fileMap, suffixConfig) {
    // Extract additional extension files based on configuration
    def additionalFiles = [:]
    
    // Check for additional_extensions at top level (for named sets)
    if (suffixConfig.containsKey('additional_extensions')) {
        suffixConfig.additional_extensions.each { ext ->
            if (fileMap.containsKey(ext)) {
                additionalFiles[ext] = fileMap[ext]
            }
        }
    }
    
    // Check for additional_extensions in plain_set block (for plain sets)
    if (suffixConfig.containsKey('plain_set') && suffixConfig.plain_set.containsKey('additional_extensions')) {
        suffixConfig.plain_set.additional_extensions.each { ext ->
            if (fileMap.containsKey(ext)) {
                additionalFiles[ext] = fileMap[ext]
            }
        }
    }
    
    // Check for additional_extensions in mixed_set block (for mixed sets)
    if (suffixConfig.containsKey('mixed_set') && suffixConfig.mixed_set.containsKey('additional_extensions')) {
        suffixConfig.mixed_set.additional_extensions.each { ext ->
            if (fileMap.containsKey(ext)) {
                additionalFiles[ext] = fileMap[ext]
            }
        }
    }
    
    // Check for additional_extensions in sequential_set block (for sequential sets)
    if (suffixConfig.containsKey('sequential_set') && suffixConfig.sequential_set.containsKey('additional_extensions')) {
        suffixConfig.sequential_set.additional_extensions.each { ext ->
            if (fileMap.containsKey(ext)) {
                additionalFiles[ext] = fileMap[ext]
            }
        }
    }
    
    return additionalFiles
}

def buildChannelData(fileMap, suffixConfig) {
    // Build standardized channel data with normalized keys
    def channelData = [:]
    
    // Handle NIfTI files with normalized key
    def niiFile = fileMap.containsKey('nii.gz') ? fileMap['nii.gz'] : fileMap['nii']
    if (niiFile) {
        channelData['nii'] = niiFile
    }
    
    // Handle JSON files
    if (fileMap.containsKey('json')) {
        channelData['json'] = fileMap['json']
    }
    
    // Handle additional extensions
    def additionalFiles = extractAdditionalFiles(fileMap, suffixConfig)
    additionalFiles.each { ext, file ->
        channelData[ext] = file
    }
    
    return channelData
}


def buildSequentialChannelData(niiFiles, jsonFiles, suffixConfig) {
    // Build standardized channel data for sequential files (arrays)
    def channelData = [:]
    
    // Always use 'nii' key for consistency
    if (niiFiles && niiFiles.size() > 0) {
        channelData['nii'] = niiFiles
    }
    
    // Handle JSON files
    if (jsonFiles && jsonFiles.size() > 0) {
        channelData['json'] = jsonFiles
    }
    
    // Note: additional_extensions for sequential sets would need special handling
    // This could be extended in the future if needed
    
    return channelData
}

