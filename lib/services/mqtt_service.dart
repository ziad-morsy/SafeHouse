import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

enum MqttCurrentConnectionState {
  IDLE,
  CONNECTING,
  CONNECTED,
  DISCONNECTED,
  ERROR_WHEN_CONNECTING,
}

class MQTTService {
  static const String broker =
      '195bdf59edc94f0f82ca8280f9aeea8c.s1.eu.hivemq.cloud';
  static const int port = 8883;
  static const String username = 'Morse';
  static const String password = 'Morsesama9';

  late MqttServerClient _client;
  final _connectionStatus =
      StreamController<MqttCurrentConnectionState>.broadcast();
  final _messageStream = StreamController<Map<String, dynamic>>.broadcast();

  Stream<MqttCurrentConnectionState> get connectionStream =>
      _connectionStatus.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageStream.stream;

  Future<void> connect() async {
    _client =
        MqttServerClient(
            broker,
            'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
          )
          ..port = port
          ..keepAlivePeriod = 20
          ..onDisconnected = _onDisconnected
          ..onConnected = _onConnected
          ..onSubscribed = _onSubscribed
          ..secure = true
          ..securityContext = SecurityContext.defaultContext;

    try {
      _connectionStatus.add(MqttCurrentConnectionState.CONNECTING);
      await _client.connect(username, password);
    } catch (e) {
      print('Exception: $e');
      _connectionStatus.add(MqttCurrentConnectionState.ERROR_WHEN_CONNECTING);
      _client.disconnect();
    }

    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _connectionStatus.add(MqttCurrentConnectionState.CONNECTED);
      _setupMessageListener();
    } else {
      _connectionStatus.add(MqttCurrentConnectionState.ERROR_WHEN_CONNECTING);
      _client.disconnect();
    }
  }

  void subscribe(String topic) {
    print('\n=== Subscribing to topic: $topic ===');
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      print('Client is connected, subscribing...');
      _client.subscribe(topic, MqttQos.atLeastOnce);
      print('Subscription request sent for: $topic');
    } else {
      print(
        'Cannot subscribe, client connection state: ${_client.connectionStatus?.state}',
      );
    }
    print('\n');
  }

  void publish(String topic, Map<String, dynamic> message) {
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(message));
      _client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
    }
  }

  void disconnect() {
    _client.disconnect();
    _connectionStatus.close();
    _messageStream.close();
  }

  void _setupMessageListener() {
    _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      print('\n=== MQTT Message Received ===');
      print('Topic: ${messages[0].topic}');

      final recMess = messages[0].payload as MqttPublishMessage;
      final messageStr = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      print('Raw message: $messageStr');

      try {
        final messageJson = jsonDecode(messageStr);
        print('Parsed JSON: $messageJson');
        _messageStream.add({
          'topic': messages[0].topic,
          'message': messageJson,
        });
        print('Message added to stream\n');
      } catch (e) {
        print('Error parsing message as JSON: $e');
        print('Raw message that failed to parse: $messageStr');
        // Fallback for non-JSON messages
        _messageStream.add({
          'topic': messages[0].topic,
          'message': {'value': messageStr},
        });
        print('Added fallback message to stream\n');
      }
    });
  }

  void _onConnected() {
    _connectionStatus.add(MqttCurrentConnectionState.CONNECTED);
    print('Connected to HiveMQ Cloud');
  }

  void _onDisconnected() {
    _connectionStatus.add(MqttCurrentConnectionState.DISCONNECTED);
  }

  void _onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }
}
