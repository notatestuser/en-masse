en-masse (WIP) [![Build Status](https://travis-ci.org/notatestuser/en-masse.png?branch=master)](https://travis-ci.org/notatestuser/en-masse)
==============

Get [Duplex](http://nodejs.org/api/stream.html#stream_class_stream_duplex) streams to named peers in your network without having to worry
about DNS or hostname configuration. Uses [Redis](http://redis.io/) as a name server.

* Peers are apps that have arbitrary names
* Peers belong to a namespace
* The name server stores peer name to address/port/protocol mappings
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

![Diagram](http://notatestuser.github.io/en-masse/diagram.svg)

*For ease of understanding, this diagram depicts two en-masse clients on the network.
It can support more.*

Let's see how easy might be to get RPC with peer name matching using a Redis instance
on the local machine:

```js
var masse   = require('en-masse'),
    pillion = require('pillion'),
    burro   = require('burro');

var rpc = new masse('my-server-app');

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

### But what if I don't want to use Redis or TCP?

Okay, the diagram can be a little deceiving, but you can really use anything you'd like.
This thing has been designed so that those interfaces are merely *defaults*; supplying your
own implementation is as easy as sending in another registry, interface or wrapper chain.

Now let's say you'd instead like to use a SQL server as your registry:

```js
var masse = require('en-masse'),
    ...;

// obviously you'd have to implement this class, but there's already a base
// that does some basic caching and what-not that you can extend from.
var SQLRegistry = require('./registries/mysql');

var rpc = new masse('my-server-app', new SQLRegistry());

rpc.addStreamWrapper ... etc
```

And that's not all! You could really go hog wild with replacing the third *interface* argument to use a different network protocol between peers. *BaseInterface* may be extended
from to do just that.

### Great, but I don't like RPC

We can cater for your needs. Stream wrappers merely serve to take in
a stream (initially a socket client) and output another duplex stream. You could do plenty
of things instead like transformations, parsing, simulated latency, etc.

Neat uses
---------
Have you been using configuration files to target your application at a set of services that
varies depending upon which environment it's running in? Try this!

```js
var masse = require('en-masse'),
    ...;

var net = new masse('my-server-app');
net.setPeerNamespace(process.env.NODE_ENV || 'dev');

net.to('db-server-1') // ...use your stream...
```

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
* Support for invocation of local methods (we currently exclude the local host from lists of destination peers)
* Debug mode and logging

The MIT License (MIT)
---------------------
Copyright © 2013 Luke T. Plaster, [lukep.org](http://lukep.org/)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
