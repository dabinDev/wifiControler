import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/control_message.dart';

class UdpDatagramEvent {
  const UdpDatagramEvent({
    required this.message,
    required this.senderAddress,
    required this.senderPort,
  });

  final ControlMessage message;
  final String senderAddress;
  final int senderPort;
}

class UdpService {
  UdpService({required this.listenPort});

  final int listenPort;

  RawDatagramSocket? _socket;
  final StreamController<UdpDatagramEvent> _eventsController =
      StreamController<UdpDatagramEvent>.broadcast();

  Stream<UdpDatagramEvent> get events => _eventsController.stream;

  Future<void> startListening() async {
    if (_socket != null) {
      return;
    }
    final RawDatagramSocket socket =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort);
    socket.broadcastEnabled = true;
    _socket = socket;

    socket.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final Datagram? datagram = socket.receive();
      if (datagram == null) {
        return;
      }

      final String payload = utf8.decode(datagram.data, allowMalformed: true);
      final ControlMessage? message = ControlMessage.tryParse(payload);
      if (message == null || message.type.isEmpty || message.messageId.isEmpty) {
        return;
      }

      _eventsController.add(
        UdpDatagramEvent(
          message: message,
          senderAddress: datagram.address.address,
          senderPort: datagram.port,
        ),
      );
    });
  }

  void sendBroadcast({required String jsonPayload, int? port}) {
    final RawDatagramSocket? socket = _socket;
    if (socket == null) {
      return;
    }
    final List<int> bytes = utf8.encode(jsonPayload);
    socket.send(bytes, InternetAddress('255.255.255.255'), port ?? listenPort);
  }

  void sendUnicast({
    required String jsonPayload,
    required String ip,
    required int port,
  }) {
    final RawDatagramSocket? socket = _socket;
    if (socket == null) {
      return;
    }
    final List<int> bytes = utf8.encode(jsonPayload);
    socket.send(bytes, InternetAddress(ip), port);
  }

  Future<void> dispose() async {
    await _eventsController.close();
    _socket?.close();
    _socket = null;
  }
}
