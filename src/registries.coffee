redis          = require 'redis'
{EventEmitter} = require 'events'
RegExp.quote   = require 'regexp-quote'

###* The base class is reserved for transparent caching in the future ###
class Base extends EventEmitter
  @DEFAULT_NAMESPACE: 'sidecar'

  constructor: (namespace = Base.DEFAULT_NAMESPACE) ->
    @setPeerNamespace namespace

  setPeerNamespace: (@namespace) -> @

###* Initialise a Redis backed registry ###
class Redis extends Base
  ###* Connect to a Redis server on the specified host/port ###
  constructor: (port, host, namespace, @client) ->
    super(namespace)

    @client  ?= redis.createClient(port, host, detect_buffers: yes)
    @pubsub  ?= redis.createClient(port, host)

    @channels = {}
    @pubsub.subscribe @channels.joins = "#{@namespace}#joins"
    @pubsub.subscribe @channels.parts = "#{@namespace}#parts"
    @pubsub.on 'message', @_consumeMessage.bind(@)

  ###* It's only sensible to ensure there's a colon on the end of Redis key prefixes ###
  setPeerNamespace: (namespace) ->
    namespace = "#{namespace}:" if namespace.lastIndexOf(':') isnt namespace.length - 1
    super namespace

  ###* Publish a client with the specified identifier to the registry ###
  publish: (identifier, options={}, callback) ->
    [callback, options] = [options, {}] if typeof options is 'function'

    key = @_getKeyForIdentifier(identifier)

    @client.exists key, (err, res) =>
      callback?(err) if err

      if parseInt(res)
        callback? null, @
      else
        @client.hmset key, identifier, (err, res) =>
          callback? err if err

          # we must use the regular client because apparently 'pub/sub mode' does not permit the publishing part
          @client.publish @channels.joins, JSON.stringify(identifier)
          callback? null, @

          if options and options.pexpire
            # expire the key in n ms
            @client.pexpire key, options.pexpire
    @

  ###* Find a host using the specified key pattern
       Redis will take a glob-like pattern and run it across the key set for us
       See http://redis.io/commands/keys
  ###
  lookup: (nicknamePattern, exclusions=[], callback) ->
    [callback, exclusions] = [exclusions, []] if typeof exclusions is 'function'

    @client.keys @_getKeyForIdentifier(nicknamePattern, yes), (err, keys) =>
      return callback?(err) if err
      keys.forEach (key) =>
        if not ~exclusions.indexOf key.substr(@namespace.length)
          @client.hgetall key, (err, obj) ->
            callback? err, obj
    @

  _consumeMessage: (channel, message) ->
    switch channel
      when @channels.joins
        @emit 'join', JSON.parse(message)
      when @channels.parts
        @emit 'part', JSON.parse(message)

  _getKeyForIdentifier: (identifier, escapePrefix = no) ->
    namespace = if escapePrefix then RegExp.quote(@namespace) else @namespace
    namespace + (identifier.name or identifier)

module.exports.BaseRegistry  = Base
module.exports.RedisRegistry = Redis
