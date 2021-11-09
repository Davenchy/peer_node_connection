import 'dart:typed_data';

import 'package:typed_messages/typed_messages.dart';

import '../peer.dart';

abstract class NodeEvent {
  const NodeEvent();

  const factory NodeEvent.onStart() = NodeOnStartEvent;
  const factory NodeEvent.onStop() = NodeOnStopEvent;
  const factory NodeEvent.onPeerConnect(Peer peer) = NodeOnPeerConnectEvent;
  const factory NodeEvent.onPeerDisconnect(
    Peer peer,
  ) = NodeOnPeerDisconnectEvent;
  const factory NodeEvent.onData(Uint8List data, Peer peer) = NodeOnDataEvent;
  const factory NodeEvent.onMessage(
    Message message,
    Peer peer,
  ) = NodeOnMessageEvent;
  const factory NodeEvent.onSendData(Uint8List data) = NodeOnSendDataEvent;
  const factory NodeEvent.onSendMessage(
    Message message,
  ) = NodeOnSendMessageEvent;
  const factory NodeEvent.onError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) = NodeOnErrorEvent;
}

class NodeOnStartEvent extends NodeEvent {
  const NodeOnStartEvent();
}

class NodeOnStopEvent extends NodeEvent {
  const NodeOnStopEvent();
}

class NodeOnPeerConnectEvent extends NodeEvent {
  const NodeOnPeerConnectEvent(this.peer);
  final Peer peer;
}

class NodeOnPeerDisconnectEvent extends NodeEvent {
  const NodeOnPeerDisconnectEvent(this.peer);
  final Peer peer;
}

class NodeOnDataEvent extends NodeEvent {
  const NodeOnDataEvent(this.data, this.peer);
  final Uint8List data;
  final Peer peer;
}

class NodeOnMessageEvent<T extends Message> extends NodeEvent {
  const NodeOnMessageEvent(this.message, this.peer);
  final T message;
  final Peer peer;
}

class NodeOnSendDataEvent extends NodeEvent {
  const NodeOnSendDataEvent(this.data);
  final Uint8List data;
}

class NodeOnSendMessageEvent<T extends Message> extends NodeEvent {
  const NodeOnSendMessageEvent(this.message);
  final T message;
}

class NodeOnErrorEvent extends NodeEvent {
  const NodeOnErrorEvent(this.message, this.error, this.stackTrace);
  final String message;
  final Object error;
  final StackTrace stackTrace;
}
