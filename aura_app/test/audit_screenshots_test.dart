import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:aura_app/features/auth/presentation/screens/otp_screen.dart';
import 'package:aura_app/features/radar/presentation/screens/radar_screen.dart';
import 'package:aura_app/features/echoes/presentation/screens/echoes_screen.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:aura_app/features/chat/presentation/screens/matches_chat_list_screen.dart';
import 'package:aura_app/features/chat/presentation/widgets/date_concierge_sheet.dart';
import 'package:aura_app/features/auth/presentation/theme/atmospheric_theme.dart';

class MockImageHttpOverrides extends HttpOverrides {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MockImageHttpOverrides();
  const physicalPhoneSize = Size(786, 1704); // 393 x 852 logical at 2.0 dpr

  group('Aura Dating App: Screen-By-Screen Verification & Screenshot Capture', () {
    testWidgets('01_welcome_landing_snow_manali.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: const WelcomeScreen(
              initialDestinationIndex: 0,
              forcedEnvironment: AtmosphericEnvironment.snow,
              isDemoPreviewMode: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/01_welcome_landing_snow_manali.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('02_welcome_landing_banff_canada.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: const WelcomeScreen(
              initialDestinationIndex: 1,
              forcedEnvironment: AtmosphericEnvironment.snow,
              isDemoPreviewMode: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/02_welcome_landing_banff_canada.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('03_welcome_landing_sakura_tokyo.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: key,
            child: const WelcomeScreen(
              initialDestinationIndex: 2,
              forcedEnvironment: AtmosphericEnvironment.springDusk,
              isDemoPreviewMode: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/03_welcome_landing_sakura_tokyo.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('04_phone_auth_canada_picker.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: const OtpScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on the country dial code pill to reveal Canada (+1) & India (+91) selector sheet
      final countrySelector = find.byType(InkWell).first;
      await tester.tap(countrySelector);
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/04_phone_auth_canada_picker.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('05_radar_500m_proximity_feed.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: const Scaffold(
            backgroundColor: Color(0xFF080A0F),
            body: RadarScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/05_radar_500m_proximity_feed.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('06_echoes_path_crossings_screen.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: const Scaffold(
            backgroundColor: Color(0xFF080A0F),
            body: EchoesScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/06_echoes_path_crossings_screen.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('07_chat_vibe_thermometer_80_magic.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: const ChatScreen(
            matchId: 'match_priya_vibe',
            matchName: 'Priya Sharma',
            currentUserId: 'usr_me_001',
            initialChemistryScore: 84,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/07_chat_vibe_thermometer_80_magic.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('08_secret_vault_hidden_search.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: const MatchesChatListScreen(
            initialSearchQuery: '7777',
            initialVaultUnlocked: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/08_secret_vault_hidden_search.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('09_date_prep_outfit_concierge.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: const Scaffold(
            backgroundColor: Color(0xFF080A0F),
            body: SafeArea(
              child: DateConciergeSheet(
                matchName: 'Priya Sharma',
                initialTabIndex: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../docs/audit_screenshots/09_date_prep_outfit_concierge.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
