fs = require('fs')

class FileLogger
    constructor: (@file) ->
        fs.appendFile @file, "###################\n", () ->
    
    log: (msg) ->
        fs.appendFile @file, msg + "\n", () ->

module.exports = FileLogger