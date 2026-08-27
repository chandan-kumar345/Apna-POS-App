class CrmLeadModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String source;
  final String stage;
  final String status;
  final List<String> tags;
  final bool isLiked;
  final bool isStarred;
  final DateTime? followupDate;
  final String followupNotes;
  final String followupStatus;
  final String notes;
  final int totalOrders;
  final double totalSpent;
  final DateTime createdAt;
  final DateTime? lastVisit;
  final List<dynamic> recentOrders;

  CrmLeadModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.source = 'Dine In',
    this.stage = 'New Lead',
    this.status = 'New Lead',
    this.tags = const ['New Lead'],
    this.isLiked = false,
    this.isStarred = false,
    this.followupDate,
    this.followupNotes = '',
    this.followupStatus = 'none',
    this.notes = '',
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    required this.createdAt,
    this.lastVisit,
    this.recentOrders = const [],
  });

  factory CrmLeadModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    }
    if (parsedTags.isEmpty) {
      final st = json['status']?.toString() ?? 'New Lead';
      parsedTags = [st];
    }

    DateTime parsedCreated = DateTime.now();
    if (json['createdAt'] != null) {
      try {
        parsedCreated = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    DateTime? parsedFollowup;
    if (json['followupDate'] != null) {
      try {
        parsedFollowup = DateTime.parse(json['followupDate'].toString());
      } catch (_) {}
    }

    DateTime? parsedLastVisit;
    if (json['lastVisit'] != null) {
      try {
        parsedLastVisit = DateTime.parse(json['lastVisit'].toString());
      } catch (_) {}
    }

    return CrmLeadModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: (json['name']?.toString() ?? '').trim().isNotEmpty
          ? json['name'].toString().trim()
          : 'Guest Customer',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      source: (json['source']?.toString() ?? '').trim().isNotEmpty
          ? json['source'].toString().trim()
          : 'Dine In',
      stage: json['stage']?.toString() ?? 'New Lead',
      status: json['status']?.toString() ?? 'New Lead',
      tags: parsedTags,
      isLiked: json['isLiked'] == true,
      isStarred: json['isStarred'] == true,
      followupDate: parsedFollowup,
      followupNotes: json['followupNotes']?.toString() ?? '',
      followupStatus: json['followupStatus']?.toString() ?? 'none',
      notes: json['notes']?.toString() ?? '',
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      createdAt: parsedCreated,
      lastVisit: parsedLastVisit,
      recentOrders: json['recentOrders'] is List ? json['recentOrders'] as List : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'source': source,
        'stage': stage,
        'status': status,
        'tags': tags,
        'isLiked': isLiked,
        'isStarred': isStarred,
        'followupDate': followupDate?.toIso8601String(),
        'followupNotes': followupNotes,
        'followupStatus': followupStatus,
        'notes': notes,
        'totalOrders': totalOrders,
        'totalSpent': totalSpent,
        'createdAt': createdAt.toIso8601String(),
        'lastVisit': lastVisit?.toIso8601String(),
      };

  CrmLeadModel copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? source,
    String? stage,
    String? status,
    List<String>? tags,
    bool? isLiked,
    bool? isStarred,
    DateTime? followupDate,
    String? followupNotes,
    String? followupStatus,
    String? notes,
    int? totalOrders,
    double? totalSpent,
    DateTime? lastVisit,
    List<dynamic>? recentOrders,
  }) {
    return CrmLeadModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      source: source ?? this.source,
      stage: stage ?? this.stage,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      isLiked: isLiked ?? this.isLiked,
      isStarred: isStarred ?? this.isStarred,
      followupDate: followupDate ?? this.followupDate,
      followupNotes: followupNotes ?? this.followupNotes,
      followupStatus: followupStatus ?? this.followupStatus,
      notes: notes ?? this.notes,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      createdAt: createdAt,
      lastVisit: lastVisit ?? this.lastVisit,
      recentOrders: recentOrders ?? this.recentOrders,
    );
  }
}

class CrmStatsModel {
  final int total;
  final int leads;
  final int prospects;
  final int deals;
  final int wins;
  final int lost;

  CrmStatsModel({
    this.total = 0,
    this.leads = 0,
    this.prospects = 0,
    this.deals = 0,
    this.wins = 0,
    this.lost = 0,
  });

  factory CrmStatsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CrmStatsModel();
    return CrmStatsModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      leads: (json['leads'] as num?)?.toInt() ?? 0,
      prospects: (json['prospects'] as num?)?.toInt() ?? 0,
      deals: (json['deals'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      lost: (json['lost'] as num?)?.toInt() ?? 0,
    );
  }
}
