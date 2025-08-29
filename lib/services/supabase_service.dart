import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://clsyjaqncfjicxkyvjud.supabase.co';
  static const String supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsc3lqYXFuY2ZqaWN4a3l2anVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzODU2NDIsImV4cCI6MjA3MVk2MTY0Mn0.wl1b3h6-RpGNeVFQUikSSG0O3EvMFOzpm9AeP7QL2I4';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  }

  // Insert sensor data into Supabase
  static Future<void> insertSensorData({
    required bool doorStatus,
    required bool lightStatus,
    required bool motionDetected,
    required bool fireAlarm,
  }) async {
    try {
      await client.from('sensor_data').insert({
        'door_status': doorStatus,
        'light_status': lightStatus,
        'motion_detected': motionDetected,
        'fire_alarm': fireAlarm,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('Sensor data inserted successfully');
    } catch (e) {
      print('Error inserting sensor data: $e');
    }
  }

  // Get latest sensor readings
  static Future<Map<String, dynamic>?> getLatestSensorData() async {
    try {
      final response = await client
          .from('sensor_data')
          .select()
          .order('timestamp', ascending: false)
          .limit(1)
          .single();

      print('Latest sensor data retrieved successfully');
      return response;
    } catch (e) {
      print('Error getting latest sensor data: $e');
      return null;
    }
  }

  // Get sensor data history
  static Future<List<Map<String, dynamic>>> getSensorDataHistory({
    int limit = 10,
  }) async {
    try {
      final response = await client
          .from('sensor_data')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);

      print('Sensor data history retrieved successfully');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting sensor data history: $e');
      return [];
    }
  }

  // Insert door control logs
  static Future<void> insertDoorControlLog({
    required String action,
    required bool previousState,
    required bool newState,
  }) async {
    try {
      await client.from('door_control_logs').insert({
        'action': action,
        'previous_state': previousState,
        'new_state': newState,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('Door control log inserted successfully');
    } catch (e) {
      print('Error inserting door control log: $e');
    }
  }

  // Get door control history
  static Future<List<Map<String, dynamic>>> getDoorControlHistory({
    int limit = 10,
  }) async {
    try {
      final response = await client
          .from('door_control_logs')
          .select()
          .order('timestamp', ascending: false)
          .limit(limit);

      print('Door control history retrieved successfully');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting door control history: $e');
      return [];
    }
  }
}
