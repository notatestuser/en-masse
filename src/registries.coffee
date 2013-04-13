redis        = require 'redis'
RegExp.quote = require 'regexp-quote'

###* The base class is reserved for transparent caching in the future ###
class Base
  constructor: ->

class Redis extends Base
  @DEFAULT_KEY_PREFIX: 'en-masse:'

  ###* Initialise a Redis backed registry on the specified host/port ###
  constructor: (port, host, @keyPrefix = Redis.DEFAULT_KEY_PREFIX, @client) ->
    super()
    @client ?= redis.createClient(port, host, detect_buffers: yes)

  ###* Publish a client with the specified identifier to the registry ###
  publish: (identifier, options={}, callback) ->
    [callback, options] = [options, {}] if typeof options is 'function'

    # TODO: write to cache, publish event
    @client.HMSET key = @_getKeyForIdentifier(identifier), identifier, callback

    if options and options.pexpire
      # expire the key in n ms
      @client.pexpire key, options.pexpire

  ###* Find a host using the specified key pattern
       Redis will take a regex pattern and run it across the key set for us
       See http://redis.io/commands/keys
  ###
  lookup: (nicknamePattern, callback) ->
    @client.KEYS @_getKeyForIdentifier(nicknamePattern, yes), (err, keys) =>
      return callback?(err) if err
      keys.forEach (key) =>
        @client.HGETALL key, (err, obj) ->
          callback? err, obj

  _getKeyForIdentifier: (identifier, escapePrefix = no) ->
    keyPrefix = if escapePrefix then RegExp.quote(@keyPrefix) else @keyPrefix
    keyPrefix + (identifier.name or identifier)

module.exports.BaseRegistry  = Base
module.exports.RedisRegistry = Redis
