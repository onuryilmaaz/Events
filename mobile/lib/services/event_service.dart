import 'package:dio/dio.dart';
import '../models/event_model.dart';

class EventService {
  final Dio dio = Dio();
  final String baseUrl = 'http://10.0.2.2:5117';

  Future<List<Event>> getEvents() async {
    try {
      final response = await dio.get('$baseUrl/api/Events');
      return (response.data as List)
          .map((item) => Event.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Etkinlikler yüklenemedi: $e');
    }
  }

  Future<Event> getEvent(String id) async {
    try {
      final response = await dio.get('$baseUrl/api/events/$id');
      return Event.fromJson(response.data);
    } catch (e) {
      throw Exception('Etkinlik yüklenemedi: $e');
    }
  }

  Future<Event> createEvent(Event event) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/events',
        data: event.toJson(),
      );
      return Event.fromJson(response.data);
    } catch (e) {
      throw Exception('Etkinlik oluşturulamadı: $e');
    }
  }

  Future<Event> updateEvent(Event event) async {
    try {
      final response = await dio.put(
        '$baseUrl/api/events/${event.id}',
        data: event.toJson(),
      );
      return Event.fromJson(response.data);
    } catch (e) {
      throw Exception('Etkinlik güncellenemedi: $e');
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await dio.delete('$baseUrl/api/events/$id');
    } catch (e) {
      throw Exception('Etkinlik silinemedi: $e');
    }
  }
}
