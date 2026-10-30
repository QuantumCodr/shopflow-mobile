class ShopSettings {
  const ShopSettings({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.isActive,
  });

  final String id;
  final String name;
  final String currencyCode;
  final bool isActive;

  factory ShopSettings.fromMap(Map<String, dynamic> map) {
    return ShopSettings(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? '',
      currencyCode: map['currency_code']?.toString() ?? 'SLE',
      isActive: map['is_active'] == true,
    );
  }
}

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.accountEmail,
    required this.shop,
  });

  final String accountEmail;
  final ShopSettings shop;
}