import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:typed_event_emitter/typed_event_emitter.dart';
import 'package:typed_messages/typed_messages.dart';

import 'events/peer_event.dart';

class Peer extends TypedEventEmitter<PeerEvent> {
  Peer(this.address, this.port);
  Peer.fromSocket(Socket socket)
      : _socket = socket,
        address = socket.remoteAddress,
        port = socket.remotePort {
    _handleSocket();
  }

  /// connect to a local node using the `port` only
  Peer.local(this.port) : address = InternetAddress.loopbackIPv4;

  /// connect to a node by its `ip` address and `port`
  factory Peer.byIp(String ip, int port) {
    final address = InternetAddress.tryParse(ip);
    if (address == null) throw Exception("Invalid IP address");
    return Peer(address, port);
  }

  Socket? _socket;

  /// peer's address
  final InternetAddress address;

  /// peer's port
  final int port;

  /// the peer's socket, check `isConnected` to see if peer is connected
  Socket get socket => _socket!;

  /// check if peer is connected
  bool get isConnected => _socket != null;

  /// peer's ip address
  String get ip => address.address;

  /// start connection to the peer and handle events
  Future<void> connect() async {
    if (isConnected) return;
    return Socket.connect(address, port).then((socket) {
      _socket = socket;
      _handleSocket();
      emit(const PeerEvent.onConnect());
    }).catchError((error, stackTrace) {
      emit(
        PeerEvent.onError(
          'Failed to connect ${address.address}:$port',
          error,
          stackTrace,
        ),
      );
    });
  }

  void _handleSocket() {
    if (_socket == null) return;
    late final StreamSubscription sub;
    sub = _socket!.listen(
      _onData,
      onError: _onError,
      onDone: () async {
        emit(const PeerEvent.onDisconnect());
        await _socket?.flush();
        _socket?.close();
        _socket = null;
        await sub.cancel();
      },
    );
  }

  void _onData(Uint8List data) {
    emit(PeerEvent.onData(data));
    final message = Message.decode(data);
    if (message != null) emit(PeerEvent.onMessage(message));
  }

  void _onError(Object error, StackTrace stackTrace) {
    emit(PeerEvent.onError('Something wrong happened', error, stackTrace));
  }

  /// handle messages with specific type `T`
  ///
  /// the same as `on(message: ...)` but checks the type `T` of the message
  /// before calling `handler`
  void onMessage<T extends Message>(
    void Function(T message) handler,
  ) =>
      on(message: (msg) {
        if (msg is T) {
          handler(msg);
        }
      });

  /// send `data` to the peer and returns true if succeeded
  bool send(Uint8List data) {
    if (!isConnected) {
      emit(
        PeerEvent.onError(
          'Can not send data, Socket is closed!',
          Exception('Cannot send data, Socket is closed!'),
          StackTrace.current,
        ),
      );
      return false;
    } else {
      socket.add(data);
      emit(PeerEvent.onSendData(data));
      return true;
    }
  }

  /// send `bytes` to the peer and returns true if succeeded
  bool sendBytes(List<int> bytes) => send(Uint8List.fromList(bytes));

  /// send `text` to the peer and returns true if succeeded
  bool sendText(String text) => sendBytes(text.codeUnits);

  /// send `message` to the peer and returns true if succeeded
  bool sendMessage(Message message) {
    if (send(Message.encode(message))) return false;
    emit(PeerEvent.onSendMessage(message));
    return true;
  }

  /// handle all events emitted by the peer
  void on({
    void Function()? connect,
    void Function()? disconnect,
    void Function(Uint8List data)? data,
    void Function(Message message)? message,
    void Function(Uint8List data)? sendData,
    void Function(Message message)? sendMessage,
    void Function(String message, Object error, StackTrace stackTrace)? error,
  }) {
    if (connect != null) {
      handle<PeerOnConnectEvent>((event) => connect());
    }
    if (disconnect != null) {
      handle<PeerOnDisconnectEvent>((event) => disconnect());
    }
    if (data != null) {
      handle<PeerOnDataEvent>((event) => data(event.data));
    }
    if (message != null) {
      handle<PeerOnMessageEvent>((event) => message(event.message));
    }
    if (sendData != null) {
      handle<PeerOnSendDataEvent>((event) => sendData(event.data));
    }
    if (sendMessage != null) {
      handle<PeerOnSendMessageEvent>((event) => sendMessage(event.message));
    }
    if (error != null) {
      handle<PeerOnErrorEvent>(
        (event) => error(
          event.message,
          event.error,
          event.stackTrace,
        ),
      );
    }
  }

  /// flush data, disconnect peer and close socket then clear memory
  ///
  /// you can reconnect again after disconnecting instead call `destroy`
  /// to full memory cleanup
  void disconnect() => _socket?.destroy();

  /// destroy the current peer connection
  ///
  /// calls `disconnect`
  /// then full memory cleanup
  ///
  /// you cannot reconnect after calling this method
  @override
  Future<void> destroy() async {
    disconnect();
    return super.destroy();
  }

  /// returns peer's info with `~` at the end if peer is connected as a __String__
  @override
  String toString() => 'Peer($ip:$port)${isConnected ? '~' : ''}';

  @override
  bool operator ==(Object other) {
    return other is Peer &&
        (identical(other, this) ||
            (address == other.address && port == other.port));
  }

  @override
  int get hashCode => super.hashCode ^ address.hashCode ^ port.hashCode;
}
