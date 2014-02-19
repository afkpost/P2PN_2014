Peer = require('./peer')
Controllers = require('./controllers')
require 'array-sugar'

caps = [1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 7, 8, 10]

p = new Peer(8000, "P0", caps[0], [console])
fstPort = 30000

for i in [1...10]
    new Controllers.Simple new Peer fstPort + i, "P#{ i }", caps[i % caps.length]
    
new Controllers.CLI p