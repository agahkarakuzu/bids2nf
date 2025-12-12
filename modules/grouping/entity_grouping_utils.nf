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
    
    def matchingEntry = suffixConfig.named_set.find { entry ->
        def groupingName = entry.key
        def groupingConfig = entry.value
        
        def matches = groupingConfig.every { entity, value ->
            def rowValue = row[entity]
            def isMatch = entity == 'description' || entityValuesMatch(rowValue, value)
            return isMatch
        }
        
        return matches
    }
    
    return matchingEntry ? matchingEntry.key : null
}

def createFileMap(extFiles) {
    def fileMap = [:]
    extFiles.each { extension, filePath ->
        fileMap[extension] = filePath
    }
    return fileMap
}

def createFileMapWithDataType(extFiles) {
    // Create both a fileMap and a dataTypeMap
    // extFiles format: [[extension, filePath, dataType], ...]
    // When multiple files have the same extension but different dataTypes,
    // store them as lists
    def fileMap = [:]
    def dataTypeMap = [:]

    extFiles.each { item ->
        if (item.size() >= 3) {
            def extension = item[0]
            def filePath = item[1]
            def dataType = item[2]

            // Check if we already have a file with this extension
            if (fileMap.containsKey(extension)) {
                // Multiple files with same extension - convert to list if needed
                if (!(fileMap[extension] instanceof List)) {
                    fileMap[extension] = [fileMap[extension]]
                    dataTypeMap[extension] = [dataTypeMap[extension]]
                }
                fileMap[extension] << filePath
                dataTypeMap[extension] << dataType
            } else {
                fileMap[extension] = filePath
                dataTypeMap[extension] = dataType
            }
        } else if (item.size() == 2) {
            // Fallback for old format without dataType
            def extension = item[0]
            def filePath = item[1]
            fileMap[extension] = filePath
        }
    }

    return [fileMap, dataTypeMap]
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
    log.debug "Subject ${subject}, Session ${session}, Run ${run}, Suffix ${suffix}, grouping ${groupName}: Found valid files: ${foundFiles}"
    
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

def buildChannelData(fileMap, suffixConfig, dataTypeMap = [:]) {
    // Build standardized channel data with normalized keys
    // If group_by_modality is enabled, files are nested by their data_type (modality folder)
    def channelData = [:]

    // Check if group_by_modality is enabled
    def groupByModality = false
    if (suffixConfig.containsKey('group_by_modality')) {
        groupByModality = suffixConfig.group_by_modality
    } else if (suffixConfig.containsKey('plain_set') && suffixConfig.plain_set.containsKey('group_by_modality')) {
        groupByModality = suffixConfig.plain_set.group_by_modality
    } else if (suffixConfig.containsKey('named_set') && suffixConfig.named_set.containsKey('group_by_modality')) {
        groupByModality = suffixConfig.named_set.group_by_modality
    }

    if (groupByModality && dataTypeMap) {
        // Group files by modality
        def modalityGroups = [:]

        // Handle NIfTI files
        ['nii.gz', 'nii'].each { ext ->
            if (fileMap.containsKey(ext)) {
                if (!modalityGroups.containsKey('nii')) {
                    modalityGroups['nii'] = [:]
                }

                // Check if we have multiple files (list) or single file
                if (fileMap[ext] instanceof List) {
                    // Multiple files with different modalities
                    fileMap[ext].eachWithIndex { file, idx ->
                        def modality = (dataTypeMap[ext] instanceof List && idx < dataTypeMap[ext].size()) ?
                                      dataTypeMap[ext][idx] : 'unknown'
                        modalityGroups['nii'][modality] = file
                    }
                } else {
                    // Single file
                    def modality = dataTypeMap[ext] ?: 'unknown'
                    modalityGroups['nii'][modality] = fileMap[ext]
                }
            }
        }

        // Handle JSON files
        if (fileMap.containsKey('json')) {
            if (!modalityGroups.containsKey('json')) {
                modalityGroups['json'] = [:]
            }

            // Check if we have multiple files (list) or single file
            if (fileMap['json'] instanceof List) {
                // Multiple JSON files with different modalities
                fileMap['json'].eachWithIndex { file, idx ->
                    def modality = (dataTypeMap['json'] instanceof List && idx < dataTypeMap['json'].size()) ?
                                  dataTypeMap['json'][idx] : 'unknown'
                    modalityGroups['json'][modality] = file
                }
            } else {
                // Single JSON file
                def modality = dataTypeMap['json'] ?: 'unknown'
                modalityGroups['json'][modality] = fileMap['json']
            }
        }

        // Handle additional extensions
        def additionalFiles = extractAdditionalFiles(fileMap, suffixConfig)
        additionalFiles.each { ext, file ->
            if (!modalityGroups.containsKey(ext)) {
                modalityGroups[ext] = [:]
            }

            // Additional files might also be lists
            if (file instanceof List && dataTypeMap.containsKey(ext) && dataTypeMap[ext] instanceof List) {
                file.eachWithIndex { f, idx ->
                    def modality = (idx < dataTypeMap[ext].size()) ? dataTypeMap[ext][idx] : 'unknown'
                    modalityGroups[ext][modality] = f
                }
            } else {
                def modality = dataTypeMap[ext] ?: 'unknown'
                modalityGroups[ext][modality] = file
            }
        }

        channelData = modalityGroups
    } else {
        // Default behavior: flat structure
        // Handle NIfTI files with normalized key
        def niiFile = fileMap.containsKey('nii.gz') ? fileMap['nii.gz'] : fileMap['nii']
        if (niiFile) {
            // If multiple files, take the last one (backward compatible behavior)
            channelData['nii'] = (niiFile instanceof List) ? niiFile[-1] : niiFile
        }

        // Handle JSON files
        if (fileMap.containsKey('json')) {
            def jsonFile = fileMap['json']
            // If multiple files, take the last one (backward compatible behavior)
            channelData['json'] = (jsonFile instanceof List) ? jsonFile[-1] : jsonFile
        }

        // Handle additional extensions
        def additionalFiles = extractAdditionalFiles(fileMap, suffixConfig)
        additionalFiles.each { ext, file ->
            // If multiple files, take the last one (backward compatible behavior)
            channelData[ext] = (file instanceof List) ? file[-1] : file
        }
    }

    return channelData
}


def buildSequentialChannelData(niiFiles, jsonFiles, suffixConfig, niiDataTypes = [], jsonDataTypes = []) {
    // Build standardized channel data for sequential files (arrays)
    // If group_by_modality is enabled, files are nested by their data_type (modality folder)
    def channelData = [:]

    // Check if group_by_modality is enabled
    def groupByModality = false
    if (suffixConfig.containsKey('group_by_modality')) {
        groupByModality = suffixConfig.group_by_modality
    } else if (suffixConfig.containsKey('sequential_set') && suffixConfig.sequential_set.containsKey('group_by_modality')) {
        groupByModality = suffixConfig.sequential_set.group_by_modality
    } else if (suffixConfig.containsKey('mixed_set') && suffixConfig.mixed_set.containsKey('group_by_modality')) {
        groupByModality = suffixConfig.mixed_set.group_by_modality
    }

    if (groupByModality && (niiDataTypes || jsonDataTypes)) {
        // Group files by modality
        def modalityGroups = [:]

        // Handle NIfTI files
        if (niiFiles && niiFiles.size() > 0) {
            def niiByModality = [:]
            niiFiles.eachWithIndex { file, idx ->
                def modality = (idx < niiDataTypes.size()) ? niiDataTypes[idx] : 'unknown'
                if (!niiByModality.containsKey(modality)) {
                    niiByModality[modality] = []
                }
                niiByModality[modality] << file
            }
            modalityGroups['nii'] = niiByModality
        }

        // Handle JSON files
        if (jsonFiles && jsonFiles.size() > 0) {
            def jsonByModality = [:]
            jsonFiles.eachWithIndex { file, idx ->
                def modality = (idx < jsonDataTypes.size()) ? jsonDataTypes[idx] : 'unknown'
                if (!jsonByModality.containsKey(modality)) {
                    jsonByModality[modality] = []
                }
                jsonByModality[modality] << file
            }
            modalityGroups['json'] = jsonByModality
        }

        channelData = modalityGroups
    } else {
        // Default behavior: flat structure
        // Always use 'nii' key for consistency
        if (niiFiles && niiFiles.size() > 0) {
            channelData['nii'] = niiFiles
        }

        // Handle JSON files
        if (jsonFiles && jsonFiles.size() > 0) {
            channelData['json'] = jsonFiles
        }
    }

    // Note: additional_extensions for sequential sets would need special handling
    // This could be extended in the future if needed

    return channelData
}

