import 'dart:convert';

class ControlMessage {
  const ControlMessage({
    required this.type,
    required this.messageId,
    required this.from,
    required this.timestampMs,
    this.target = 'all',
    this.to,
    this.command,
    this.deviceName,
    this.ip,
    this.model,
    this.slot,
    this.traceId,
    this.sessionId,
    this.payload,
    this.status,
  });

  final String type;
  final String messageId;
  final String from;
  final String target;
  final String? to;
  final String? command;
  final String? deviceName;
  final String? ip;
  final String? model;
  final int? slot;
  final String? traceId;
  final String? sessionId;
  final Map<String, dynamic>? payload;
  final String? status;
  final int timestampMs;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type,
      'msgId': messageId,
      'from': from,
      'target': target,
      'to': to,
      'cmd': command,
      'deviceName': deviceName,
      'ip': ip,
      'model': model,
      'slot': slot,
      'traceId': traceId,
      'sessionId': sessionId,
      'payload': payload,
      'status': status,
      'ts': timestampMs,
    }..removeWhere((_, value) => value == null);
  }

  String toJson() => jsonEncode(toMap());

  static ControlMessage? tryParse(String source) {
    try {
      final dynamic decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return ControlMessage(
        type: (decoded['type'] ?? '').toString(),
        messageId: (decoded['msgId'] ?? '').toString(),
        from: (decoded['from'] ?? '').toString(),
        target: (decoded['target'] ?? 'all').toString(),
        to: decoded['to']?.toString(),
        command: decoded['cmd']?.toString(),
        deviceName: decoded['deviceName']?.toString(),
        ip: decoded['ip']?.toString(),
        model: decoded['model']?.toString(),
        slot: int.tryParse((decoded['slot'] ?? '').toString()),
        traceId: decoded['traceId']?.toString(),
        sessionId: decoded['sessionId']?.toString(),
        payload: decoded['payload'] is Map<String, dynamic>
            ? decoded['payload'] as Map<String, dynamic>
            : null,
        status: decoded['status']?.toString(),
        timestampMs: int.tryParse((decoded['ts'] ?? 0).toString()) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
