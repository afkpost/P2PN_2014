// Generated by CoffeeScript 1.6.3
(function() {
  var CLIController, FileController, SimpleController, async, constants, fs,
    __slice = [].slice;

  fs = require('fs');

  async = require('async');

  constants = require('./constants');

  CLIController = (function() {
    function CLIController(peer) {
      var get, kseach, report, search;
      process.stdout.write("> ");
      process.stdin.resume();
      process.stdin.setEncoding("utf8");
      search = function(_arg, done) {
        var query, ttl;
        query = _arg[0], ttl = _arg[1];
        if (ttl != null) {
          ttl = parseInt(ttl);
        }
        peer.search(query, ttl);
        return done();
      };
      kseach = function(_arg, done) {
        var k, query, ttl;
        query = _arg[0], k = _arg[1], ttl = _arg[2];
        if (k != null) {
          k = parseInt(k);
        }
        if (ttl != null) {
          ttl = parseInt(ttl);
        }
        peer.ksearch(query, k, ttl);
        return done();
      };
      get = function(_arg, done) {
        var file;
        file = _arg[0];
        return peer.getFile(file, done);
      };
      report = function(_arg, done) {
        var file;
        file = _arg[0];
        peer.report(file);
        return done();
      };
      process.stdin.on("data", function(data) {
        var done, processData;
        data = data.trim().split('\n');
        processData = function(data, done) {
          var args, command, _ref;
          data = data.trim();
          if (data === "") {
            done();
          }
          _ref = data.split(" "), command = _ref[0], args = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
          command = command.trim();
          switch (command) {
            case constants.HELLO:
              return peer.hello(args, done);
            case constants.PLIST:
              return peer.printKnownPeers(done);
            case constants.DREAM:
              return peer.dream(args, done);
            case constants.EXIT:
              return process.exit(0);
            case constants.NLIST:
              return peer.printNeighbourhood(args, done);
            case constants.JOIN:
              return peer.joinNeighbourhood(done);
            case constants.FIND:
              return search(args, done);
            case constants.KFIND:
              return kseach(args, done);
            case constants.REPORT:
              return report(args, done);
            case constants.GET:
              return get(args, done);
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
    }

    return CLIController;

  })();

  FileController = (function() {
    function FileController(file, peer) {
      fs.readFile(file, {
        encoding: "utf8"
      }, function(err, data) {
        if (err != null) {
          return console.log(err);
        } else {
          return setTimeout(function() {
            var done, processData;
            data = data.trim().split('\n');
            processData = function(data, done) {
              var args, command, _ref;
              data = data.trim();
              if (data === "") {
                done();
              }
              _ref = data.split(" "), command = _ref[0], args = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
              command = command.trim();
              switch (command) {
                case constants.HELLO:
                  return peer.hello(args, done);
                case constants.PLIST:
                  return peer.printKnownPeers(done);
                case constants.DREAM:
                  return peer.dream(args, done);
                case constants.EXIT:
                  return process.exit(0);
                case constants.NLIST:
                  return peer.printNeighbourhood(args, done);
                case constants.JOIN:
                  return peer.joinNeighbourhood(done);
                default:
                  return done();
              }
            };
            done = function() {};
            return async.eachSeries(data, processData, done);
          }, 1000);
        }
      });
    }

    return FileController;

  })();

  SimpleController = (function() {
    function SimpleController(peer) {
      peer.network.on('ready', function() {
        return peer.hello(["localhost:8000"], function() {});
      });
    }

    return SimpleController;

  })();

  module.exports = {
    CLI: CLIController,
    File: FileController,
    Simple: SimpleController
  };

}).call(this);
