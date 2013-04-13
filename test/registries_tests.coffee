vows    = require 'vows'
assert  = require 'assert'

{RedisRegistry} = require('../lib/registries')

mocks = identifier:
  name: 'peer-1'
  host: 'localhost'
  port:  1337

### Tests ###

vows
  .describe('Registry')
  .addBatch(

    "RedisRegistry":
      topic: ->
        keyPrefix = "unit-test-#{new Date().getTime()}:"
        return new RedisRegistry(null, null, keyPrefix)

      "upon publishing data to the server":
        topic: (registry) ->
          registry.publish mocks.identifier,
            pexpire: 3000
          , @callback
          return # wait for async c/b

        "the data can be retrieved by key":
          topic: (res, registry) ->
            registry.client.HGETALL "#{registry.keyPrefix}peer-1", @callback
            return

          "and the stored data is correct": (err, res) ->
            assert.ok not err
            assert.deepEqual res, mocks.identifier

        "the server can be found through a call to lookup()":
          topic: (res, registry) ->
            registry.lookup 'peer-?', @callback
            return

          "and our identifier is passed through to our callback": (err, res) ->
            assert.ok not err
            assert.deepEqual res, mocks.identifier

  ).export(module)

