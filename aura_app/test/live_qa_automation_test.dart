import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:aura_app/features/auth/presentation/screens/otp_screen.dart';
import 'package:aura_app/features/radar/presentation/screens/radar_screen.dart';
import 'package:aura_app/features/radar/presentation/widgets/dna_blueprint_sheet.dart';
import 'package:aura_app/features/radar/data/models/dna_blueprint_model.dart';
import 'package:aura_app/features/echoes/presentation/screens/echoes_screen.dart';
import 'package:aura_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:aura_app/features/chat/presentation/screens/matches_chat_list_screen.dart';
import 'package:aura_app/features/chat/presentation/widgets/receiver_call_consent_card.dart';
import 'package:aura_app/features/chat/domain/entities/call_consent_request.dart';
import 'package:aura_app/features/chat/presentation/widgets/vibe_spark_ignition_modal.dart';
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

  group('Principal Mobile QA Automation Suite: Aura Dating App Live End-to-End Run', () {

    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => '.',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async => null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.auraapp.aura_app/security'),
        (MethodCall methodCall) async => true,
      );
    });

    testWidgets('01_welcome_snow_manali.png', (WidgetTester tester) async {
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
        matchesGoldenFile('../test_reports/screenshots/01_welcome_snow_manali.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('02_welcome_tokyo_sakura.png', (WidgetTester tester) async {
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
        matchesGoldenFile('../test_reports/screenshots/02_welcome_tokyo_sakura.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('03_phone_auth_canada.png', (WidgetTester tester) async {
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
        matchesGoldenFile('../test_reports/screenshots/03_phone_auth_canada.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('04_otp_verification.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: const OtpScreen(
            initialIsOtpSent: true,
            initialPhoneNumber: '+1 (416) 555-0199',
            initialCountdown: 28,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../test_reports/screenshots/04_otp_verification.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('05_radar_active_nodes.png', (WidgetTester tester) async {
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
            body: RadarScreen(isTestMode: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../test_reports/screenshots/05_radar_active_nodes.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('06_dna_blueprint_sheet.png', (WidgetTester tester) async {
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
              child: DnaBlueprintSheet(
                initialBlueprint: DnaBlueprint(
                  socialEnergy: SocialEnergy.extrovert,
                  idealFirstMeet: IdealFirstMeet.foodAndMusic,
                  lifestylePace: LifestylePace.spontaneous,
                  connectionGoal: ConnectionGoal.chemistry,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../test_reports/screenshots/06_dna_blueprint_sheet.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('07_call_permission_handshake.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      final testConsentRequest = CallConsentRequest(
        callerId: 'usr_elena_007',
        callerName: 'Elena Rostova',
        callerAvatarUrl: '',
        callType: CallType.video,
        status: CallConsentStatus.pending,
        timestamp: DateTime.now(),
        ttl: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: Scaffold(
            backgroundColor: const Color(0xFF080A0F),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ReceiverCallConsentCard(
                  request: testConsentRequest,
                  onAllowAndConnect: () {},
                  onDecline: () {},
                  onMute: () {},
                  onExpired: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../test_reports/screenshots/07_call_permission_handshake.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('08_secret_vault_search_reveal.png', (WidgetTester tester) async {
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
        matchesGoldenFile('../test_reports/screenshots/08_secret_vault_search_reveal.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('09_spark_meter_80_surge.png', (WidgetTester tester) async {
      tester.view.physicalSize = physicalPhoneSize;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          builder: (context, child) => RepaintBoundary(key: key, child: child),
          home: Scaffold(
            backgroundColor: const Color(0xFF080A0F),
            body: Stack(
              children: [
                const ChatScreen(
                  matchId: 'match_priya_vibe',
                  matchName: 'Priya Sharma',
                  currentUserId: 'usr_me_001',
                  initialChemistryScore: 85,
                  enableLiveSockets: false,
                ),
                VibeSparkIgnitionModal(
                  score: 85,
                  matchName: 'Priya Sharma',
                  onDatePlanSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../test_reports/screenshots/09_spark_meter_80_surge.png'),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('10_date_prep_concierge.png', (WidgetTester tester) async {
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
                initialTabIndex: 1, // Outfit & Prep Tab
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byKey(key),
        matchesGoldenFile('../test_reports/screenshots/10_date_prep_concierge.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('11_echoes_feed.png', (WidgetTester tester) async {
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
        matchesGoldenFile('../test_reports/screenshots/11_echoes_feed.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
