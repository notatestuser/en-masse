net              = require 'net'
{getNetworkIPs}  = require 'node-networkip'

class Base
  ###* The base interface doesn't know anything about the underlying protocol ###
  constructor: ->
    # all we can really assume is that we're not already listening
    @listening = no

class Tcp extends Base
  ###* TCP binds to a port on a host, so these are provided ###
  constructor: (@port = 3000, @host) ->
    super()

  ###* Connect to the client associated with a given identifier ###
  connect: (identifier, callback) ->
    client = net.connect
      host: identifier.host
      port: identifier.port
    , ->
      callback? null, client

  ###* Listen for connections as a server on the configured port ###
  listen: (callback) ->
    server = net.createServer (_socket) ->
      callback? null, _socket
    server.listen @port, =>
      @listening = yes

  ###* Make an identifier hash for the current host - this is what we register ###
  getHostIdentifier: (nickname, callback) ->
    callbackFn = (err) =>
      callback? err,
        name: nickname
        host: @host
        port: @port
    if @host
      return callbackFn()
    # attempt to find this host's network IP
    getNetworkIPs (err, _ips = []) =>
      return callback(err) if err
      @host = _ips[0]
      callbackFn err

module.exports.BaseInterface = Base
module.exports.TcpInterface  = Tcp
