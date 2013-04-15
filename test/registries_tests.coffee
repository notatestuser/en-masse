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
  identifier1: makeIdentifier('peer-1')
  identifier2: makeIdentifier('peer-2')
  quad1:       makeIdentifier('quad-1')
  quad2:       makeIdentifier('quad-2')
  quad3:       makeIdentifier('quad-3')
  quad4:       makeIdentifier('quad-4')

### Tests ###

vows
  .describe('Registry')
  .addBatch(

    "a single RedisRegistry":
      topic: ->
        namespace = "test-lone-#{new Date().getTime()}"
        new RedisRegistry(null, null, namespace, ignoreProcessExit: yes)

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

        "and the server can be found through a call to each()":
          topic: (res, registry) ->
            registry.each 'peer-?', @callback
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
            registries[0].lookup 'quad*', [mocks.quad1.name, mocks.quad4.name], @callback
            return

          "returning quad-2 and quad-3's identifiers": (identifiers) ->
            assert.equal identifiers.length, 2, "contains 2 identifiers"
            assert.deepEqual identifiers, [mocks.quad2, mocks.quad3] if identifiers[0].name is 'quad-2'
            assert.deepEqual identifiers, [mocks.quad3, mocks.quad2] if identifiers[0].name is 'quad-3'

        "and an each() performed with a pattern and exclusions":
          topic: (registries) ->
            registries[0].each 'quad*', [mocks.quad1.name, mocks.quad2.name, mocks.quad4.name], @callback
            return

          "invokes callback with quad-3's identifier": (identifier) ->
            assert.deepEqual identifier, mocks.quad3

        "there should be keys in the published hash for each identifier":
          topic: (registries) ->
            ns   = registries[0].namespace
            keys = Object.keys published = registries[0].published
            for idx in [1..4]
              identifier = mocks["quad#{idx}"]
              assert.ok (key = ns + identifier.name) in keys
              assert.equal published[key], identifier
            registries[0].unpublish mocks.quad4.name, @callback
            return

          "and when a peer is unpublished":
            "the key should no longer be present in the published hash": (registry) ->
              ns = registry.namespace
              assert.ok not registry.published[ns + mocks.quad4]?

            "and an attempt to look it up":
              topic: (registry) ->
                registry.lookup mocks.quad4.name, @callback
                return

              "should return nothing": (names) ->
                assert.deepEqual names, []

    "multiple RedisRegistries":
      topic: ->
        namespace = "test-duo-#{new Date().getTime()}"
        [ new RedisRegistry(null, null, namespace, ignoreProcessExit: yes),
          new RedisRegistry(null, null, namespace, ignoreProcessExit: yes) ]

      "when publish() is called on the second client":
        topic: (registries) ->
          registries[0].on 'join', (_identifier) =>
            @callback null, _identifier, registries
          registries[1].publish mocks.identifier2, pexpire: 1000
          return # wait for async c/b

        "the first client receives a 'join' event with a valid identifier": (identifier) ->
          assert.deepEqual identifier, mocks.identifier2

        "and a each() is performed with a pattern and no exclusions":
          topic: (identifier, registries) ->
            registries[0].each 'peer-?', @callback
            return

          "then the other client's identifier should have been received": (identifier) ->
            assert.deepEqual identifier, mocks.identifier2


  ).export(module)
