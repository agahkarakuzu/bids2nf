def validateRequiredFilesEnhanced(fileMap, subject, session, run, suffix, groupName) {
    def context = "FILE_VALIDATION"
    def identifier = "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, Group ${groupName}"
    
    def hasNii = fileMap.containsKey('nii') || fileMap.containsKey('nii.gz')
    def hasJson = fileMap.containsKey('json')
    
    if (!hasNii) {
        log.error "${identifier}: Missing required NII file. Available extensions: ${fileMap.keySet()}"
        return false
    }
    
    if (!hasJson) {
        log.error "${identifier}: Missing required JSON file. Available extensions: ${fileMap.keySet()}"
        return false
    }
    
    // Validate file existence
    def niiFile = fileMap.containsKey('nii.gz') ? fileMap['nii.gz'] : fileMap['nii']
    def jsonFile = fileMap['json']
    
    if (!file(niiFile).exists()) {
        log.error "${identifier}: NII file does not exist: ${niiFile}"
        return false
    }
    
    if (!file(jsonFile).exists()) {
        log.error "${identifier}: JSON file does not exist: ${jsonFile}"
        return false
    }
    
    // Validate file sizes (basic check)
    def niiSize = file(niiFile).size()
    def jsonSize = file(jsonFile).size()
    
    if (niiSize == 0) {
        log.warn "${identifier}: NII file appears to be empty: ${niiFile}"
    }
    
    if (jsonSize == 0) {
        log.warn "${identifier}: JSON file appears to be empty: ${jsonFile}"
    }
    
    log.debug "${identifier}: File validation passed. NII: ${niiFile} (${niiSize} bytes), JSON: ${jsonFile} (${jsonSize} bytes)"
    return true
}

def validateGroupingConfiguration(config, suffix) {
    def context = "CONFIG_VALIDATION"
    
    if (!config.containsKey(suffix)) {
        log.error "${context}: Configuration missing for suffix: ${suffix}"
        return false
    }
    
    def suffixConfig = config[suffix]
    
    if (!suffixConfig.containsKey('named_set')) {
        log.warn "${context}: No named_set configuration for suffix: ${suffix}"
        return true // This is optional
    }
    
    if (!suffixConfig.containsKey('required')) {
        log.error "${context}: Missing 'required' field for suffix: ${suffix}"
        return false
    }
    
    def required = suffixConfig.required
    if (!(required instanceof List) || required.isEmpty()) {
        log.error "${context}: 'required' field must be a non-empty list for suffix: ${suffix}"
        return false
    }
    
    def entityBasedGrouping = suffixConfig.named_set
    def missingGroups = required.findAll { requiredGroup ->
        !entityBasedGrouping.containsKey(requiredGroup)
    }
    
    if (missingGroups.size() > 0) {
        log.error "${context}: Required groupings ${missingGroups} not found in named_set for suffix: ${suffix}"
        return false
    }
    
    log.debug "${context}: Configuration validation passed for suffix: ${suffix}"
    return true
}

def validateEntityGroupingMatch(row, groupingConfig, groupingName) {
    def context = "ENTITY_MATCHING"
    
    def matchingEntities = groupingConfig.every { entity, expectedValue ->
        def actualValue = row[entity]
        
        // Special handling for description field
        if (entity == 'description') {
            return true
        }
        
        if (actualValue != expectedValue) {
            log.debug "${context}: Entity mismatch for grouping '${groupingName}': ${entity} = '${actualValue}' (expected: '${expectedValue}')"
            return false
        }
        return true
    }
    
    if (!matchingEntities) {
        return false
    }
    
    log.debug "${context}: Entity matching passed for grouping: ${groupingName}"
    return true
}

def validateCompleteGrouping(allGroupingMaps, config, subject, session, run) {
    def context = "COMPLETE_GROUPING_VALIDATION"
    def identifier = "Subject ${subject}, Session ${session}, Run ${run}"
    
    def allSuffixesValid = allGroupingMaps.every { suffix, groupingMap ->
        def suffixConfig = config[suffix]
        
        if (!suffixConfig.containsKey('required')) {
            log.warn "${context}: No required groupings specified for suffix: ${suffix}"
            return true
        }
        
        def requiredGroupings = suffixConfig.required
        def availableGroupings = groupingMap.keySet()
        
        def missingGroupings = requiredGroupings.findAll { requiredGrouping ->
            !availableGroupings.contains(requiredGrouping)
        }
        
        if (missingGroupings.size() > 0) {
            log.error "${context}: ${identifier}, Suffix ${suffix}: Missing required groupings ${missingGroupings}. Available: ${availableGroupings}, Required: ${requiredGroupings}"
            return false
        }
        return true
    }
    
    if (!allSuffixesValid) {
        return false
    }
    
    log.info "${context}: Complete grouping validation passed for ${identifier}"
    return true
}