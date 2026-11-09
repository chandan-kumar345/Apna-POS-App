class CustomRingtone {
  final String id;
  final String name;
  final String url;
  final String type; // 'notification' or 'order'
  final int sizeBytes;
  final DateTime? createdAt;

  const CustomRingtone({
    required this.id,
    required this.name,
    required this.url,
    this.type = 'order',
    this.sizeBytes = 0,
    this.createdAt,
  });

  factory CustomRingtone.fromJson(Map<String, dynamic> json) {
    return CustomRingtone(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Custom Audio',
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString() ?? 'order',
      sizeBytes: int.tryParse(json['sizeBytes']?.toString() ?? '0') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'sizeBytes': sizeBytes,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class NotificationSettingModel {
  final String? id;
  final String? businessId;
  final String? userId;

  // General Notification Ringtone
  final String notificationSound;
  final String notificationSoundName;
  final String notificationSoundUrl;
  final String notificationSoundType; // 'default', 'preset', 'custom'

  // Urgent Incoming Order Accept Ringtone
  final String orderRingtone;
  final String orderRingtoneName;
  final String orderRingtoneUrl;
  final String orderRingtoneType; // 'default', 'preset', 'custom'

  // Preferences
  final bool soundEnabled;
  final double orderVolume;
  final double notificationVolume;
  final bool vibrationEnabled;
  final bool autoOpenOrderScreen;

  final List<CustomRingtone> customRingtones;

  const NotificationSettingModel({
    this.id,
    this.businessId,
    this.userId,
    this.notificationSound = 'default',
    this.notificationSoundName = 'Default Apna POS (Chime)',
    this.notificationSoundUrl = 'sounds/Notification_sound.mp3',
    this.notificationSoundType = 'default',
    this.orderRingtone = 'default',
    this.orderRingtoneName = 'Default Apna POS (Looping Alarm)',
    this.orderRingtoneUrl = 'sounds/order_recieve_ringtone.mp3',
    this.orderRingtoneType = 'default',
    this.soundEnabled = true,
    this.orderVolume = 1.0,
    this.notificationVolume = 1.0,
    this.vibrationEnabled = true,
    this.autoOpenOrderScreen = true,
    this.customRingtones = const [],
  });

  factory NotificationSettingModel.defaults({String? businessId, String? userId}) {
    return NotificationSettingModel(
      businessId: businessId,
      userId: userId,
      notificationSound: 'default',
      notificationSoundName: 'Default Apna POS (Chime)',
      notificationSoundUrl: 'sounds/Notification_sound.mp3',
      notificationSoundType: 'default',
      orderRingtone: 'default',
      orderRingtoneName: 'Default Apna POS (Looping Alarm)',
      orderRingtoneUrl: 'sounds/order_recieve_ringtone.mp3',
      orderRingtoneType: 'default',
      soundEnabled: true,
      orderVolume: 1.0,
      notificationVolume: 1.0,
      vibrationEnabled: true,
      autoOpenOrderScreen: true,
      customRingtones: const [],
    );
  }

  factory NotificationSettingModel.fromJson(Map<String, dynamic> json) {
    final customList = <CustomRingtone>[];
    if (json['customRingtones'] is List) {
      for (final item in json['customRingtones']) {
        if (item is Map) {
          customList.add(CustomRingtone.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return NotificationSettingModel(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      businessId: json['businessId']?.toString(),
      userId: json['userId']?.toString(),
      notificationSound: json['notificationSound']?.toString() ?? 'default',
      notificationSoundName: json['notificationSoundName']?.toString() ?? 'Default Apna POS (Chime)',
      notificationSoundUrl: json['notificationSoundUrl']?.toString() ?? 'sounds/Notification_sound.mp3',
      notificationSoundType: json['notificationSoundType']?.toString() ?? 'default',
      orderRingtone: json['orderRingtone']?.toString() ?? 'default',
      orderRingtoneName: json['orderRingtoneName']?.toString() ?? 'Default Apna POS (Looping Alarm)',
      orderRingtoneUrl: json['orderRingtoneUrl']?.toString() ?? 'sounds/order_recieve_ringtone.mp3',
      orderRingtoneType: json['orderRingtoneType']?.toString() ?? 'default',
      soundEnabled: json['soundEnabled'] != false,
      orderVolume: double.tryParse(json['orderVolume']?.toString() ?? '1.0') ?? 1.0,
      notificationVolume: double.tryParse(json['notificationVolume']?.toString() ?? '1.0') ?? 1.0,
      vibrationEnabled: json['vibrationEnabled'] != false,
      autoOpenOrderScreen: json['autoOpenOrderScreen'] != false,
      customRingtones: customList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (businessId != null) 'businessId': businessId,
      if (userId != null) 'userId': userId,
      'notificationSound': notificationSound,
      'notificationSoundName': notificationSoundName,
      'notificationSoundUrl': notificationSoundUrl,
      'notificationSoundType': notificationSoundType,
      'orderRingtone': orderRingtone,
      'orderRingtoneName': orderRingtoneName,
      'orderRingtoneUrl': orderRingtoneUrl,
      'orderRingtoneType': orderRingtoneType,
      'soundEnabled': soundEnabled,
      'orderVolume': orderVolume,
      'notificationVolume': notificationVolume,
      'vibrationEnabled': vibrationEnabled,
      'autoOpenOrderScreen': autoOpenOrderScreen,
      'customRingtones': customRingtones.map((e) => e.toJson()).toList(),
    };
  }

  NotificationSettingModel copyWith({
    String? id,
    String? businessId,
    String? userId,
    String? notificationSound,
    String? notificationSoundName,
    String? notificationSoundUrl,
    String? notificationSoundType,
    String? orderRingtone,
    String? orderRingtoneName,
    String? orderRingtoneUrl,
    String? orderRingtoneType,
    bool? soundEnabled,
    double? orderVolume,
    double? notificationVolume,
    bool? vibrationEnabled,
    bool? autoOpenOrderScreen,
    List<CustomRingtone>? customRingtones,
  }) {
    return NotificationSettingModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      userId: userId ?? this.userId,
      notificationSound: notificationSound ?? this.notificationSound,
      notificationSoundName: notificationSoundName ?? this.notificationSoundName,
      notificationSoundUrl: notificationSoundUrl ?? this.notificationSoundUrl,
      notificationSoundType: notificationSoundType ?? this.notificationSoundType,
      orderRingtone: orderRingtone ?? this.orderRingtone,
      orderRingtoneName: orderRingtoneName ?? this.orderRingtoneName,
      orderRingtoneUrl: orderRingtoneUrl ?? this.orderRingtoneUrl,
      orderRingtoneType: orderRingtoneType ?? this.orderRingtoneType,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      orderVolume: orderVolume ?? this.orderVolume,
      notificationVolume: notificationVolume ?? this.notificationVolume,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      autoOpenOrderScreen: autoOpenOrderScreen ?? this.autoOpenOrderScreen,
      customRingtones: customRingtones ?? this.customRingtones,
    );
  }
}
