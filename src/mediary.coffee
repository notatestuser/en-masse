{TcpInterface} = require './interfaces'

###* Eradicate the need to catch errors manually in callback soup ###
captureError = (errorCb, successCb) ->
  (err, retVal) ->
    return errorCb?(err) if err
    successCb?(null, retVal)

###* Encapsulates liason with the registry and interface ###
class Mediary
  constructor: (@nickname, @registry, @interface) ->
    @wrappers = []

  withDefaults: ->
    @registry  = new RedisRegistry() if not @registry
    @interface = new TcpInterface()  if not @interface
    @

  addStreamWrapper: (wrapperFn) ->
    @wrappers.push wrapperFn

  to: (nicknamePattern, callback) ->
    # ensure we have a registry and an interface to use
    @withDefaults()

    # ensure our interface is listening out for connections
    @interface.listen() if not @interface.listening

    # our identifier will be published to the registry
    @interface.getHostIdentifier @nickname, captureError(callback, (err, _hostIdentifier) =>

      # publish our host in the registry
      @registry.publish _hostIdentifier

      # ask the @registry to lookup the given nicknamePattern
      @registry.lookup nicknamePattern, captureError(callback, (err, _clientIdentifier) =>

        # make a connection to the remote host
        @interface.connect _clientIdentifier, captureError(callback, (err, _socket) =>

          # wrap the client in layers of wrappers and get outta here
          callback? err, @_wrapStream(_socket)

        )
      )
    )

  _wrapStream: (stream) ->
    @wrappers.forEach (_wrapperFn) ->
      stream = _wrapperFn(stream)
    stream

module.exports = Mediary
