import 'package:flutter/material.dart';
import 'services/mqtt_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home Monitor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Smart Home Monitor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final MQTTService _mqttService = MQTTService();
  bool _doorStatus = false;
  bool _lightStatus = false;
  bool _motionDetected = false;
  bool _fireAlarm = false;
  MqttCurrentConnectionState _connectionState = MqttCurrentConnectionState.IDLE;

  @override
  void initState() {
    super.initState();
    _setupMqttClient();
    _setupSubscriptions();
  }

  Future<void> _setupMqttClient() async {
    await _mqttService.connect();
  }

  void _setupSubscriptions() {
    _mqttService.connectionStream.listen((state) {
      setState(() {
        _connectionState = state;
        if (state == MqttCurrentConnectionState.CONNECTED) {
          _subscribeToTopics();
        }
      });
    });

    _mqttService.messageStream.listen((data) {
      _updateSensorStatus(data['topic'], data['message']);
    });
  }

  void _subscribeToTopics() {
    _mqttService.subscribe('safehouse/data'); // Subscribe to sensor data
  }

  void _updateSensorStatus(String topic, dynamic message) {
    if (topic != 'safehouse/data') return;

    setState(() {
      final Map<String, dynamic> data = Map<String, dynamic>.from(message);

      // ✅ Light (robust fix)
      if (data.containsKey('light')) {
        final lightValue = data['light'].toString().trim().toLowerCase();
        if (lightValue == 'dark') {
          _lightStatus = true; // Active
        } else if (lightValue == 'light') {
          _lightStatus = false; // Inactive
        } else {
          _lightStatus = false;
        }
      }

      // Motion
      if (data.containsKey('motion')) {
        _motionDetected = int.tryParse(data['motion'].toString()) == 1;
      }

      // Fire/Smoke
      if (data.containsKey('smoke')) {
        _fireAlarm = int.tryParse(data['smoke'].toString()) == 1;
      }

      // Door
      if (data.containsKey('door')) {
        _doorStatus = data['door'].toString().toLowerCase() == 'open';
      }
    });

    // Save sensor data to Supabase
    _saveSensorDataToSupabase();

    print("\n=== Updated States ===");
    print("Light: $_lightStatus");
    print("Motion: $_motionDetected");
    print("Fire: $_fireAlarm");
    print("Door: $_doorStatus\n");
  }

  Future<void> _saveSensorDataToSupabase() async {
    await SupabaseService.insertSensorData(
      doorStatus: _doorStatus,
      lightStatus: _lightStatus,
      motionDetected: _motionDetected,
      fireAlarm: _fireAlarm,
    );
  }

  void _toggleDoor() {
    final previousStatus = _doorStatus;
    final newStatus = !_doorStatus;

    // Log door control action to Supabase
    SupabaseService.insertDoorControlLog(
      action: newStatus ? 'open' : 'close',
      previousState: previousStatus,
      newState: newStatus,
    );

    // Publish servo control message
    _mqttService.publish('safehouse/servo', {
      'servo': newStatus ? 'open' : 'close',
    });

    // Update local door status
    setState(() {
      _doorStatus = newStatus;
    });
  }

  @override
  void dispose() {
    _mqttService.disconnect();
    super.dispose();
  }

  Widget _buildStatusCard(
    String title,
    bool status,
    IconData icon,
    Color activeColor,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: status ? activeColor : Colors.grey,
          size: 32,
        ),
        title: Text(title),
        subtitle: Text(status ? 'Active' : 'Inactive'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            Card(
              child: ListTile(
                leading: Icon(
                  _connectionState == MqttCurrentConnectionState.CONNECTED
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                  color:
                      _connectionState == MqttCurrentConnectionState.CONNECTED
                      ? Colors.green
                      : Colors.red,
                ),
                title: const Text('Connection Status'),
                subtitle: Text(_connectionState.toString().split('.').last),
              ),
            ),
            const SizedBox(height: 16),
            // Sensors Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _buildStatusCard(
                    'Door',
                    _doorStatus,
                    Icons.door_front_door,
                    Colors.blue,
                  ),
                  _buildStatusCard(
                    'Light',
                    _lightStatus,
                    Icons.lightbulb,
                    Colors.yellow,
                  ),
                  _buildStatusCard(
                    'Motion Sensor',
                    _motionDetected,
                    Icons.motion_photos_on,
                    Colors.orange,
                  ),
                  _buildStatusCard(
                    'Fire Alarm',
                    _fireAlarm,
                    Icons.local_fire_department,
                    Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleDoor,
        label: Text(_doorStatus ? 'Close Door' : 'Open Door'),
        icon: Icon(_doorStatus ? Icons.lock : Icons.lock_open),
      ),
    );
  }
}
