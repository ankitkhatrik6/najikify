enum DevicePlatform {
  linux,
  android,
  windows,
  macos,
  ios,
  web,
  unknown;

  static DevicePlatform fromString(String value) {
    switch (value.toLowerCase()) {
      case 'linux':
        return DevicePlatform.linux;
      case 'android':
        return DevicePlatform.android;
      case 'windows':
        return DevicePlatform.windows;
      case 'macos':
        return DevicePlatform.macos;
      case 'ios':
        return DevicePlatform.ios;
      case 'web':
        return DevicePlatform.web;
      default:
        return DevicePlatform.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case DevicePlatform.linux:
        return 'Linux';
      case DevicePlatform.android:
        return 'Android';
      case DevicePlatform.windows:
        return 'Windows';
      case DevicePlatform.macos:
        return 'macOS';
      case DevicePlatform.ios:
        return 'iOS';
      case DevicePlatform.web:
        return 'Web';
      case DevicePlatform.unknown:
        return 'Unknown';
    }
  }
}

class Device {
  final String id;
  final String name;
  final DevicePlatform platform;
  final String ipAddress;
  final int port;
  final String fingerprint;
  final bool isTrusted;
  final DateTime lastSeen;

  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.ipAddress,
    required this.port,
    required this.fingerprint,
    this.isTrusted = false,
    required this.lastSeen,
  });

  String get httpBaseUrl => 'http://$ipAddress:$port';

  Device copyWith({
    String? id,
    String? name,
    DevicePlatform? platform,
    String? ipAddress,
    int? port,
    String? fingerprint,
    bool? isTrusted,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      fingerprint: fingerprint ?? this.fingerprint,
      isTrusted: isTrusted ?? this.isTrusted,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'platform': platform.name,
      'ip_address': ipAddress,
      'port': port,
      'fingerprint': fingerprint,
      'is_trusted': isTrusted ? 1 : 0,
      'last_seen': lastSeen.millisecondsSinceEpoch,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      name: map['name'] as String,
      platform: DevicePlatform.fromString(map['platform'] as String),
      ipAddress: map['ip_address'] as String,
      port: map['port'] as int,
      fingerprint: map['fingerprint'] as String? ?? '',
      isTrusted: (map['is_trusted'] as int? ?? 0) == 1,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform.name,
      'ip': ipAddress,
      'port': port,
      'fingerprint': fingerprint,
      'isTrusted': isTrusted,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: DevicePlatform.fromString(json['platform'] as String? ?? 'unknown'),
      ipAddress: json['ip'] as String? ?? json['ip_address'] as String? ?? '',
      port: json['port'] as int? ?? 53317,
      fingerprint: json['fingerprint'] as String? ?? '',
      isTrusted: json['isTrusted'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen'] as String) : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
