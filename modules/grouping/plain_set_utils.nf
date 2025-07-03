def handlePartsLogic(fileMap, suffixConfig) {
    // Check if this set has parts configuration
    def partsConfig = null
    if (suffixConfig.containsKey('plain_set') && suffixConfig.plain_set.containsKey('parts')) {
        partsConfig = suffixConfig.plain_set.parts
    } else if (suffixConfig.containsKey('named_set') && suffixConfig.named_set.containsKey('parts')) {
        partsConfig = suffixConfig.named_set.parts
    } else if (suffixConfig.containsKey('sequential_set') && suffixConfig.sequential_set.containsKey('parts')) {
        partsConfig = suffixConfig.sequential_set.parts
    } else if (suffixConfig.containsKey('mixed_set') && suffixConfig.mixed_set.containsKey('parts')) {
        partsConfig = suffixConfig.mixed_set.parts
    }
    
    if (!partsConfig) {
        return fileMap  // No parts logic needed, return original fileMap
    }
    
    // Group files by base name (without part entity but keeping other entities)
    def baseGroups = [:]
    fileMap.each { ext, filePath ->
        def fileName = new File(filePath).name
        def baseName = fileName.replaceAll(/_part-[^_]+/, '')  // Remove part entity
        
        if (!baseGroups.containsKey(baseName)) {
            baseGroups[baseName] = [:]
        }
        if (!baseGroups[baseName].containsKey(ext)) {
            baseGroups[baseName][ext] = []
        }
        baseGroups[baseName][ext] << filePath
    }
    
    // Create new file map with parts logic
    def newFileMap = [:]
    
    baseGroups.each { baseName, extGroups ->
        // Find JSON files
        def jsonFiles = extGroups.get('json', [])
        
        jsonFiles.each { jsonPath ->
            // Extract the base pattern from JSON filename (without extension)
            def jsonFileName = new File(jsonPath).name
            def jsonBaseName = jsonFileName.replaceAll(/\.json$/, '')
            
            // Look for NII files with the configured parts that match this JSON pattern
            def niiFiles = [:]
            partsConfig.each { partValue ->
                // Look for matching NII files in all extensions
                ['nii', 'nii.gz'].each { niiExt ->
                    def niiCandidates = extGroups.get(niiExt, [])
                    def matchingNii = niiCandidates.find { niiPath ->
                        def niiFileName = new File(niiPath).name
                        def niiBaseName = niiFileName.replaceAll(/\.(nii|nii\.gz)$/, '')
                        // Check if this NII file has the part we're looking for and matches the JSON base
                        return niiBaseName.contains("_part-${partValue}") && 
                               niiBaseName.replaceAll(/_part-[^_]+/, '') == jsonBaseName
                    }
                    if (matchingNii) {
                        niiFiles[partValue] = matchingNii
                    }
                }
            }
            
            // If we have all required parts, create the grouped entry
            if (niiFiles.size() == partsConfig.size()) {
                def groupKey = jsonBaseName
                // Create array of NII files in the order specified in partsConfig
                def niiArray = partsConfig.collect { partValue -> niiFiles[partValue] }
                newFileMap[groupKey] = [json: jsonPath, nii: niiArray]
            }
        }
    }
    
    return newFileMap.isEmpty() ? fileMap : newFileMap
}

def validatePlainSetFiles(fileMap, subject, session, run, suffix, suffixConfig) {
    // Apply parts logic if configured
    def processedFileMap = handlePartsLogic(fileMap, suffixConfig)
    
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
    // For parts logic, we need to check the values in the map which might be nested structures
    def hasNii = false
    def hasJson = false
    
    processedFileMap.each { key, value ->
        if (value instanceof Map) {
            // Parts logic creates nested maps
            if (value.containsKey('json')) hasJson = true
            if (value.containsKey('nii') && value.nii instanceof List) hasNii = true  // Parts logic creates nii array
            if (value.keySet().any { k -> k != 'json' && k != 'nii' }) hasNii = true  // Other nii keys
        } else {
            // Regular file structure
            if (key == 'json') hasJson = true
            if (key == 'nii.gz' || key == 'nii') hasNii = true
        }
    }
    
    def hasAdditional = additionalExtensions.any { ext -> processedFileMap.containsKey(ext) }
    
    // At least one file type must be present
    if (!hasNii && !hasJson && !hasAdditional) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: No valid files found. Available: ${processedFileMap.keySet()}, Expected: nii/nii.gz, json, or ${additionalExtensions}"
        return false
    }
    
    // Check for explicitly required extensions
    def missingRequired = requiredExtensions.findAll { ext -> !processedFileMap.containsKey(ext) }
    if (missingRequired) {
        log.warn "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}: Missing required extensions: ${missingRequired}. Available: ${processedFileMap.keySet()}, Required: ${requiredExtensions}"
        return false
    }
    
    // Log what we found for debugging
    def foundFiles = []
    if (hasNii) foundFiles.add('nii')
    if (hasJson) foundFiles.add('json')
    if (hasAdditional) foundFiles.addAll(additionalExtensions.findAll { ext -> processedFileMap.containsKey(ext) })
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