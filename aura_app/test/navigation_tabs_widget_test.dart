import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/main.dart';

class _MockImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  static final Uint8List _kTransparentImage = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockImageHttpOverrides();
  });

  group('NextGen IT Global - Primary Navigation Tabs Widget Tests', () {
    testWidgets('1. Renders all 5 primary bottom navigation tabs with correct labels and icons', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // 1. Radar Tab
      expect(find.text('Radar'), findsOneWidget);
      expect(find.byIcon(Icons.radar_rounded), findsWidgets);

      // 2. Discover Tab
      expect(find.text('Discover'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);

      // 3. Echoes Tab
      expect(find.text('Echoes'), findsOneWidget);
      expect(find.byIcon(Icons.waves_outlined), findsOneWidget);

      // 4. Chat Tab
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      // 5. Profile & Privacy Tab
      expect(find.text('Profile & Privacy'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('2. Switching between navigation tabs updates active screen correctly', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationShell(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Verify initial index is 0 (Radar)
      expect((tester.widget(find.byType(IndexedStack)) as IndexedStack).index, equals(0));

      // Tap on 'Discover' tab
      await tester.tap(find.text('Discover'));
      await tester.pump(const Duration(milliseconds: 200));
      expect((tester.widget(find.byType(IndexedStack)) as IndexedStack).index, equals(1));

      // Tap on 'Echoes' tab
      await tester.tap(find.text('Echoes'));
      await tester.pump(const Duration(milliseconds: 200));
      expect((tester.widget(find.byType(IndexedStack)) as IndexedStack).index, equals(2));

      // Tap on 'Chat' tab
      await tester.tap(find.text('Chat'));
      await tester.pump(const Duration(milliseconds: 200));
      expect((tester.widget(find.byType(IndexedStack)) as IndexedStack).index, equals(3));

      // Tap on 'Profile & Privacy' tab
      await tester.tap(find.text('Profile & Privacy'));
      await tester.pump(const Duration(milliseconds: 200));
      expect((tester.widget(find.byType(IndexedStack)) as IndexedStack).index, equals(4));

      // Return to 'Radar' tab
      await tester.tap(find.text('Radar'));
      await tester.pump(const Duration(milliseconds: 200));
      expect((tester.widget(find.byType(IndexedStack)) as IndexedStack).index, equals(0));
    });
  });
}
