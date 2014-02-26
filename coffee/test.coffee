Peer = require './peer'
Controllers = require './controllers'
FileLogger = require './filelogger'
require 'array-sugar'
cluster = require 'cluster'
async = require 'async'
count = (require 'os').cpus().length - 1

numberOfPeers = 22
perProcess = (numberOfPeers - 1) / count
caps = [1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 7, 10].reverse()
if cluster.isMaster
    p = new Peer(8000, "Px", 10, [console, new FileLogger "logs/px.txt"])
    new Controllers.CLI p
    for i in [0...count]
        cluster.fork
            offset: i
    cluster.on 'exit', (worker, code, signal) ->
        console.log 'a worker died'
else
    fstPort = 30000
    offset = parseInt process.env.offset
    
    remaining = perProcess
    i = offset*perProcess
    
    allStarted = () -> remaining is 0
    
    startPeer = (done) ->
        peer = new Peer fstPort + i, "P#{ i }", caps[i % caps.length], [new FileLogger "logs/p#{i}.txt"]
        new Controllers.Simple peer
        i++
        remaining--
        setTimeout done, 500    
        
    async.until allStarted, startPeer, () ->