# 1. Update storefront_model.dart
with open('lib/features/storefront/models/storefront_model.dart', 'r', encoding='utf-8') as f:
    m_text = f.read()

target_fields = """  final int totalTables;
  final String? error;

  const StorefrontTableInfo({
    this.isValid = true,
    required this.tableCode,
    this.tableNumber,
    this.name = '',
    this.floor = 'Ground Floor',
    this.capacity = 4,
    this.totalTables = 0,
    this.error,
  });"""

replace_fields = """  final int totalTables;
  final String? error;
  final bool isTableOrdering;
  final String restaurantCode;

  const StorefrontTableInfo({
    this.isValid = true,
    required this.tableCode,
    this.tableNumber,
    this.name = '',
    this.floor = 'Ground Floor',
    this.capacity = 4,
    this.totalTables = 0,
    this.error,
    this.isTableOrdering = false,
    this.restaurantCode = '',
  });"""

target_from_json = """      totalTables: (json['totalTables'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
    );"""

replace_from_json = """      totalTables: (json['totalTables'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString(),
      isTableOrdering: json['isTableOrdering'] == true,
      restaurantCode: json['restaurantCode']?.toString() ?? '',
    );"""

target_copy_with = """    int? totalTables,
    String? error,
  }) {
    return StorefrontTableInfo(
      isValid: isValid ?? this.isValid,
      tableCode: tableCode ?? this.tableCode,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      totalTables: totalTables ?? this.totalTables,
      error: error,
    );"""

replace_copy_with = """    int? totalTables,
    String? error,
    bool? isTableOrdering,
    String? restaurantCode,
  }) {
    return StorefrontTableInfo(
      isValid: isValid ?? this.isValid,
      tableCode: tableCode ?? this.tableCode,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      totalTables: totalTables ?? this.totalTables,
      error: error,
      isTableOrdering: isTableOrdering ?? this.isTableOrdering,
      restaurantCode: restaurantCode ?? this.restaurantCode,
    );"""

m_norm = m_text.replace('\r\n', '\n')
assert target_fields.replace('\r\n', '\n') in m_norm, "target_fields not found"
assert target_from_json.replace('\r\n', '\n') in m_norm, "target_from_json not found"
assert target_copy_with.replace('\r\n', '\n') in m_norm, "target_copy_with not found"

m_norm = m_norm.replace(target_fields.replace('\r\n', '\n'), replace_fields)
m_norm = m_norm.replace(target_from_json.replace('\r\n', '\n'), replace_from_json)
m_norm = m_norm.replace(target_copy_with.replace('\r\n', '\n'), replace_copy_with)

with open('lib/features/storefront/models/storefront_model.dart', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(m_norm)
print("SUCCESS: storefront_model.dart updated")

# 2. Update storefront_service.dart to import 'dart:async';
with open('lib/features/storefront/services/storefront_service.dart', 'r', encoding='utf-8') as f:
    s_text = f.read()

s_norm = s_text.replace('\r\n', '\n')
if "import 'dart:async';" not in s_norm:
    s_norm = "import 'dart:async';\n" + s_norm
    with open('lib/features/storefront/services/storefront_service.dart', 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(s_norm)
    print("SUCCESS: storefront_service.dart updated with import 'dart:async';")
else:
    print("ALREADY PRESENT: import 'dart:async';")
