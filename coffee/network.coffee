require('array-sugar')
xmlrpc = require('xmlrpc')
constants = require('./constants')
EventEmitter = (require 'events').EventEmitter
    
class Network extends EventEmitter
    constructor: (port, log) ->
        log ?= () ->
        server = xmlrpc.createServer
            port: port
        
        createClient = (receiver) =>
            xmlrpc.createClient
                port: receiver.port
                host: receiver.host
        
        @pong = (receiver, sender, knownPeers, done) ->
            client = createClient receiver
            client.methodCall constants.PONG, [sender, knownPeers], done
        
        @ping = (receiver, sender, done) ->
            client = createClient receiver
            client.methodCall constants.PING, [sender], done
            
        @forceFriend = (receiver, sender, token, done) ->
            client = createClient receiver
            client.methodCall constants.FORCE_FRIEND, [sender, token], done
                
        @friend = (receiver, sender, token, done) ->
            client = createClient receiver
            client.methodCall constants.FRIEND, [sender, token], done
                
        @unfriend = (receiver, sender, newPeer, token, done) ->
            client = createClient receiver
            client.methodCall constants.UNFRIEND, [sender, newPeer, token], done
        
        @deleteToken = (receiver, token, done) =>
            client = createClient receiver
            client.methodCall constants.DELETE_TOKEN, [token], done
            
        @createGraph = (receiver, done) =>
            client = createClient receiver
            client.methodCall constants.GRAPH, [], done
            
        @query = (receiver, origin, query, details, done) =>
            client = createClient receiver
            client.methodCall constants.QUERY, [origin, query, details], done
            
        @queryResult = (receiver, result, details, done) =>
            client = createClient receiver
            client.methodCall constants.QUERY_RESULT, [result, details], done
        
        
        #rounting
        server.on constants.PING, (err, [peer], callback) =>
            callback null # acknowledge
            @emit constants.PING, peer
        
        server.on constants.PONG, (err, [sender, peers], callback) =>
            callback null # acknowledge
            @emit constants.PONG, sender, peers
                
        server.on constants.FORCE_FRIEND, (err, [peer, token], callback) =>
            @emit constants.FORCE_FRIEND, peer, token, (kicked) -> callback null, kicked
            
        server.on constants.UNFRIEND, (err, [oldFriend, peer, token], callback) =>
            callback null # acknowledge
            @emit constants.UNFRIEND, oldFriend, peer, token
            
        server.on constants.FRIEND, (err, [peer, token], callback) =>
            @emit constants.FRIEND, peer, token, (err) -> callback null, err
                
        server.on constants.GRAPH, (err, [], callback) =>
            @emit constants.GRAPH, (graph) -> callback null, graph
            
        server.on constants.DELETE_TOKEN, (err, [token], callback) =>
            callback null # acknowledge
            @emit constants.DELETE_TOKEN, token
            
        server.on constants.QUERY, (err, [origin, query, details], callback) =>
            callback null # acknowledge
            @emit constants.QUERY, origin, query, details
            
        server.on constants.QUERY_RESULT, (err, [result, details], callback) =>
            callback null # acknowledge
            @emit constants.QUERY_RESULT, result, details
            
        
        
        log "Listening on #{ @port }"
                
module.exports = Network

