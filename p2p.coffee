Peer = require('./peer')
constants = require('./constants')
async = require('async')

args = process.argv[2...]


peer = new Peer parseInt(args[1]) or 8080, "P" + args[0], parseInt(args[2]) or 5

# input
process.stdout.write "> "
process.stdin.resume()
process.stdin.setEncoding "utf8"

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
            else
                console.log "unknown command: #{ command }"
                done()
                
    done = () -> process.stdout.write "> " 
    async.eachSeries data, processData, done 