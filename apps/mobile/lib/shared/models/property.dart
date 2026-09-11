class Property {
  const Property({
    required this.id,
    required this.name,
    required this.type,
    required this.pricePerDay,
    this.priceMorningShift,
    this.priceEveningShift,
    required this.capacity,
    this.description = '',
    this.cityName,
    this.provinceName,
    this.amenities = const [],
    this.imageUrl,
  });

  final String id;
  final String name;
  final String type;
  final num pricePerDay;
  final num? priceMorningShift;
  final num? priceEveningShift;
  final int capacity;
  final String description;
  final String? cityName;
  final String? provinceName;
  final List<String> amenities;
  final String? imageUrl;

  factory Property.fromJson(Map<String, dynamic> json) {
    final city = json['city'] as Map<String, dynamic>?;
    final media = json['media'] as List<dynamic>? ?? [];
    final firstImage = media.cast<Map<String, dynamic>?>().whereType<Map<String, dynamic>>().cast<Map<String, dynamic>>();
    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      pricePerDay: json['pricePerDay'] is num
          ? json['pricePerDay'] as num
          : num.tryParse('${json['pricePerDay']}') ?? 0,
      priceMorningShift: json['priceMorningShift'] != null
          ? (json['priceMorningShift'] is num
              ? json['priceMorningShift'] as num
              : num.tryParse('${json['priceMorningShift']}'))
          : null,
      priceEveningShift: json['priceEveningShift'] != null
          ? (json['priceEveningShift'] is num
              ? json['priceEveningShift'] as num
              : num.tryParse('${json['priceEveningShift']}'))
          : null,
      capacity: json['capacity'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      cityName: city?['nameAr'] as String?,
      provinceName: (city?['province'] as Map<String, dynamic>?)?['nameAr'] as String?,
      amenities: (json['amenities'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      imageUrl: firstImage.isEmpty ? null : firstImage.first['url'] as String?,
    );
  }
}
