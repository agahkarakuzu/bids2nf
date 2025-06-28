def findMatchingGrouping(row, suffixConfig) {
    if (!suffixConfig.containsKey('entity_based_grouping')) {
        return null
    }
    
    for (entry in suffixConfig.entity_based_grouping) {
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