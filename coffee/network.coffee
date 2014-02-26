require('array-sugar')
xmlrpc = require('xmlrpc')
EventEmitter = (require 'events').EventEmitter
    
PONG = "pong"
PING = "ping"
FORCE_FRIEND = "force_friend"
FRIEND = "friend"
UNFRIEND = "unfriend"
DELETE_TOKEN = "delete_token"
GRAPH = "graph"
QUERY = "query"
QUERY_RESULT = "query_result"
KQUERY = "kquery"
FILE = "file"
FOUND = "found"
REPORT = "report"
    
class Network extends EventEmitter
    constructor: (peer, log) ->
        port = peer.port
        log ?= () ->
        server = xmlrpc.createServer
            port: port
        
        createClient = (receiver) =>
            xmlrpc.createClient
                port: receiver.port
                host: receiver.host
        
        sent = {}
        received = {}
        updateData = (records, key, data) =>
            records[key] ?=
                count: 0
                data: 0
            records[key].count++
            data ?= 0
            if typeof data isnt "number"
                data = parseInt data.options.headers['Content-Length']
            records[key].data += data
        
        @pong = (receiver, sender, knownPeers, done) ->
            client = createClient receiver
            client.methodCall PONG, [sender, knownPeers], done
            updateData sent, PONG, client
        
        @ping = (receiver, sender, done) ->
            client = createClient receiver
            client.methodCall PING, [sender], done
            updateData sent, PING, client
            
        @forceFriend = (receiver, sender, token, done) ->
            client = createClient receiver
            client.methodCall FORCE_FRIEND, [sender, token], done
            updateData sent, FORCE_FRIEND, client
                
        @friend = (receiver, sender, token, done) ->
            client = createClient receiver
            client.methodCall FRIEND, [sender, token], done
            updateData sent, FRIEND, client
                
        @unfriend = (receiver, sender, newPeer, token, done) ->
            client = createClient receiver
            client.methodCall UNFRIEND, [sender, newPeer, token], done
            updateData sent, UNFRIEND, client
        
        @deleteToken = (receiver, token, done) =>
            client = createClient receiver
            client.methodCall DELETE_TOKEN, [token], done
            updateData sent, DELETE_TOKEN, client
            
        @createGraph = (receiver, done) =>
            client = createClient receiver
            client.methodCall GRAPH, [], done
            updateData sent, GRAPH, client
            
        @query = (receiver, origin, query, details, done) =>
            client = createClient receiver
            client.methodCall QUERY, [origin, query, details], done
            updateData sent, QUERY, client
            
        @kquery = (receiver, origin, query, details, done) =>
            client = createClient receiver
            client.methodCall KQUERY, [origin, query, details], done
            updateData sent, KQUERY, client
            
        @queryResult = (receiver, result, details, done) =>
            client = createClient receiver
            client.methodCall QUERY_RESULT, [result, details], done
            updateData sent, QUERY_RESULT, client
        
        @fetchFile = (receiver, file, done) =>
            client = createClient receiver
            client.methodCall FILE, [file], done
            updateData sent, FILE, client
            
        @found = (receiver, sender, id, done) =>
            client = createClient receiver
            client.methodCall FOUND, [sender, id], done
            updateData sent, FOUND, client
            
        @getData = (peer, keys, done) =>
            client = createClient peer
            client.methodCall REPORT, [keys], (err, str) =>
                done str
        
        #rounting
        server.on PING, (err, [peer], callback) =>
            callback null # acknowledge
            updateData received, PING
            @emit PING, peer
        
        server.on PONG, (err, [sender, peers], callback) =>
            callback null # acknowledge
            updateData received, PONG
            @emit PONG, sender, peers
                
        server.on FORCE_FRIEND, (err, [peer, token], callback) =>
            updateData received, FORCE_FRIEND
            @emit FORCE_FRIEND, peer, token, (kicked) -> callback null, kicked
            
        server.on UNFRIEND, (err, [oldFriend, peer, token], callback) =>
            callback null # acknowledge
            updateData received, UNFRIEND
            @emit UNFRIEND, oldFriend, peer, token
            
        server.on FRIEND, (err, [peer, token], callback) =>
            updateData received, FRIEND
            @emit FRIEND, peer, token, (err) -> callback null, err
                
        server.on GRAPH, (err, [], callback) =>
            updateData received, GRAPH
            @emit GRAPH, (graph) -> callback null, graph
            
        server.on DELETE_TOKEN, (err, [token], callback) =>
            callback null # acknowledge
            updateData received, DELETE_TOKEN
            @emit DELETE_TOKEN, token
            
        server.on QUERY, (err, [origin, query, details], callback) =>
            callback null # acknowledge
            updateData received, QUERY
            @emit QUERY, origin, query, details
            
        server.on KQUERY, (err, [origin, query, details], callback) =>
            callback null # acknowledge
            updateData received, KQUERY
            @emit KQUERY, origin, query, details
            
        server.on QUERY_RESULT, (err, [result, details], callback) =>
            callback null # acknowledge
            updateData received, QUERY_RESULT
            @emit QUERY_RESULT, result, details
            
        server.on FILE, (err, [file], callback) =>
            updateData received, FILE
            @emit FILE, file, callback
            
        server.on FOUND, (err, [sender, id], callback) =>
            updateData received, FOUND
            @emit FOUND, sender, id, (found) => callback null, found
            
        server.on REPORT, (err, [keys], callback) =>
            buffer = ""
            for key in keys
                s = sent[key]
                r = received[key]
                s ?=
                    count: 0
                r ?=
                    count: 0
                buffer += ", #{s.count}, #{r.count}"
            callback null, "#{peer.id}#{buffer}"
            
        log "Listening on port #{port}"
                
module.exports = Network

