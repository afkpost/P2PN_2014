// Generated by CoffeeScript 1.6.3
(function() {
  var Edge, Graph, Node, addFriend, addPeer, args, async, constants, createToken, debug, details, dev, doForceFriend, doFriend, doPing, doPong, doUnfriend, dream, exit, friends, hello, ifaces, joinNeighbourhood, knownPeers, knows, os, printKnownPeers, printNeighbourhood, remCap, removeOnError, removePeer, same, self, server, unFriend, xmlrpc, _i, _len, _ref,
    __slice = [].slice;

  require('array-sugar');

  xmlrpc = require('xmlrpc');

  constants = require('./constants');

  os = require('os');

  async = require('async');

  Graph = require('./graph.js').Graph;

  Node = require('./graph.js').Node;

  Edge = require('./graph.js').Edge;

  debug = true;

  args = process.argv.slice(2);

  self = {};

  self.id = "P" + args[0];

  self.port = parseInt(args[1]) || 8080;

  self.capacity = parseInt(args[2]) || 5;

  remCap = self.capacity;

  ifaces = os.networkInterfaces();

  for (dev in ifaces) {
    _ref = ifaces[dev];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      details = _ref[_i];
      if (details.family === "IPv4" && !details.internal) {
        self.host = details.address;
      }
    }
  }

  knownPeers = [];

  friends = [];

  addFriend = function(p) {
    if (remCap <= 0) {
      throw "Apple sucks";
    }
    friends.push(p);
    return remCap--;
  };

  unFriend = function(p) {
    var oldFriend;
    oldFriend = friends.findOne(function(p1) {
      return same(p, p1);
    });
    if (oldFriend != null) {
      remCap++;
      return friends.remove(oldFriend);
    } else {
      throw 'The apple isn\'t blue';
    }
  };

  same = function(p1, p2) {
    return p1.host === p2.host && p1.port === p2.port;
  };

  knows = function(peer) {
    return (knownPeers.findOne(function(p) {
      return same(p, peer);
    })) != null;
  };

  addPeer = function(peer) {
    if ((same(peer, self)) || (knows(peer))) {
      return;
    }
    return knownPeers.push(peer);
  };

  removePeer = function(peer) {
    return knownPeers.remove(peer);
  };

  removeOnError = function(peer, err) {
    return function(err) {
      if (err.code != null) {
        return removePeer(peer);
      }
    };
  };

  doPong = function(peer) {
    var client;
    if (debug) {
      console.log("ponging %s:%s", peer.host, peer.port);
    }
    client = xmlrpc.createClient(peer);
    return client.methodCall(constants.PONG, [self, knownPeers], removeOnError(peer));
  };

  doPing = function(peer, self) {
    var client;
    if (debug) {
      console.log("pinging %s:%s", peer.host, peer.port);
    }
    client = xmlrpc.createClient(peer);
    return client.methodCall(constants.PING, [self], removeOnError(peer));
  };

  doForceFriend = function(peer, token, done) {
    var client;
    if (debug) {
      console.log("force friending %s", peer.id);
    }
    remCap -= 2;
    client = xmlrpc.createClient(peer);
    return client.methodCall(constants.FORCE_FRIEND, [self, token], function(err, args) {
      var kickedPeer;
      remCap++;
      if (!err || (err.code == null)) {
        kickedPeer = args[0];
        addFriend(peer);
        if (!kickedPeer) {
          remCap++;
        }
      }
      remCap++;
      return done(err);
    });
  };

  doFriend = function(peer, token, done) {
    var client;
    if (debug) {
      console.log("friending %s", peer.id);
    }
    client = xmlrpc.createClient(peer);
    remCap--;
    if (debug) {
      console.log(self, token);
    }
    return client.methodCall(constants.FRIEND, [self, token], function(err) {
      remCap++;
      if (err != null) {
        if (err.code != null) {
          removePeer(peer);
        }
      } else {
        addFriend(peer);
      }
      return done();
    });
  };

  doUnfriend = function(peer, newPeer, token) {
    var client;
    if (debug) {
      console.log("unfriending %s", peer.id);
    }
    unFriend(peer);
    client = xmlrpc.createClient(peer);
    return client.methodCall(constants.UNFRIEND, [self, newPeer, token], removeOnError(peer));
  };

  printKnownPeers = function(done) {
    var id, ids, _j, _len1;
    console.log("Known peers");
    ids = knownPeers.map(function(p) {
      return p.id;
    });
    ids.sort();
    for (_j = 0, _len1 = ids.length; _j < _len1; _j++) {
      id = ids[_j];
      console.log(id);
    }
    return done();
  };

  server = xmlrpc.createServer({
    port: self.port
  });

  server.on(constants.PING, function(err, _arg, callback) {
    var peer;
    peer = _arg[0];
    callback();
    if ((peer != null)) {
      doPong(peer);
      return addPeer(peer);
    }
  });

  server.on(constants.PONG, function(err, _arg, callback) {
    var peer, peers, sender, _j, _len1, _results;
    sender = _arg[0], peers = _arg[1];
    callback();
    addPeer(sender);
    _results = [];
    for (_j = 0, _len1 = peers.length; _j < _len1; _j++) {
      peer = peers[_j];
      if ((!knows(peer)) && (!same(peer, self))) {
        _results.push(doPing(peer, self));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  });

  server.on(constants.FORCE_FRIEND, function(err, _arg, callback) {
    var oldFriend, peer, token;
    peer = _arg[0], token = _arg[1];
    if (remCap > 0) {
      callback(null, false);
    } else {
      friends.sort(function(p1, p2) {
        return p1.capacity - p2.capacity;
      });
      oldFriend = friends.first;
      doUnfriend(oldFriend, peer, token);
      callback(null, true);
    }
    return addFriend(peer);
  });

  server.on(constants.UNFRIEND, function(err, _arg, callback) {
    var oldFriend, peer, token;
    oldFriend = _arg[0], peer = _arg[1], token = _arg[2];
    callback();
    unFriend(oldFriend);
    return doFriend(peer, token, function() {});
  });

  server.on(constants.FRIEND, function(err, _arg, callback) {
    var peer, token;
    peer = _arg[0], token = _arg[1];
    if (token != null) {
      remCap--;
    }
    if (remCap > 0) {
      addFriend(peer);
      return callback();
    } else {
      return callback("I have enough friends, Nigger!!");
    }
  });

  console.log("Listening on %s:%s", self.host, self.port);

  hello = function(_arg, done) {
    var address, host, peer, port, _j, _len1, _ref1;
    address = _arg[0];
    if (address) {
      _ref1 = address.trim().split(":"), host = _ref1[0], port = _ref1[1];
      doPing({
        host: host,
        port: port
      }, self);
    } else {
      for (_j = 0, _len1 = knownPeers.length; _j < _len1; _j++) {
        peer = knownPeers[_j];
        doPing(peer);
      }
    }
    return done();
  };

  dream = function(_arg, done) {
    var timeout;
    timeout = _arg[0];
    timeout = parseInt(timeout) || 1000;
    return setTimeout(done, timeout);
  };

  printNeighbourhood = function(args, done) {
    var graph, handlePeer, nextIsOutput, out, peers;
    peers = [];
    out = null;
    nextIsOutput = false;
    args.forEach(function(arg) {
      if (arg === "-o") {
        return nextIsOutput = true;
      } else if (nextIsOutput) {
        nextIsOutput = false;
        return out = arg;
      } else {
        return peers.push(arg);
      }
    });
    graph = new Graph();
    handlePeer = function(peer, done) {
      return done();
    };
    return async.each(peers, handlePeer, function(err) {
      var node;
      node = new Node(self.id, self.capacity);
      graph.addNode(node);
      friends.forEach(function(n) {
        return graph.addEdge(new Edge(node, new Node(n.id, n.capacity)));
      });
      console.log(graph.print());
      return done();
    });
  };

  createToken = function() {
    return self.id;
  };

  joinNeighbourhood = function(done) {
    var highCap;
    done();
    if (self.capacity === 1) {

    } else {
      highCap = knownPeers.findOne(function(p) {
        return p.capacity >= constants.limits.HIGH;
      });
      if (highCap == null) {
        highCap = knownPeers.first;
      }
      return doForceFriend(highCap, createToken(), function(err) {
        var friendRandomPeer, haveCapacity;
        if (err) {
          knownPeers.remove(highCap);
          return joinNeighbourhood(function() {});
        } else {
          haveCapacity = function() {
            return remCap !== 0;
          };
          friendRandomPeer = function(done) {
            var candidates, idx, peer;
            candidates = knownPeers;
            friends.forEach(function(n) {
              return candidates.remove(n);
            });
            idx = Math.floor(Math.random() * candidates.length);
            peer = candidates[idx];
            if (peer != null) {
              return doFriend(peer, null, done);
            } else {
              return done("No more peers");
            }
          };
          return async.whilst(haveCapacity, friendRandomPeer, function(err) {
            if (debug && (err != null)) {
              return console.log(err);
            }
          });
        }
      });
    }
  };

  exit = function() {
    return process.exit(0);
  };

  process.stdout.write("> ");

  process.stdin.resume();

  process.stdin.setEncoding("utf8");

  process.stdin.on("data", function(data) {
    var done, processData;
    data = data.trim().split('\n');
    processData = function(data, done) {
      var command, _ref1;
      data = data.trim();
      if (data === "") {
        done();
      }
      _ref1 = data.split(" "), command = _ref1[0], args = 2 <= _ref1.length ? __slice.call(_ref1, 1) : [];
      command = command.trim();
      switch (command) {
        case constants.HELLO:
          return hello(args, done);
        case constants.PLIST:
          return printKnownPeers(done);
        case constants.DREAM:
          return dream(args, done);
        case constants.EXIT:
          return exit();
        case constants.NLIST:
          return printNeighbourhood(args, done);
        case constants.JOIN:
          return joinNeighbourhood(done);
        default:
          console.log("unknown command: " + command);
          return done();
      }
    };
    done = function() {
      return process.stdout.write("> ");
    };
    return async.eachSeries(data, processData, done);
  });

  setTimeout(function() {
    return joinNeighbourhood(function() {});
  }, 10000);

}).call(this);