require('array-sugar')
xmlrpc = require('xmlrpc')
constants = require('./constants')
os = require('os')
async = require('async')
fs = require('fs')
Graph = require('./graph.js').Graph
Node = require('./graph.js').Node
Edge = require('./graph.js').Edge

debug = true

args = process.argv[2...]

self = {}

# Identifier
self.id = "P" + args[0]

# Parse port
self.port = parseInt(args[1]) or 8080

# Parse number of capacity
self.capacity = parseInt(args[2]) or 5
remCap = self.capacity
reserved = 0


# Find IP
ifaces = os.networkInterfaces();
for dev of ifaces
    for details in ifaces[dev] when details.family is "IPv4" and not details.internal
        self.host = details.address 

# peers
knownPeers = []
friends = []

addFriend = (p) ->
    throw "Apple sucks" if remCap <= 0
    friends.push p
    remCap--

unFriend = (p) ->
    oldFriend = friends.findOne (p1) -> same p, p1
    if oldFriend?
        remCap++
        friends.remove oldFriend
    else
        throw 'The apple isn\'t blue'

same = (p1, p2) ->
    p1.host is p2.host and p1.port is p2.port

knows = (peer) ->
    (knownPeers.findOne (p) -> same p, peer)?
    
isFriend = (peer) ->
    (friends.findOne (p) -> same p, peer)?
    
addPeer = (peer) ->
    return if (same peer, self) or (knows peer)
    knownPeers.push peer
    
removePeer = (peer) ->
    knownPeers.remove peer

#funtions
removeOnError = (peer, err) ->
    (err) ->
        removePeer peer if err.code?

doPong = (peer) ->
    console.log "ponging %s:%s", peer.host, peer.port if debug
    if (not peer.host?)
        console.log typeof peer
    client = xmlrpc.createClient peer
    client.methodCall constants.PONG, [self, knownPeers], removeOnError(peer)

doPing = (peer, self) ->
    console.log "pinging %s:%s", peer.host, peer.port if debug
    client = xmlrpc.createClient peer
    client.methodCall constants.PING, [self], removeOnError(peer)
    
doForceFriend = (peer, token, done) ->
    console.log "force friending %s", peer.id if debug
    if isFriend peer
        done()
    else
        remCap -= 2 #reserve spot for peer and maybe kicked peer
        reserved += 2
        client = xmlrpc.createClient peer
        client.methodCall constants.FORCE_FRIEND, [self, token], (err, args) ->
            remCap++ #unreserve spot for contacted peer
            reserved--
            if not err or not err.code?
                kickedPeer = args[0]
                addFriend peer
                if not kickedPeer #unreserve spot for kicked peer - he is not kicked!!
                    remCap++ 
                    reserved--
            done(err)
        
doFriend = (peer, token, done) ->
    console.log "friending %s", peer.id if debug
    client = xmlrpc.createClient peer
    remCap-- #reserve
    reserved++
    client.methodCall constants.FRIEND, [self, token], (err) ->
        remCap++ #unreserve
        reserved--
        if err? and err.code?
            removePeer peer
        else
            addFriend peer
        done()
        
doUnfriend = (peer, newPeer, token) ->
    console.log "unfriending %s", peer.id if debug
    unFriend peer
    client = xmlrpc.createClient peer
    client.methodCall constants.UNFRIEND, [self, newPeer, token], removeOnError(peer)

printKnownPeers = (done) ->
    console.log "Known peers"
    ids = knownPeers.map (p) -> p.id
    ids.sort()
    console.log id for id in ids
    done()
   
# server
server = xmlrpc.createServer {
    port: self.port
}

#rounting
server.on constants.PING, (err, [peer], callback) ->
    callback() # acknowledge
    if (peer? and peer isnt "")
        doPong peer
        addPeer peer

server.on constants.PONG, (err, [sender, peers], callback) ->
    callback() # acknowledge
    addPeer sender
    for peer in peers 
        if (not knows peer) and (not same peer, self)
            doPing peer, self
        
server.on constants.FORCE_FRIEND, (err, [peer, token], callback) ->
    if remCap > 0
        callback null, false
    else
        friends.sort (p1, p2) -> p1.capacity - p2.capacity
        oldFriend = friends.first 
        doUnfriend oldFriend, peer, token
        callback null, true
    addFriend peer

server.on constants.UNFRIEND, (err, [oldFriend, peer, token], callback) ->
    callback()
    unFriend oldFriend
    doFriend peer, token, () -> 
    
server.on constants.FRIEND, (err, [peer, token], callback) ->
    if token? #TODO: check token
        remCap++
        reserved--
    if remCap > 0
        addFriend peer
        callback()
    else
        callback("I have enough friends, Nigger!!")
        
server.on constants.GRAPH, (err, [], callback) ->
    console.log "graph"
    callback null, getGraph()
        
console.log "Listening on %s:%s", self.host, self.port
        
# helpers
hello = ([address], done) ->
    if address
        [host, port] = address.trim().split ":"
        doPing {
            host: host,
            port: port
        }, self
    else
        doPing peer for peer in knownPeers
    done()
    
dream = ([timeout], done) ->
    timeout = parseInt(timeout) or 1000
    setTimeout(done, timeout)

getGraph = () ->
    graph = new Graph()
    node = new Node self.id, self.capacity
    graph.addNode node
    friends.forEach (n) ->
        graph.addEdge new Edge node, (new Node n.id, n.capacity)
    return graph
            
            
printNeighbourhood = (args, done) ->
    peers = []
    out = null
    nextIsOutput = false
    args.forEach (arg) ->
        if arg is "-o"
            nextIsOutput = true
        else if nextIsOutput
            nextIsOutput = false
            out = arg
        else
            if arg isnt ""
                peers.push(arg)
    
    graph = getGraph()
    handlePeer = (peer, done) ->
        peer = knownPeers.findOne (p) -> p.id is peer
        if not peer?
            done()
            return
        client = xmlrpc.createClient peer
        client.methodCall constants.GRAPH, [], (err, g) ->
            g.nodes.forEach (n) ->
                graph.addNode (new Node n.id, n.capacity)
            g.edges.forEach (e) ->
                e.n1 = new Node e.n1.id, e.n1.capacity
                e.n2 = new Node e.n2.id, e.n2.capacity
                graph.addEdge (new Edge e.n1, e.n2)
            done()
    
    console.log "#####", peers.isEmpty
    if debug and peers.isEmpty
        peers.push p.id for p in knownPeers
        
    async.each peers, handlePeer, (err) ->
        # handle output
        if out?
            fs.writeFile out, graph.print()
        else
            console.log "reserved: " + reserved + "/" + remCap + "\n" + graph.print()
        done()
        
createToken = () -> self.id
        
joinNeighbourhood = (done) ->
    done()
    if self.capacity is 1
        #special case
    else
        startLoop = (err) ->
            if err
                knownPeers.remove highCap
                joinNeighbourhood () ->
            else
                haveCapacity = () ->
                    remCap > 0
                friendRandomPeer = (done) ->
                    candidates = knownPeers.copy()
                    friends.forEach (f1) ->
                        candidates.remove f for f in candidates.filter (f2) -> f1.id is f2.id
                    idx = Math.floor Math.random()*candidates.length
                    peer = candidates[idx];
                    if peer?
                        doFriend peer, null, done
                    else
                        done("No more peers")
                
                async.whilst haveCapacity, friendRandomPeer, (err) ->
                    console.log remCap
                    console.log err if debug and err?
        
        if (friends.findOne (p) -> p.capacity >= constants.limits.HIGH)?
            startLoop()
        else
            highCap = knownPeers.findOne (p) -> p.capacity >= constants.limits.HIGH #TODO: randomize!!!!!
            highCap ?= knownPeers.first
            if highCap?
                doForceFriend highCap, createToken(), startLoop
            else
                startLoop()

exit = () ->
    process.exit(0)
        
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
            when constants.HELLO then hello args, done
            when constants.PLIST then printKnownPeers done
            when constants.DREAM then dream args, done
            when constants.EXIT then exit()
            when constants.NLIST then printNeighbourhood args, done
            when constants.JOIN then joinNeighbourhood done
            else
                console.log "unknown command: #{ command }"
                done()
                
    done = () -> process.stdout.write "> " 
    async.eachSeries data, processData, done 

setTimeout () ->
    hello [], () ->
        joinNeighbourhood () ->
    
, 5000

