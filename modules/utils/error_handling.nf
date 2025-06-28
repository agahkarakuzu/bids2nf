def handleError(String context, Exception e) {
    log.error "[${context}] Error occurred: ${e.message}"
    if (log.isDebugEnabled()) {
        log.debug "[${context}] Stack trace:", e
    }
    exit 1
}

def handleError(String context, String message) {
    log.error "[${context}] ${message}"
    exit 1
}

def handleWarning(String context, String message) {
    log.warn "[${context}] ${message}"
}

def logProgress(String context, String message) {
    log.info "[${context}] ${message}"
}

def logDebug(String context, String message) {
    if (log.isDebugEnabled()) {
        log.debug "[${context}] ${message}"
    }
}

def validateAndThrow(boolean condition, String context, String errorMessage) {
    if (!condition) {
        handleError(context, errorMessage)
    }
}

def tryWithContext(String context, Closure operation) {
    try {
        return operation.call()
    } catch (Exception e) {
        handleError(context, e)
    }
}

def safeExecute(String context, Closure operation, def defaultValue = null) {
    try {
        return operation.call()
    } catch (Exception e) {
        handleWarning(context, "Operation failed: ${e.message}")
        return defaultValue
    }
}