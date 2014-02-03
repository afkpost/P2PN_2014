require('array-sugar')
xmlrpc = require('xmlrpc')
constants = require('./constants')
os = require('os')

debug = false

args = process.argv[2...]

self = {}

# Identifier
self.id = "P" + args[0]

# Parse port
self.port = parseInt(args[1]) or 8080

# Parse number of capacity
self.capacity = parseInt(args[2]) or 5


# Find IP
ifaces = os.networkInterfaces();
for dev of ifaces
    for details in ifaces[dev] when details.family is "IPv4" and not details.internal
        self.host = details.address 

# peers
knownPeers = []

same = (p1, p2) ->
    p1.host is p2.host and p1.port is p2.port

knows = (peer) ->
    (knownPeers.findOne (p) -> same(p, peer))?
    
addPeer = (peer) ->
    return if (same peer, self) or (knows peer)
    knownPeers.push peer
    
removePeer = (peer) ->
    knownPeers.remove peer

#funtions
removeOnError = (peer, err) ->
    (err) ->
        removePeer peer if err.code?

doPong = (details) ->
    console.log "ponging %s:%s", details.host, details.port if debug
    client = xmlrpc.createClient details
    client.methodCall constants.PONG, [self, knownPeers], removeOnError(details)

doPing = (details) ->
    console.log "pinging %s:%s", details.host, details.port if debug
    client = xmlrpc.createClient details
    client.methodCall constants.PING, [self], removeOnError(details)

printKnownPeers = () ->
    console.log "Known peers"
    console.log peer.id for peer in knownPeers
   
# server
server = xmlrpc.createServer self

#rounting
server.on constants.PING, (err, [peer], callback) ->
    callback() # acknowledge
    doPong peer
    addPeer peer

server.on constants.PONG, (err, [sender, peers], callback) ->
    callback() # acknowledge
    addPeer sender
    for peer in peers when (not knows peer) and (not same peer, self)
        doPing peer
        
        
console.log "Listening on %s:%s", self.host, self.port
        
# helpers
hello = (address) ->
    if address
        [host, port] = address.trim().split ":"
        doPing {
            host: host,
            port: port
        }
    else
        doPing peer for peer in knownPeers
        
# input
process.stdout.write "> "
process.stdin.resume()
process.stdin.setEncoding "utf8"

process.stdin.on "data", (data) ->
    [command, address] = data.split " "
    command = command.trim()
    switch command
        when constants.HELLO then hello address
        when constants.PLIST then printKnownPeers()
        else console.log "unknown command: #{ command }"
            
        
    process.stdout.write "> "

