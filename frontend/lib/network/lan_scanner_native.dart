import 'dart:io';

/// Native implementation — scans device network interfaces to find LAN hosts.
Future<List<String>> detectLanHosts() async {
  final hosts = <String>{};
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length != 4) continue;
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        if (subnet == '127.0.0' || parts[0] == '169') continue;
        for (final lastOctet in [1, 2, 3, 4, 5, 10, 20, 35, 50, 100]) {
          hosts.add('$subnet.$lastOctet');
        }
      }
    }
  } catch (_) {}
  return hosts.toList();
}
