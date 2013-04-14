vows    = require 'vows'
assert  = require 'assert'

{getByProtoName, TcpInterface} = require '../src/interfaces'

### Tests ###

vows
  .describe('Interface')
  .addBatch(

    "TcpInterface":
      topic: ->
        new TcpInterface null, '127.0.0.1'

      "generates a host identifier object":
        topic: (iface) ->
          iface.getHostIdentifier 'peer', @callback
          return

        "and it is in a format that we expect": (err, identifier) ->
          assert.deepEqual identifier,
            name:  'peer',
            host:  '127.0.0.1',
            port:   3000,
            proto: 'tcp'

    "getByProtoName":
      topic: ->
        getByProtoName

      "returns the TcpInterface when 'tcp' is requested": (fn) ->
        assert.equal getByProtoName('tcp'), TcpInterface, 'should return TcpInterface'

  ).export(module)
