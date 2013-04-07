en-masse (WIP)
==============

Get full-duplex streams to named nodes in your network without having to worry
about DNS configuration or hostnames. Uses Redis to keep peer state by default.

The problem
-----------
I wanted to adopt [pillion](https://github.com/deoxxa/pillion) into my application
to get streaming RPC calls between my clients, but didn't have an effective way to
connect them without having to store protocol addresses (IPs).
If your network is anything like mine, you'll be using DHCP to give clients dynamic
addresses; so having to constantly update them or maintain a list of static assignments
isn't really practical.

While I'm aware that MQ and multicast groups can be used in place of TCP streams to
refer to hosts by something other than an arbitrarily changing IP, the complexity of
those technologies can be burdensome to someone who isn't looking to accomodate massive
amounts of throughput or orchestrate bazillions of clients.

Moreover, I wanted something that would keep my state in a central location for monitoring.

The solution
------------
[KISS](https://en.wikipedia.org/wiki/KISS_principle)!

![Diagram](http://notatestuser.github.io/node-masse/diagram.svg)

*For ease of understanding, this diagram depicts two en-masse clients on the network.
It can support more.*

### But what if I don't want to use Redis or TCP?

Okay, the diagram can be a little deceiving, but you can really use anything you'd like.
This thing has been designed so that those interfaces are merely *defaults*; supplying your
own implementation is as easy as sending in another registry, interface or wrapper chain.

Let's see how easy it is to get RPC with a peer identity registry in about 5 seconds using
a Redis server running on the local machine:

```js
var masse   = require('en-masse'),
    burro   = require('burro'),
    pillion = require('pillion');

var rpc = new masse('my-server-app');

rpc.addStreamWrapper(function(_socket) {
  return burro.wrap(_socket);
});

rpc.addStreamWrapper(function(_socket) {
  return new pillion(_socket);
});

rpc.to('*').provide("greet", function(name, cb) {
  cb("hi there, " + name);
});
```

Now let's say you'd instead like to use a SQL server as your registry (for some reason):

```js
var masse   = require('en-masse'),
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

That's pretty weird, but we cater for your needs. Stream wrappers merely serve to take in
a stream (initially a socket client) and output another duplex stream. You could do plenty
of things like transformations, parsing, simulated latency, etc.


More to come...
---------------
