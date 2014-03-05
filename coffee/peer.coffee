require('array-sugar')
constants = require('./constants')
os = require('os')
async = require('async')
fs = require('fs')
Graph = require('./graph').Graph
Node = require('./graph').Node
Edge = require('./graph').Edge
Network = require('./network')

debug = true

same = (p1, p2) =>
    p1.host is p2.host and p1.port is p2.port
count = 0

# Find IP
ifaces = os.networkInterfaces();
for dev of ifaces
    for details in ifaces[dev] when details.family is "IPv4" and not details.internal
        host = details.address 
    
class Peer
    constructor: (@port, @id, @capacity = 5, loggers = []) ->
        
        remCap = @capacity
        reserved = 0
        knownPeers = []
        friends = []
        pendingFriends = []
        
        log = (msg) =>
            logger.log msg for logger in loggers
                
        network = new Network this, log
        @network = network
        
        @addLogger = (logger) =>
            loggers.push logger
        
        
        @host = host
        @host ?= "localhost"
        @host = "localhost" if debug
        
        # helpers
        addFriend = (p) =>
            log "is friends already" if isFriend p
            throw "Add friends sucks" if remCap <= 0
            friends.push p
            remCap--
            
        addPendingFriend = (p) =>
            throw "Add pending friends sucks" if remCap <= 0
            pendingFriends.push p
            remCap--
        
        unFriend = (p) =>
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
            log "removing #{peer.id}"
            try
                unfriend peer
            catch
                
                
            for key, peers of fileMap
                pleaseRemoveUs = peers.filter (p) => same p, peer
                peers.remove p for p in pleaseRemoveUs
                    
            knownPeers.remove peer
        
        #funtions
        removeOnError = (peer) =>
            (err) =>
                removePeer peer if err
        
        doPong = (peer) =>
            log "ponging #{ peer.host }:#{ peer.port}"
            network.pong peer, this, knownPeers, removeOnError(peer)
        
        doPing = (peer, self) =>
            log "pinging #{ peer.host }:#{ peer.port}" if debug
            addPeer peer if peer.id? #if peers have no id it is bootstraping
            network.ping peer, self, (err) -> removeOnError(peer)
            
        doForceFriend = (peer, token, done) =>
            log "#{@id} is forcefriending #{peer.id}"
            if isFriend peer
                log "#{@id} and #{peer.id} are already friends"
                done()
            else
                remCap-- #reserve spot for peer and maybe kicked peer
                addPendingFriend peer
                network.forceFriend peer, this, token, (err, kickedPeer) =>
                    removePendingFriend peer
                    if err?
                        log "#{@id} failed request to #{peer.id}"
                        removePeer peer
                    else
                        addFriend peer
                        if kickedPeer 
                            log "#{@id}: #{peer.id} kicked a peer"
                        else 
                            remCap++ #unreserve spot for kicked peer - no one is kicked!!
                            log "#{@id}: #{peer.id} did not kick a peer"
                    done(err)
                
        doFriend = (peer, token, done) =>
            log "#{@id} is trying to friend #{peer.id}"
            addPendingFriend peer
            network.friend peer, this, token, (err, res) =>
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
                log "#{@id} is unfriending #{peer.id}"
                unFriend peer
                network.unfriend peer, this, newPeer, token, removeOnError peer
        
        doDeleteToken = (peer, token) =>
            log "#{@id} tells #{peer.id} to delete token"
            network.deleteToken peer, token, removeOnError peer
        
        #rounting
        network.on "ping", (peer) =>
            if (peer? and peer isnt "")
                doPong peer
                addPeer peer
        
        network.on "pong", (sender, peers) =>
            addPeer sender
            for peer in peers 
                if (not knows peer) and (not same peer, this)
                    log "got #{peer.id} from #{sender.id}"
                    doPing peer, this
                
        network.on "force_friend", (peer, token, callback) =>
            if remCap > 0 or isFriend peer or isPendingFriend peer
                log "#{@id} accepts forcefriend from #{peer.id}. No one kicked"
                callback false
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
                callback true
            addFriend peer if not (isFriend peer or isPendingFriend peer)
        
        network.on "unfriend", (oldFriend, peer, token) =>
            if isFriend oldFriend
                unFriend oldFriend
                doFriend peer, token, () =>
            else
                doDeleteToken peer, token if token
            
        network.on "friend", (peer, token, callback) =>
            if token? #TODO: check token
                remCap++
                reserved--
            if remCap > 0 or isFriend peer or isPendingFriend peer
                log "#{@id} accepts #{peer.id}"
                addFriend peer if not (isFriend peer or isPendingFriend peer)
                callback()
            else
                log "#{@id} rejects #{peer.id}"
                callback constants.errors.ENOUGH_FRIENDS
                
        network.on "graph", (callback) =>
            log "graph"
            callback @getGraph()
            
        network.on "delete_token", (token) =>
            if token? #TODO: check token
                remCap++
        
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
                network.createGraph peer, (err, g) =>
                    log "got response from #{peer.id}"
                    if (err)
                        log "error for #{peer.id}"
                    else
                        g.nodes.forEach (n) =>
                            if n.id? and n.capacity?
                                graph.addNode (new Node n.id, n.capacity)
                            else
                                log "got weird graph from #{peer.id}"
                            
                        g.edges.forEach (e) =>
                            e.n1 = new Node e.n1.id, e.n1.capacity
                            e.n2 = new Node e.n2.id, e.n2.capacity
                            graph.addEdge (new Edge e.n1, e.n2)
                    done()
            
            if debug and peers.isEmpty
                peers.push p.id for p in knownPeers
                
            async.each peers, handlePeer, (err) =>
                # handle output
                if err?
                    log "error in printing " + err
                else if out?
                    fs.writeFile out, graph.print(), (err) =>
                        console.error err if err?
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
                candidates.sort (p1, p2) => p2.capacity - p1.capacity
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
        
        # reporting           
        @report = (file) =>
            buffer = ""
            buffer += "peer, query, , kquery, , found,\n"
            buffer += ", sent, received, sent, received, sent, received\n"
            network.getData this, ["query", "kquery", "found"], (data) ->
                buffer += "#{data}\n"
                async.each knownPeers, (peer, done) =>
                    network.getData peer, ["query", "kquery", "found"], (data) ->
                        buffer += "#{data}\n"
                        done()
                , () ->
                    if file?
                        fs.writeFile file, buffer, () ->
                    else
                        log buffer
        
        # searching
        nextId = 0
        sentQueries = []
        seenQueries = {}
        
        @search = (query, ttl = constants.TTL) =>
            log "seaching for #{query} with flooding"
            id = nextId++
            details =
                ttl: ttl
                id: id
            sentQueries[id] = query
            friends.forEach (peer) =>
                network.query peer, this, query, details, removeOnError peer
        
        
            
        network.on "query", (origin, query, details) =>
            seenQueries[origin.id] ?= []
            bucket = seenQueries[origin.id]
            return if bucket.contains details.id #ignore query
            log "query (#{query}) from #{origin.id}. Id: #{details.id}, TTL: #{details.ttl}"
            
            bucket.push details.id
            fs.exists "#{folder}/#{query}", (exists) =>
                if exists
                    network.queryResult origin, this, details, removeOnError origin
                else if details.ttl > 1
                    details.ttl--
                    forward = (peer) =>
                        network.query peer, origin, query, details, removeOnError peer
                    forward peer for peer in friends when not (same peer, origin)
                    
        @ksearch = (query, k = 4, ttl = 256) =>
            log "seaching for #{query} with texas rangers"
            candidates = friends.copy()
            id = nextId++
            details =
                path: [@id]
                ttl: ttl
                id: id
                modulo: 4
                lifetime: ttl
                
            sentQueries[id] = query
            for i in [0...k] when candidates.length isnt 0
                idx = Math.floor Math.random() * candidates.length
                peer = candidates[idx]
                candidates.remove peer if peer.capacity is 1
                network.kquery peer, this, query, details, removeOnError peer
            
        network.on "kquery", (origin, query, details) =>
            path = details.path.join ','
            log "kquery (#{query}) from #{origin.id}. Id: #{details.id}, TTL: #{details.ttl}."
            
            fs.exists "#{folder}/#{query}", (exists) =>
                if exists
                    network.queryResult origin, this, details, removeOnError origin
                else if details.ttl > 1
                    details.ttl--
                    cont = () =>
                        candidates = friends.copy()
                        if candidates.length > 1
                            candidates.remove friends.findOne (p) => p.id is details.path.last
                        details.path.push @id
                        idx = Math.floor Math.random() * candidates.length
                        peer = candidates[idx]
                        network.kquery peer, origin, query, details, removeOnError peer
                        
                    if (details.lifetime - details.ttl) % details.modulo is 0
                        network.found origin, @id, details.id, (err, found) =>
                            if err
                                (removeOnError origin) err
                            else if not found
                                cont()
                    else
                        cont()
        foundIds = []
        network.on "found", (sender, id, callback) =>
            log "walkercallback from #{sender}: (#{id})"
            callback foundIds.contains id
                    
        network.on "query_result", (sender, details) =>
            id = details.id
            foundIds.push id
            query = sentQueries[id]
            log "found #{query} at #{sender.id}"
            fileMap[query] ?= []
            fileMap[query].push sender
        
        # File handling
        fileMap = {}            
        @getFile = (file, done) =>
            peers = fileMap[file]
            if peers?
                peer = peers.first
                if peer?
                    network.fetchFile peer, file, (err, data) ->
                        (removeOnError peer) err
                        if err?
                            done "File not found. Please call find #{file}"
                        else
                            fs.writeFile "#{folder}/#{file}", data, (err) =>
                                if err?
                                    done "Error writing #{file}!!!"
                                else
                                    done "Success writing #{file}!!!"
                else
                    done "File not found. Please call find #{file}"
            else
                done "File not found. Please call find #{file}"
        
        network.on "file", (file, done) =>
            fs.readFile "#{folder}/#{file}", done
        
        # setup file structure - an empty folder for every peer
        folder = "files/#{@id}"
        fs.mkdir folder, (err) =>
            if err? and err.code is "EEXIST"
                fs.readdir folder, (err, files) =>
                    if not err? and files?
                        fs.unlink "#{folder}/#{file}" for file in files
                
        
                    
        joinEvery30Second = () =>
            @printNeighbourhood ["THIS IS AWESOME", "-o", "#{folder}/graph_#{@id}.dot"], () =>
                setTimeout () =>
                    console.log "### %s TICK ###", @id
                    @joinNeighbourhood () ->
                , 5000
        
        network.on 'ready', ()  =>
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

