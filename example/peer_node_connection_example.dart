import 'dart:async';
import 'dart:math' show Random;

import 'package:peer_node_connection/peer_node_connection.dart';
import 'package:typed_messages/typed_messages.dart';

import 'port_message.dart';

void log(
  String message, {
  String name = 'main',
  Object? error,
  StackTrace? stackTrace,
}) {
  print('[$name] $message');
  if (error != null) print(error);
  if (stackTrace != null) print(stackTrace);
}

Future<void> main() async {
  // use PortMessage prototype
  IMessagePrototype.definePrototype(const PortMessagePrototype());

  // create a new peer node
  final node = Node();

  // handle general events
  node.on(
    start: () => log('started on port ${node.port}', name: 'Node'),
    stop: () => log('stopped', name: 'Node'),
    peerConnect: (peer) => log('peer connected: $peer', name: 'Node'),
    peerDisconnect: (peer) => log('peer disconnected: $peer', name: 'Node'),
    error: (msg, err, stk) =>
        log(msg, error: err, stackTrace: stk, name: 'Node'),
  );

  node.on(
    // send port message to peer on connect
    peerConnect: (peer) {
      peer.sendMessage(PortMessage(Random().nextInt(29000) + 1000));
    },

    // stop node server if no more peers in the pool
    peerDisconnect: (peer) {
      if (node.peers.isEmpty) node.stop();
    },
  );

  // handle message of type PortMessage
  node.onMessage<PortMessage>((message, peer) {
    log('received peer port message: $message from $peer', name: 'Node');
  });

  // start node server
  await node.start(); // port default value is 0, which means use a random port

  createPeer(node.port); // create simple peer

  await node.onNextEmit<NodeOnStopEvent>(); // await for server to shutdown
  // await node.destroy(); // clean memory
  print('completed!');
}

void createPeer(int port) {
  // create peer and target localhost with the node server's random port
  final peer = Peer.local(port);

  // handle general events
  peer.on(
    connect: () => log('connected', name: peer.toString()),
    disconnect: () => log('disconnected', name: peer.toString()),
    error: (msg, err, stk) =>
        log(msg, error: err, stackTrace: stk, name: peer.toString()),
  );

  // on PortMessage message received send PortMessage with port 0 and destroy peer connection
  peer.onMessage<PortMessage>((message) {
    log('port message: $message.port from node', name: peer.toString());
    peer.sendMessage(PortMessage(0));
    Timer(
      const Duration(seconds: 2),
      () => peer.destroy(), // disconnect and full memory cleanup
    );
  });

  peer.connect(); // connect to node peer
}
