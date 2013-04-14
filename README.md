sidecar (WIP) [![Build Status](https://travis-ci.org/notatestuser/sidecar.png?branch=master)](https://travis-ci.org/notatestuser/sidecar)
=============

Get [Duplex](http://nodejs.org/api/stream.html#stream_class_stream_duplex) streams to named peers in your network without having to worry
about DNS or hostname configuration. Uses [Redis](http://redis.io/) as a name server.

* Peers are apps that have arbitrary names
* The name server stores name to network address mappings
* Connection is transparent and happens upon demanding a stream
* A protocol is mutually agreed upon (currently TCP only), producing a [Duplex](http://nodejs.org/api/stream.html#stream_class_stream_duplex) stream
* Established stream is wrapped with desired indirection
* Events are emitted when servers join, leave, timeout or use a stream (optional)

The problem
-----------
I wanted to adopt [pillion](https://github.com/deoxxa/pillion) into my application
to get streaming RPC calls between my clients, but didn't have an effective way to
connect them without having to store protocol addresses (IPs).
If your network is anything like mine, you'll be using DHCP to assign
addresses, so having to constantly update a list of assignments
isn't really practical.

While I'm aware that MQ and multicast groups can be used in place of TCP streams to
refer to hosts by something other than an arbitrarily changing IP, the complexity of
those technologies can be burdensome to someone who isn't looking to accomodate massive
amounts of throughput or orchestrate bazillions of clients.

Moreover, I wanted something that would keep my state in a central location for monitoring.

The solution
------------
[KISS](https://en.wikipedia.org/wiki/KISS_principle)!

![Diagram](http://notatestuser.github.io/sidecar/diagram.svg)

*For ease of understanding, this diagram depicts two sidecar clients on the network.
It can support more.*

### But what if I don't want to use Redis or TCP?

Okay, the diagram can be a little deceiving, but you can really use anything you'd like.
This thing has been designed so that those interfaces are merely *defaults*; supplying your
own implementation is as easy as sending in another registry, interface or wrapper chain.

Let's see how easy it is to get RPC with a peer identity registry in about 5 seconds using
a Redis server running on the local machine:

```js
var sidecar = require('sidecar'),
    pillion = require('pillion'),
    burro   = require('burro');

var rpc = new sidecar('my-server-app');

rpc.addStreamWrapper(function(_socket) {
  return burro.wrap(_socket);
});

rpc.addStreamWrapper(function(_socket) {
  // you could even use pillion's second constructor argument to expose methods on all streams
  return new pillion(_socket);
});

rpc.to('*').provide("greet", function(name, cb) {
  cb("hi there, " + name);
});
```

Now let's say you'd instead like to use a SQL server as your registry:

```js
var sidecar = require('sidecar'),
    ...;

// obviously you'd have to implement this class, but there's already a base
// that does some basic caching and what-not that you can extend from.
var SQLRegistry = require('./registries/mysql');

var rpc = new sidecar('my-server-app', new SQLRegistry());

rpc.addStreamWrapper ... etc
```

And that's not all! You could really go hog wild with replacing the third *interface* argument to use a different network protocol between peers. *BaseInterface* may be extended
from to do just that.

### Great, but I don't like RPC

We can cater for your needs. Stream wrappers merely serve to take in
a stream (initially a socket client) and output another duplex stream. You could do plenty
of things instead like transformations, parsing, simulated latency, etc.

The future
------------
Please feel free to contribute to any extent.

* Support for Redis servers that require authentication
* Persistence of provided methods
* Pillion extensions for referencing method objects by URI (with peer nick pattern support)
      namespace://peer/method
      namespace://peer?/method
      namespace://*/method
* Pillion extensions for method/service discovery
* Proxied objects

The MIT License (MIT)
---------------------
Copyright © 2013 Luke T. Plaster, [lukep.org](http://lukep.org/)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
