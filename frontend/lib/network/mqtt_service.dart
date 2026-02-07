// Conditional export: re-export the IO or Web implementation depending on platform.
// This file serves as the single import point for MqttService in the app.
export 'mqtt_service_io.dart' if (dart.library.html) 'mqtt_service_web.dart';
