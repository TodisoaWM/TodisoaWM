class Client {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String country;
  final String createdAt;

  Client({
    this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.country = 'Madagascar',
    this.createdAt = '',
  });

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'],
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        address: m['address'] ?? '',
        city: m['city'] ?? '',
        country: m['country'] ?? 'Madagascar',
        createdAt: m['created_at'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'country': country,
        'created_at': createdAt.isEmpty
            ? DateTime.now().toIso8601String()
            : createdAt,
      };

  Client copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? country,
  }) =>
      Client(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        city: city ?? this.city,
        country: country ?? this.country,
        createdAt: createdAt,
      );
}
