require('array-sugar')
xmlrpc = require('xmlrpc')
constants = require('./constants')
os = require('os')

args = process.argv[2...]

self = {}

# Parse port
self.port = parseInt(args[0]) or 8080

# Find IP
ifaces = os.networkInterfaces();
[[self.host]] = for dev of ifaces
    for details in ifaces[dev] when details.family is "IPv4" and details.address isnt "127.0.0.1"    
        details.address 

# Broadcast address
[first..., last] = self.host.split "."
last = "255"
broadcast = [first..., last].join "."

# peers
knownPeers = []

same = (p1, p2) ->
    p1.host is p1.host and p1.port is p2.port

knows = (peer) ->
    (knownPeers.findOne (p) -> same(p, peer))?
    
addPeer = (peer) ->
    return if same peer, self
    knownPeers.push {
        host: peer.host,
        port: peer.port
    }

#funtions
dummy = (err) ->

doPong = (details) ->
    client = xmlrpc.createClient details
    client.methodCall constants.PONG, [self, knownPeers], dummy

doPing = (details) ->
    client = xmlrpc.createClient details
    client.methodCall constants.PING, [self], dummy

printKnownPeers = () ->
    console.log "Known peers"
    console.log peer for peer in knownPeers
   
# server
server = xmlrpc.createServer self

#rounting
server.on constants.PING, (err, [peer], callback) ->
    callback() # acknowledge
    doPong peer
    addPeer peer if not knows peer

server.on constants.PONG, (err, [sender, peers], callback) ->
    callback() # acknowledge
    addPeer sender if not knows sender
    for peer in peers when not knows peer
        addPeer peer
        doPing peer
        
        
console.log "Listening on %s:%s", self.host, self.port
        
# helpers
parseHello = (address = "#{ broadcast }:2210", done) ->
    [host, port] = address.trim().split ":"
    done {
        host: host,
        port: port
    }
        
# input
process.stdout.write "> "
process.stdin.resume()
process.stdin.setEncoding "utf8"

process.stdin.on "data", (data) ->
    [command, address] = data.split " "
    command = command.trim()
    switch command
        when constants.HELLO then parseHello address, doPing
        when constants.PLIST then printKnownPeers()
        else console.log "unknown command: #{ command }"
            
        
    process.stdout.write "> "

