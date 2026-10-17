import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  String? _authToken;

  ApiClient._internal() {
    final baseUrl = kIsWeb
        ? 'http://localhost:3000'
        : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          debugPrint('API Error [${e.response?.statusCode}]: ${e.message}');
          return handler.next(e);
        },
      ),
    );
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  // Auth Endpoints
  Future<Response> sendOtp(String phone) =>
      dio.post('/api/auth/send-otp', data: {'phone': phone});

  Future<Response> verifyOtp(String phone, String otp) =>
      dio.post('/api/auth/verify-otp', data: {'phone': phone, 'otp': otp});

  Future<Response> demoLogin() => dio.post('/api/auth/demo-login');

  // Location & Radar Endpoints
  Future<Response> getRadar(double lat, double lng, double radiusKm) =>
      dio.get('/api/location/radar', queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radiusKm,
      });

  Future<Response> updateLocation(double lat, double lng, double accuracy) =>
      dio.post('/api/location/update', data: {
        'latitude': lat,
        'longitude': lng,
        'accuracy': accuracy,
      });

  Future<Response> getEchoes() => dio.get('/api/location/echoes');

  // DPDP Act & Privacy Endpoints
  Future<Response> setIncognito(bool isIncognito) =>
      dio.put('/api/user/incognito', data: {'isIncognito': isIncognito});

  Future<Response> blockUser(String targetUserId) =>
      dio.post('/api/user/block', data: {'targetUserId': targetUserId});

  Future<Response> reportUser(String targetUserId, String reason, String details) =>
      dio.post('/api/user/report', data: {
        'targetUserId': targetUserId,
        'reason': reason,
        'details': details,
      });

  Future<Response> deleteAccount() => dio.delete('/api/user/account');

  Future<Response> purgeLocationHistory() => dio.delete('/api/location/history');

  Future<Response> exportData() => dio.get('/api/user/export-data');
}
