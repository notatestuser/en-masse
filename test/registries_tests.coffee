vows       = require 'vows'
assert     = require 'assert'
{parallel} = require 'async'

{RedisRegistry} = require '../src/registries'

### Mocks ###

makeIdentifier = (peerName) ->
  name: peerName
  host: 'localhost'
  post: 1337

mocks =
  identifier1: makeIdentifier 'peer-1'
  identifier2: makeIdentifier 'peer-2'
  quad1:       makeIdentifier 'quad-1'
  quad2:       makeIdentifier 'quad-2'
  quad3:       makeIdentifier 'quad-3'
  quad4:       makeIdentifier 'quad-4'

### Tests ###

vows
  .describe('Registry')
  .addBatch(

    "a single RedisRegistry":
      topic: ->
        namespace = "test-lone-#{new Date().getTime()}"
        new RedisRegistry(null, null, namespace)

      "has appended a colon to the end of the given namespace": (registry) ->
        namespace = registry.namespace
        assert.ok namespace.lastIndexOf(':') is namespace.length - 1

      "publishes an identifier":
        topic: (registry) ->
          registry.publish mocks.identifier1, pexpire: 1000, @callback
          return

        "and the data is retrieved by key":
          topic: (res, registry) ->
            registry.client.hgetall "#{registry.namespace}peer-1", @callback
            return

          "then the stored data is correct": (err, res) ->
            assert.ok not err
            assert.deepEqual res, mocks.identifier1

        "and the server can be found through a call to lookup()":
          topic: (res, registry) ->
            registry.lookup 'peer-?', @callback
            return

          "then our identifier is passed through to our callback": (err, res) ->
            assert.ok not err
            assert.deepEqual res, mocks.identifier1

      "publishes many identifiers":
        topic: (registry) ->
          parallel [
            registry.publish.bind registry, mocks.quad1, pexpire: 1000
            registry.publish.bind registry, mocks.quad2, pexpire: 1000
            registry.publish.bind registry, mocks.quad3, pexpire: 1000
            registry.publish.bind registry, mocks.quad4, pexpire: 1000
          ], @callback

        "and a lookup() is performed with a pattern and exclusions":
          topic: (registries) ->
            registries[0].lookup 'quad*', ['quad-1', 'quad-2', 'quad-4'], @callback
            return

          "then quad-3's identifier should have been received": (identifier) ->
            assert.deepEqual identifier, mocks.quad3

    "multiple RedisRegistries":
      topic: ->
        namespace = "test-duo-#{new Date().getTime()}"
        [ new RedisRegistry(null, null, namespace),
          new RedisRegistry(null, null, namespace) ]

      "when publish() is called on the second client":
        topic: (registries) ->
          registries[0].on 'join', (_identifier) =>
            @callback null, _identifier, registries
          registries[1].publish mocks.identifier2, pexpire: 1000
          return # wait for async c/b

        "the first client receives a 'join' event with a valid identifier": (identifier) ->
          assert.deepEqual identifier, mocks.identifier2

        "and a lookup() is performed with a pattern and no exclusions":
          topic: (identifier, registries) ->
            registries[0].lookup 'peer-?', @callback
            return

          "then the other client's identifier should have been received": (identifier) ->
            assert.deepEqual identifier, mocks.identifier2

  ).export(module)

