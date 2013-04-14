redis          = require 'redis'
{map}          = require 'async'
{EventEmitter} = require 'events'
RegExp.quote   = require 'regexp-quote'

###* The base class is reserved for transparent caching in the future ###
class Base extends EventEmitter
  @DEFAULT_NAMESPACE: 'default-ns'

  constructor: (namespace = Base.DEFAULT_NAMESPACE, options={}) ->
    # we shouldn't be publishing many peers from one app, so let's just use a dumb object
    @published = {}
    @setPeerNamespace namespace

    # when the process exits we should unpublish everything we've published
    if not options.ignoreProcessExit
      process.on 'exit', => @unpublishAll()

  setPeerNamespace: (@namespace) -> @

  unpublishAll: ->
    @unpublish(_key) for _key, _identifier of published

  unpublish: (key) ->
    @published[key] = null

  publish: -> throw 'Not implemented in this base class'
  lookup:  -> throw 'Not implemented in this base class'
  each:    -> throw 'Not implemented in this base class'

  _getKeyForIdentifier: (identifier, escapePrefix = no) ->
    namespace = if escapePrefix then RegExp.quote(@namespace) else @namespace
    namespace + (identifier.name or identifier)

  _cacheAsPublished: (key, identifier={}) ->
    @published[key] = identifier if key

  _isCachedAsPublished: (key) ->
    @published[key]?

###* Initialise a Redis backed registry ###
class Redis extends Base
  ###* Connect to a Redis server on the specified host/port ###
  constructor: (port, host, namespace, options) ->
    super(namespace, options)

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
    return callback?(null, @) if @_isCachedAsPublished key

    @client.exists key, (err, res) =>
      callback?(err) if err

      if parseInt(res)
        callback? null, @
      else
        @client.hmset key, identifier, (err, res) =>
          callback? err if err

          # we must use the regular client because apparently 'pub/sub mode' does not permit the publishing part
          @_cacheAsPublished key, identifier
          @client.publish @channels.joins, JSON.stringify(identifier)
          callback? null, @

          if options and options.pexpire
            # expire the key in n ms
            @client.pexpire key, options.pexpire
    @

  ###* Unpublish a client ###
  unpublish: (key, callback) ->
    key = "#{@namespace}#{key}" if key.indexOf(@namespace) isnt 0

    @client.del key, =>
      callback? null, @
    @client.publish @channels.parts, JSON.stringify(@published[key])

    # set the reference in @published to null
    super key

  ###* Find hosts using the specified key pattern
       Redis will take a glob-like pattern and run it across the key set for us
       See http://redis.io/commands/keys
  ###
  lookup: (pattern, exclusions=[], callback) ->
    [callback, exclusions] = [exclusions, []] if typeof exclusions is 'function'

    @client.keys @_getKeyForIdentifier(pattern, yes), (err, keys) =>
      return callback?(err) if err
      keys = keys.filter (key) =>
        not ~exclusions.indexOf key.substr(@namespace.length)
      map keys, @client.hgetall.bind(@client), callback
    @

  ###* Invoke a callback on each identifier found through a lookup() ###
  each: (pattern, exclusions, callback) ->
    [callback, exclusions] = [exclusions, []] if typeof exclusions is 'function'

    @lookup pattern, exclusions, (err, identifiers) ->
      return callback?(err) if err
      identifiers.forEach (_identifier) ->
        callback? null, _identifier

  _consumeMessage: (channel, message) ->
    switch channel
      when @channels.joins
        @emit 'join', JSON.parse(message)
      when @channels.parts
        @emit 'part', JSON.parse(message)


module.exports.BaseRegistry  = Base
module.exports.RedisRegistry = Redis
