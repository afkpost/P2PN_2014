require('array-sugar')
xmlrpc = require('xmlrpc')
constants = require('./constants')
os = require('os')
async = require('async')
fs = require('fs')
Graph = require('./graph').Graph
Node = require('./graph').Node
Edge = require('./graph').Edge

debug = true

same = (p1, p2) =>
    p1.host is p2.host and p1.port is p2.port
count = 0
    
class Peer
    constructor: (@port, @id, @capacity = 5, loggers = []) ->
        remCap = @capacity
        reserved = 0
        knownPeers = []
        friends = []
        pendingFriends = []
        client = null
        
        log = (msg) =>
            logger.log msg for logger in loggers
                
        @addLogger = (logger) =>
            loggers.push logger
        
        
        # Find IP
        ifaces = os.networkInterfaces();
        for dev of ifaces
            for details in ifaces[dev] when details.family is "IPv4" and not details.internal
                @host = details.address 
        
        # helpers
        addFriend = (p) =>
            log "is friends already" if isFriend p
            throw "Add frieds sucks" if remCap <= 0
            friends.push p
            remCap--
            
        addPendingFriend = (p) =>
            throw "Add pending frieds sucks" if remCap <= 0
            pendingFriends.push p
            remCap--
        
        unFriend = (p) =>
            log "#{@id} is unfriending #{p.id}", @id, p.id
            oldFriend = friends.findOne (p1) => same p, p1
            if oldFriend?
                remCap++
                friends.remove oldFriend
            else
                throw 'unfriend sucks'
        
        removePendingFriend = (p) =>
            oldFriend = pendingFriends.findOne (p1) => same p, p1
            if oldFriend?
                remCap++
                pendingFriends.remove oldFriend
            else
                throw 'remove pending friend sucks'
        
        createToken = () => @id
        
        knows = (peer) =>
            (knownPeers.findOne (p) => same p, peer)?
            
        isFriend = (peer) =>
            (friends.findOne (p) => same p, peer)?
            
        isPendingFriend = (peer) =>
            (pendingFriends.findOne (p) => same p, peer)?
            
        addPeer = (peer) =>
            return if (same peer, this) or (knows peer)
            knownPeers.push
                host: peer.host
                port: peer.port
                id: peer.id
                capacity: peer.capacity
            
        removePeer = (peer) =>
            try
                unfriend peer
            catch
                
            knownPeers.remove peer
        
        #funtions
        removeOnError = (peer, err) =>
            (err) =>
                removePeer peer if err
        
        createClient = (peer) =>
            client.options.port = peer.port
            client.options.host = peer.host
            return client
        
        doPong = (peer) =>
            log "ponging #{ peer.host }:#{ peer.port}" if debug
            client = createClient peer
            client.methodCall constants.PONG, [this, knownPeers], (err) => removeOnError(peer)
        
        doPing = (peer, self) =>
            log "pinging #{ peer.host }:#{ peer.port}" if debug
            client = createClient peer
            client.methodCall constants.PING, [self], (err) => removeOnError(peer)
            
        doForceFriend = (peer, token, done) =>
            log "#{@id} is forcefriending #{peer.id}"
            log "force friending #{ peer.id }" if debug
            if isFriend peer
                log "#{@id} and #{peer.id} are already friends"
                done()
            else
                remCap-- #reserve spot for peer and maybe kicked peer
                addPendingFriend peer
                client = createClient peer
                client.methodCall constants.FORCE_FRIEND, [this, token], (err, args) =>
                    removePendingFriend peer
                    log "#{@id} got reply from #{peer.id}"
                    if err?
                        removePeer peer
                    else
                        addFriend peer
                        kickedPeer = args[0]
                        if not kickedPeer #unreserve spot for kicked peer - no one is kicked!!
                            remCap++ 
                            log "#{@id}: #{peer.id} did not kick a peer"
                        else
                            log "#{@id}: #{peer.id} kicked a peer"
                    done(err)
                
        doFriend = (peer, token, done) =>
            log "#{@id} is trying to friend #{peer.id}"
            client = createClient peer
            addPendingFriend peer
            client.methodCall constants.FRIEND, [this, token], (err, res) =>
                removePendingFriend peer
                if err?
                    removePeer peer
                else if res is constants.errors.ENOUGH_FRIENDS
                    log "#{@id} is NOT friend with #{peer.id}"
                else
                    addFriend peer
                    log "#{@id} is now friend with #{peer.id}"
                done()
                
        doUnfriend = (peer, newPeer, token) =>
            if peer?
                log "unfriending #{peer.id}"
                unFriend peer
                client = createClient peer
                client.methodCall constants.UNFRIEND, [this, newPeer, token], removeOnError(peer)
        
           
        # server
        server = xmlrpc.createServer {
            port: @port
        }
        client = xmlrpc.createClient {
            port: @port
            host: "localhost"
        }
        
        #rounting
        server.on constants.PING, (err, [peer], callback) =>
            callback null # acknowledge
            if (peer? and peer isnt "")
                doPong peer
                addPeer peer
        
        server.on constants.PONG, (err, [sender, peers], callback) =>
            callback null # acknowledge
            addPeer sender
            for peer in peers 
                if (not knows peer) and (not same peer, this)
                    doPing peer, this
                
        server.on constants.FORCE_FRIEND, (err, [peer, token], callback) =>
            if remCap > 0 or isFriend peer or isPendingFriend peer
                log "#{@id} accepts forcefriend from #{peer.id}. No one kicked"
                callback null, false
            else
                candidates = friends.copy()
                pendingFriends.forEach (p) =>
                    candidates.remove p
                    
                candidates.sort (p1, p2) => p1.capacity - p2.capacity
                oldFriend = candidates.first
                doUnfriend oldFriend, peer, token
                if oldFriend?
                    log "#{@id} accepts forcefriend from #{peer.id}. #{oldFriend.id} kicked (token #{token})"
                else
                    log "buuh"
                callback null, true
            addFriend peer if not (isFriend peer or isPendingFriend peer)
        
        server.on constants.UNFRIEND, (err, [oldFriend, peer, token], callback) =>
            callback null
            if isFriend oldFriend
                unFriend oldFriend
            doFriend peer, token, () => 
            
        server.on constants.FRIEND, (err, [peer, token], callback) =>
            if token? #TODO: check token
                remCap++
                reserved--
            if remCap > 0 or isFriend peer or isPendingFriend peer
                log "#{@id} accepts #{peer.id}"
                addFriend peer if not (isFriend peer or isPendingFriend peer)
                callback null
            else
                log "#{@id} rejects #{peer.id}"
                callback null, constants.errors.ENOUGH_FRIENDS
                
        server.on constants.GRAPH, (err, [], callback) =>
            log "graph"
            callback null, @getGraph()
                
        log "Listening on #{ @host}: #{ @port }"
        
        # helpers
        @hello = ([address], done) =>
            if address?
                [host, port] = address.trim().split ":"
                doPing {
                    host: host,
                    port: port
                }, this
            else
                doPing peer for peer in knownPeers
            done()
    
        @getGraph = () =>
            graph = new Graph()
            node = new Node @id, @capacity
            graph.addNode node
            friends.forEach (n) =>
                graph.addEdge new Edge node, (new Node n.id, n.capacity)
            return graph
        
        @printNeighbourhood = (args, done) =>
            peers = []
            out = null
            nextIsOutput = false
            args.forEach (arg) =>
                if arg is "-o"
                    nextIsOutput = true
                else if nextIsOutput
                    nextIsOutput = false
                    out = arg
                else
                    if arg isnt ""
                        peers.push(arg)
            
            graph = @getGraph()
            handlePeer = (peer, done) =>
                peer = knownPeers.findOne (p) => p.id is peer
                if not peer?
                    done()
                    return
                client = createClient peer
                client.methodCall constants.GRAPH, [], (err, g) =>
                    log "got response from #{peer.id}"
                    if (err)
                        done()
                    else
                        g.nodes.forEach (n) =>
                            graph.addNode (new Node n.id, n.capacity)
                        g.edges.forEach (e) =>
                            e.n1 = new Node e.n1.id, e.n1.capacity
                            e.n2 = new Node e.n2.id, e.n2.capacity
                            graph.addEdge (new Edge e.n1, e.n2)
                        done()
            
            if debug and peers.isEmpty
                peers.push p.id for p in knownPeers
                
            async.each peers, handlePeer, (err) =>
                # handle output
                if out?
                    fs.writeFile out, graph.print()
                else
                    log "reserved: " + reserved + "/" + remCap + "\n" + graph.print()
                done()
                
        #TODO: remove this        
        @dream = ([timeout], done) =>
            timeout = parseInt(timeout) or 1000
            setTimeout(done, timeout)

        @printKnownPeers = (done) =>
            log "Known peers"
            ids = knownPeers.map (p) => p.id
            ids.sort()
            log id for id in ids
            done()
         
        
        @joinNeighbourhood = (done) =>
            contactedPeers = []
            haveCapacity = () =>
                remCap > 0
            
            if @capacity is 1
                candidates = knownPeers.filter (p) => p.capacity > 1 # do not friend "ones"
                candidates.sort (p1, p2) => p1.capacity - p2.capacity
                async.whilst haveCapacity, (done) =>
                    peer = candidates.first
                    candidates.remove peer
                    if peer?
                        doFriend peer, null, done
                    else
                        done "No more peers"
                , (err) =>
                    log err if err? and debug
                    done()
            else
                startLoop = (err) =>
                    log "#{@id}: loop started"
                    if err
                        knownPeers.remove err.peer if err.peer?
                        @joinNeighbourhood () =>
                    else
                        friendRandomPeer = (done) =>
                            candidates = knownPeers.copy()
                            friends.forEach (f1) =>
                                candidates.remove f for f in candidates.filter (f2) => f1.id is f2.id
                            contactedPeers.forEach (f1) =>
                                candidates.remove f for f in candidates.filter (f2) => f1.id is f2.id
                            idx = Math.floor Math.random()*candidates.length
                            peer = candidates[idx]
                            contactedPeers.push peer
                            if peer?
                                doFriend peer, null, done
                            else
                                done "No more peers"
                        
                        async.whilst haveCapacity, friendRandomPeer, (err) =>
                            log remCap
                            log err if debug and err?
                            done()
                highCaps = knownPeers.filter (p) => p.capacity >= constants.limits.HIGH and not isFriend p
                idx = Math.floor Math.random()*highCaps.length
                highCap = highCaps[idx]
                if highCap? and remCap >= 2
                    doForceFriend highCap, createToken(), startLoop
                else
                    startLoop()
                    
                    
        joinEvery30Second = () =>
            setTimeout () =>
                console.log "### %s TICK ###", @id
                @joinNeighbourhood () ->
            , 15000
                    
        setTimeout () =>
            @joinNeighbourhood joinEvery30Second
        , 2000
        
        ###
        setInterval () =>
            async.each friends, (f, done) =>
                doPing f, null
                done()
            , () =>
        , 10000
        ###

module.exports = Peer

