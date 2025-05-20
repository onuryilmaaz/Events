class Event {
  final String? id;
  final String eventTitle;
  final String decs;
  final DateTime startDate;
  final DateTime endDate;
  final String category;
  final List<double> coordinates;
  final String name;
  final String address;
  final String phone;
  final String imageUrl;

  Event({
    this.id,
    required this.eventTitle,
    required this.decs,
    required this.startDate,
    required this.endDate,
    required this.category,
    required this.coordinates,
    required this.name,
    required this.address,
    required this.phone,
    required this.imageUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      eventTitle: json['eventTitle'],
      decs: json['decs'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      category: json['category'],
      coordinates: List<double>.from(json['coordinates']),
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventTitle': eventTitle,
      'decs': decs,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'category': category,
      'coordinates': coordinates,
      'name': name,
      'address': address,
      'phone': phone,
      'imageUrl': imageUrl,
    };
  }
}
