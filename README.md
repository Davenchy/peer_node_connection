# PeerNodeConnection

Simple package to define peer to peer communication

for more examples visit the example section

## Simple Node Example

```dart
final node = Node();

  node.on(
    start: () {
      print('node started on port ${node.port}');
      Timer(const Duration(seconds: 3), () {
        node.stop();
      });
    },
    stop: () => print('node stopped!'),
  );

  node.start();
  await node.onNextEmit<NodeOnStopEvent>();
  print('bye bye!');

```

## Simple Peer Example

```dart
// connect to localhost on port 3000
final peer = Peer.local(3000);

// handle general events
peer.on(
  connect: () {
    print('connected');
    peer.sendText('hello world!');
    Timer(const Duration(seconds: 3), () {
        peer.destroy();
    });
  },
  disconnect: () {
    print('disconnected');
  }
);

peer.connect(); // start peer connection

await peer.onNextEmit<PeerOnDisconnectEvent>();
print('bye bye!');

```
