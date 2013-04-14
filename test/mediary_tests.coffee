vows    = require 'vows'
assert  = require 'assert'

Mediary = require '../src/mediary'

### Mocks ###

getMockedRegistry = ->
  return registry =
    published: {} # yep, it's a hash. - one-to-one mappings only
    publish: (identifier) ->
      registry.published[identifier.name or identifier] = identifier
    each: (nickname, exclusions, callback) ->
      # we don't have to handle patterns here - let's just do a direct match
      match = registry.published[nickname]
      return callback? null, match if match
      callback 'not found'
    on: ->

getMockedInterface = ->
  return iface =
    listen: ->
      iface.listening = yes
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

      "should listen on the interface": (mediary) ->
        assert not mediary.interface.listening, 'the interface should not be listening'
        mediary.to('absent-host')
        assert mediary.interface.listening, 'the interface should be listening'

      "should publish our app's identifier to the registry": (mediary) ->
        mediary.to('absent-host')
        assert mediary.registry.published.me?

      "should attempt to connect to the host we asked for": (mediary) ->
        mediary.registry.publish name: 'present-host'
        mediary.to 'present-host', (err, socket) ->
          # the fake socket consists of an object with the identifier within it
          assert.deepEqual socket, identifier: name: 'present-host'

  ).export(module)
