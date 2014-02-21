fs = require 'fs'
async = require 'async'
constants = require './constants'

class CLIController
    constructor: (peer) ->
        # input
        process.stdout.write "> "
        process.stdin.resume()
        process.stdin.setEncoding "utf8"
        
        
        search = (queries, done) ->
            peer.search queries
            done()
        
        process.stdin.on "data", (data) ->
            data = data.trim().split '\n'
            processData = (data, done) ->
                data = data.trim();
                if (data is "")
                    done()
                [command, args...] = data.split " "
                command = command.trim()
                switch command
                    when constants.HELLO then peer.hello args, done
                    when constants.PLIST then peer.printKnownPeers done
                    when constants.DREAM then peer.dream args, done
                    when constants.EXIT then process.exit 0
                    when constants.NLIST then peer.printNeighbourhood args, done
                    when constants.JOIN then peer.joinNeighbourhood done
                    when constants.SEARCH then search args, done
                    else
                        console.log "unknown command: #{ command }"
                        done()
                        
            done = () -> process.stdout.write "> " 
            async.eachSeries data, processData, done
            
            
class FileController
    constructor: (file, peer) ->
        fs.readFile file, {encoding: "utf8"}, (err, data) ->
            if err?
                console.log err
            else
                setTimeout () ->
                    data = data.trim().split '\n'
                    processData = (data, done) ->
                        data = data.trim();
                        if (data is "")
                            done()
                        [command, args...] = data.split " "
                        command = command.trim()
                        switch command
                            when constants.HELLO then peer.hello args, done
                            when constants.PLIST then peer.printKnownPeers done
                            when constants.DREAM then peer.dream args, done
                            when constants.EXIT then process.exit 0
                            when constants.NLIST then peer.printNeighbourhood args, done
                            when constants.JOIN then peer.joinNeighbourhood done
                            else
                                done()
                                
                    done = () ->  
                    async.eachSeries data, processData, done
                , 1000
                
class SimpleController
    constructor: (peer) ->
        setTimeout () ->
            peer.hello ["localhost:8000"], () ->
        , 1000
                
module.exports =
    CLI: CLIController
    File: FileController
    Simple: SimpleController