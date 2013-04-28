vows    = require 'vows'
assert  = require 'assert'
{EventEmitter} = require 'events'

Mediary = require '../src/mediary'

### Mocks ###

getMockedRegistry = ->
  return new class extends EventEmitter
    published: {} # yep, it's a hash. - one-to-one mappings only
    publish: (identifier) ->
      @published[identifier.name or identifier] = identifier
      @
    each: (nickname, exclusions, callback) ->
      # we don't have to handle patterns here - let's just do a direct match
      match = @published[nickname]
      if match?
        return callback? null, match
      # callback new Error("peer matching '#{nickname}' not found")

getMockedInterface = ->
  return new class
    listen: ->
      @listening = yes
    connect: (identifier, callback) ->
      # return a fake socket
      callback? null, identifier: identifier
    getHostIdentifier: (nickname, callback) ->
      # return a fake identifier
      callback? null, name: nickname

### Tests ###

vows
  .describe('Mediary')
  .addBatch(

    "when given mocked dependencies":
      topic: ->
        registry  = getMockedRegistry()
        iface     = getMockedInterface()
        return new Mediary('me', registry, iface)

      "listens on the interface": (mediary) ->
        assert not mediary.interface.listening, 'the interface should not be listening'
        mediary.to 'absent-host'
        assert mediary.interface.listening, 'the interface should be listening'

      "publishes our app's identifier to the registry": (mediary) ->
        mediary.to 'absent-host'
        assert mediary.registry.published.me?

      "attempts to connect to the host we asked for":
        topic: (mediary) ->
          mediary.registry.publish name: 'present-host'
          mediary.to 'present-host', @callback
          return

        "and gives us a socket stream": (socket) ->
          # the mock socket consists of an object containing the identifier within it
          assert.deepEqual socket, identifier: name: 'present-host'

      "persists a stream actor between peer joins when we ask it to":
        topic: (mediary) ->
          mediary.to 'tardy-host', persist: yes, (err, identifier) =>
            @callback err, mediary, identifier
          console.log mediary.registry.published
          console.log mediary.persisted
          mediary.registry
            .publish(name: 'tardy-host')
            .emit('join', name: 'tardy-host')
          return

        "the persisted pair are in mediary.persisted": (mediary) ->
          assert.equal mediary.persisted.length, 1
          assert.equal mediary.persisted[0][0], 'tardy-host'
          assert.equal typeof mediary.persisted[0][1], 'function'

        "and the callback is invoked with our wrapped stream": (_err, _mediary, identifier) ->
          assert.deepEqual identifier, identifier: name: 'tardy-host'

  ).export(module)
