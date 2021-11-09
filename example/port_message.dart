import 'dart:typed_data';

import 'package:typed_messages/typed_messages.dart';

const int kPortMessageId = 0;

class PortMessage extends Message {
  const PortMessage(this.port);
  final int port;

  @override
  String toString() => 'PortMessage($port)';
}

class PortMessagePrototype implements IMessagePrototype<PortMessage> {
  const PortMessagePrototype();

  @override
  PortMessage decode(Uint8List bytes) {
    // read 2bytes at offset 1
    final int port = BytesReader(bytes).readUint(1, 2);
    return PortMessage(port);
  }

  @override
  Uint8List encode(PortMessage message) {
    final writer = BytesWriter(3);
    // write 1byte id at offset 0
    writer.writeSingleByte(kPortMessageId);
    // write 2bytes port at offset 1
    writer.writeUint(message.port, 2); // port is 2bytes length
    return writer.toBuffer();
  }

  @override
  bool validate(Uint8List bytes) {
    final reader = BytesReader(bytes);
    if (reader.length != 3) return false;
    return reader.readSingleByte(0) == kPortMessageId;
  }
}
