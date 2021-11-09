import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:typed_event_emitter/typed_event_emitter.dart';
import 'package:typed_messages/typed_messages.dart';

import 'events/node_event.dart';
import 'peer.dart';

class Node extends TypedEventEmitter<NodeEvent> {
  Node();

  ServerSocket? _socket;
  final Set<Peer> _bindingPeers = {};
  final Set<Peer> _peers = {};

  /// socket object of the node
  ///
  /// check `isAlive` before use
  ServerSocket get socket => _socket!;

  /// list of binding peers in the node
  ///
  /// binding peers are peers that node tries to connect and add them to the pool
  /// node is waiting for their success or failure
  List<Peer> get bindingPeers => List.unmodifiable(_bindingPeers);

  /// list of successfully connected peers in the node
  List<Peer> get peers => List.unmodifiable(_peers);

  /// check the state of node is alive or note
  bool get isAlive => _socket != null;

  /// current node binding address, check `isAlive` before use
  InternetAddress get address => socket.address;

  /// current node binding ip address, check `isAlive` before use
  String get ip => address.address;

  /// current socket binding port, check `isAlive` before use
  int get port => socket.port;

  /// start the node and listen to incoming connections
  ///
  /// start the node on binding `address` and `port`
  /// `port` by default is `0` which means the system will choose a random port
  /// to handle events you can use `handle<EventType>` or directly from `on`
  /// to handle errors use `on(error: () {...})`
  Future<void> start({InternetAddress? address, int port = 0}) {
    if (isAlive) return Future.value();
    return ServerSocket.bind(address ?? InternetAddress.anyIPv4, port)
        .then((socket) {
      _socket = socket;
      late final StreamSubscription sub;
      sub = socket.listen(
        _onPeer,
        onError: (err, stk) => emit(
          NodeEvent.onError('Something wrong happened', err, stk),
        ),
        onDone: () {
          sub.cancel();
          disconnectPeers().then((_) => emit(const NodeEvent.onStop()));
        },
      );
      emit(const NodeEvent.onStart());
    }).catchError((error, stackTrace) {
      emit(NodeEvent.onError('Failed to start node', error, stackTrace));
    });
  }

  /// disconnect all successfully connected peers then clear them from memory
  Future<void> disconnectPeers() async {
    if (_peers.isNotEmpty) {
      for (var peer in _peers) {
        await peer.destroy();
      }
      _peers.clear();
    }
  }

  /// stop current node server but keeps all event handlers
  ///
  /// also disconnect all successfully connected peers and remove them from memory
  Future<void> stop() => _socket?.close() ?? Future(() => null);

  /// add `peer` to the pool of binding peers
  ///
  /// if `preConnected` is `true` then the node will move the peer into the peers pool
  /// after handling its events
  /// duplicated peers will be ignored
  void addPeer(Peer peer, {bool preConnected = false}) {
    // check if peer is unique and node is active
    if (_bindingPeers.contains(peer) || _peers.contains(peer) || !isAlive) {
      return;
    }

    _bindingPeers.add(peer);

    onPeerConnectHandler() {
      _bindingPeers.remove(peer);
      if (!isAlive) {
        peer.destroy();
      } else {
        _peers.add(peer);
        emit(NodeEvent.onPeerConnect(peer));
      }
    }

    // handle peer
    peer.on(
      connect: onPeerConnectHandler,
      disconnect: () {
        _peers.remove(peer);
        emit(NodeEvent.onPeerDisconnect(peer));
      },
      data: (data) => emit(NodeEvent.onData(data, peer)),
      message: (msg) => emit(NodeEvent.onMessage(msg, peer)),
      error: (msg, err, stk) => emit(NodeEvent.onError(msg, err, stk)),
    );

    if (preConnected) {
      onPeerConnectHandler();
    } else {
      peer.connect();
    }
  }

  void _onPeer(Socket socket) {
    final peer = Peer.fromSocket(socket);
    addPeer(peer, preConnected: true);
  }

  /// handle specific message type `T`
  ///
  /// the same as `on(message: ...)` but while check if the message type is `T`
  /// before calling the `handler`
  void onMessage<T extends Message>(
    void Function(T message, Peer peer) handler,
  ) =>
      on(
        message: (msg, peer) {
          if (msg is T) {
            handler(msg, peer);
          }
        },
      );

  /// handle all the events that the node can emit
  void on({
    void Function()? start,
    void Function()? stop,
    void Function(Peer peer)? peerConnect,
    void Function(Peer peer)? peerDisconnect,
    void Function(Uint8List data, Peer peer)? data,
    void Function(Message message, Peer peer)? message,
    void Function(Uint8List data)? sendData,
    void Function(Message message)? sendMessage,
    void Function(String message, Object error, StackTrace stackTrace)? error,
  }) {
    if (start != null) {
      handle<NodeOnStartEvent>((event) => start());
    }
    if (stop != null) {
      handle<NodeOnStopEvent>((event) => stop());
    }
    if (peerConnect != null) {
      handle<NodeOnPeerConnectEvent>((event) => peerConnect(event.peer));
    }
    if (peerDisconnect != null) {
      handle<NodeOnPeerDisconnectEvent>((event) => peerDisconnect(event.peer));
    }
    if (data != null) {
      handle<NodeOnDataEvent>((event) => data(event.data, event.peer));
    }
    if (message != null) {
      handle<NodeOnMessageEvent>((event) => message(event.message, event.peer));
    }
    if (sendData != null) {
      handle<NodeOnSendDataEvent>((event) => sendData(event.data));
    }
    if (sendMessage != null) {
      handle<NodeOnSendMessageEvent>((event) => sendMessage(event.message));
    }
    if (error != null) {
      handle<NodeOnErrorEvent>(
        (event) => error(event.message, event.error, event.stackTrace),
      );
    }
  }

  /// send `bytes` to all peers in the pool and returns true if succeeded
  bool send(Uint8List data) {
    if (!isAlive) return false;
    if (_peers.isEmpty) return true;
    for (var peer in _peers) {
      peer.send(data);
    }
    emit(NodeEvent.onSendData(data));
    return true;
  }

  /// send list of `bytes` to all peers in the pool and returns true if succeeded
  bool sendBytes(List<int> bytes) => send(Uint8List.fromList(bytes));

  /// send `text` to all peers in the pool and returns true if
  bool sendText(String text) => sendBytes(text.codeUnits);

  /// send `message` to all peers in the pool and returns true if succeeded
  bool sendMessage(Message message) {
    if (!send(Message.encode(message))) return false;
    emit(NodeEvent.onSendMessage(message));
    return true;
  }

  /// destroy node server
  ///
  /// stop the server and clear all peers in the pool
  /// the close all event handlers
  /// then clean the memory
  @override
  Future<void> destroy() async {
    await stop();
    super.destroy();
  }

  @override
  bool operator ==(Object other) =>
      other is Node &&
      (identical(other, this) ||
          (isAlive ? (other.address == address && other.port == port) : true));

  @override
  int get hashCode =>
      super.hashCode ^ (isAlive ? address.hashCode ^ port.hashCode : 0);
}
