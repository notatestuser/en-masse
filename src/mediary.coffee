{EventEmitter} = require 'events'
{TcpInterface} = require './interfaces'

###* Eradicate the need to catch errors manually in callback soup ###
captureError = (errorCb, successCb) ->
  (err, retVal) ->
    return errorCb?(err) if err
    successCb?(null, retVal)

###* Encapsulates liason with the registry and interface ###
class Mediary extends EventEmitter
  constructor: (@nickname, @registry, @interface) ->
    [@wrappers, @persisted]  = [[], []]

  setPeerNamespace: (namespace) ->
    @_initDefaultsAndEvents()
      .registry
      .setPeerNamespace(namespace)

  addStreamWrapper: (wrapperFn) ->
    @wrappers.push wrapperFn

  to: (pattern, options={}, callback) ->
    [callback, options] = [options, {}] if typeof options is 'function'

    # ensure we have a registry and an interface to use
    @_initDefaultsAndEvents()

    # ensure our interface is listening out for connections
    @interface.listen() if not @interface.listening

    # make the function that will be invoked on all peers we match
    enactorFn = captureError(callback, (err, _clientIdentifier) =>
      # connect to the remote host
      @interface.connect _clientIdentifier, captureError(callback, (err, _socket) =>
        # wrap the client in layers of wrappers and get outta here
        callback? err, @_wrapStream(_socket)
      )
    )
    pair = [ pattern, enactorFn ]

    # ask the @registry to lookup the given pattern and invoke enactorFn on the resultant host set
    # it doesn't strictly matter if lookup completes before publish because we shouldn't be making streams to ourselves
    @registry.each pattern, [@nickname], enactorFn

    # get our own identifier so that we can publish it
    @interface.getHostIdentifier @nickname, captureError(callback, (err, _hostIdentifier) =>
      # publish our host in the registry
      @registry.publish _hostIdentifier, =>
        # persist to new hosts?
        if options and options.persist
          @persisted.push pair
    )

    pair # is a pointer to a kind of unique identifier that we may have 'persisted'

  _wrapStream: (stream) ->
    @wrappers.forEach (_wrapperFn) ->
      stream = _wrapperFn(stream)
    stream

  _initDefaultsAndEvents: ->
    @interface or= new TcpInterface()
    @registry  or= new RedisRegistry()

    # when a client joins, we'll want to reinstate all persisted callbacks
    @registry.on 'join', (_newIdentifier) =>
      @persisted.forEach (_persisted) =>
        @registry.each _persisted[0], [@nickname], (err, _matchedIdentifier={}) =>
          if _matchedIdentifier.name is _newIdentifier.name
            _persisted[1](err, _matchedIdentifier)
      @emit.apply @, arguments
    @

module.exports = Mediary
