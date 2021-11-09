import 'dart:typed_data';

import 'package:typed_messages/typed_messages.dart';

abstract class PeerEvent {
  const PeerEvent();

  const factory PeerEvent.onConnect() = PeerOnConnectEvent;
  const factory PeerEvent.onDisconnect() = PeerOnDisconnectEvent;
  const factory PeerEvent.onData(Uint8List data) = PeerOnDataEvent;
  const factory PeerEvent.onMessage(Message message) = PeerOnMessageEvent;
  const factory PeerEvent.onSendData(Uint8List data) = PeerOnSendDataEvent;
  const factory PeerEvent.onSendMessage(
    Message message,
  ) = PeerOnSendMessageEvent;
  const factory PeerEvent.onError(
    String message,
    Object error,
    StackTrace stackTrace,
  ) = PeerOnErrorEvent;
}

class PeerOnConnectEvent extends PeerEvent {
  const PeerOnConnectEvent();
}

class PeerOnDisconnectEvent extends PeerEvent {
  const PeerOnDisconnectEvent();
}

class PeerOnDataEvent extends PeerEvent {
  const PeerOnDataEvent(this.data);
  final Uint8List data;
}

class PeerOnMessageEvent<T extends Message> extends PeerEvent {
  const PeerOnMessageEvent(this.message);
  final T message;
}

class PeerOnSendDataEvent extends PeerEvent {
  const PeerOnSendDataEvent(this.data);
  final Uint8List data;
}

class PeerOnSendMessageEvent<T extends Message> extends PeerEvent {
  const PeerOnSendMessageEvent(this.message);
  final T message;
}

class PeerOnErrorEvent extends PeerEvent {
  const PeerOnErrorEvent(this.message, this.error, this.stackTrace);
  final String message;
  final Object error;
  final StackTrace stackTrace;
}
