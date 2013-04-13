net              = require 'net'
{getNetworkIPs}  = require 'node-networkip'

class Base
  ###* The base interface doesn't know anything about the underlying protocol ###
  constructor: ->
    # all we can really assume is that we're not already listening
    @listening = no

  ###* Make an identifier hash for the current host - this is what we register ###
  getHostIdentifier: (proto, nickname, callback) ->
    callbackFn = (err) =>
      callback? err,
        name:  nickname
        host:  @host
        port:  @port
        proto: proto
    if @host
      return callbackFn()
    # attempt to find this host's IPv4 address; other protocols may do it their own way
    getNetworkIPs (err, _ips = []) =>
      return callback(err) if err
      @host = _ips[0]
      callbackFn err

class Tcp extends Base
  @PROTO_NAME = 'tcp'

  ###* TCP binds to a port on a host, so these are provided ###
  constructor: (@port = 3000, @host, @options={}) ->
    super()

  ###* Connect to the client associated with a given identifier ###
  connect: (identifier, callback) ->
    client = net.connect
      host: identifier.host
      port: identifier.port
    , ->
      # disable Nagle's algo
      client.setNoDelay @options.noDelay or yes
      callback? null, client

  ###* Listen for connections as a server on the configured port ###
  listen: (callback) ->
    server = net.createServer (_socket) ->
      callback? null, _socket
    server.listen @port, =>
      @listening = yes

  getHostIdentifier: (nickname, callback) ->
    super Tcp.PROTO_NAME, nickname, callback

# ----------

exports = module.exports

exports.getByProtoName = (name) ->
  if name is Tcp.PROTO_NAME
    return Tcp
  throw 'Unknown protocol'

exports.BaseInterface = Base
exports.TcpInterface  = Tcp

# ----------
