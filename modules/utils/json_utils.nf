def serializeMapToJson(data) {
    def jsonBuilder = new groovy.json.JsonBuilder(data)
    return jsonBuilder.toPrettyString()
}

def readJsonFromFile(file) {
    def jsonSlurper = new groovy.json.JsonSlurper()
    return jsonSlurper.parse(file)
}

def assertJsonDirectories(expectedDir, newDir) {
def expectedFiles = []
def newFiles = []
new File(expectedDir).eachFileRecurse { file ->
if (file.name.endsWith('.json')) {
expectedFiles << file.path.replace(expectedDir + '/', '')
}
}
new File(newDir).eachFileRecurse { file ->
if (file.name.endsWith('.json')) {
newFiles << file.path.replace(newDir + '/', '')
}
}
expectedFiles.sort()
newFiles.sort()
if (expectedFiles != newFiles) {
throw new Exception("JSON file list mismatch: Expected ${expectedFiles}, New ${newFiles}")
}
expectedFiles.each { relPath ->
def expectedFile = new File(expectedDir, relPath)
def newFile = new File(newDir, relPath)
def expectedJson = readJsonFromFile(expectedFile)
def newJson = readJsonFromFile(newFile)
if (expectedJson != newJson) {
throw new Exception("JSON content mismatch in ${relPath}: Expected ${expectedJson}, New ${newJson}")
}
}
return true
}