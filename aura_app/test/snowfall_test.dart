import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/features/auth/presentation/screens/welcome_screen.dart';
import 'package:aura_app/features/auth/presentation/theme/atmospheric_theme.dart';
import 'package:aura_app/features/auth/presentation/widgets/atmospheric_particle_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AtmosphericTheme & Dynamic 4 Environments Tests', () {
    test('SNOW theme provides glacial arctic gradients and crisp icy cyan accents', () {
      final snow = AtmosphericThemeData.snow();
      expect(snow.environment, AtmosphericEnvironment.snow);
      expect(snow.radarPrimaryAccent, const Color(0xFF67E8F9)); // Frost Cyan
      expect(snow.radarSecondaryAccent, const Color(0xFFA5F3FC)); // Crisp Electric Ice
      expect(snow.backgroundGradient.colors.first, const Color(0xFF08121E));
    });

    test('RAIN theme provides midnight storm obsidian and electric neon cyan accents', () {
      final rain = AtmosphericThemeData.rain();
      expect(rain.environment, AtmosphericEnvironment.rain);
      expect(rain.radarPrimaryAccent, const Color(0xFF00F2FE)); // Electric Neon Cyan
      expect(rain.radarSecondaryAccent, const Color(0xFF4FACFE)); // Deep Violet Cyan
      expect(rain.backgroundGradient.colors.first, const Color(0xFF060B12));
    });

    test('AUTUMN theme provides burnished warm bronze and amber gold accents', () {
      final autumn = AtmosphericThemeData.autumn();
      expect(autumn.environment, AtmosphericEnvironment.autumn);
      expect(autumn.radarPrimaryAccent, const Color(0xFFF59E0B)); // Warm Amber Gold
      expect(autumn.radarSecondaryAccent, const Color(0xFFEA580C)); // Sunset Rust
      expect(autumn.backgroundGradient.colors.first, const Color(0xFF140804));
    });

    test('SPRING DUSK theme provides twilight plum obsidian and glowing neon rose accents', () {
      final spring = AtmosphericThemeData.springDusk();
      expect(spring.environment, AtmosphericEnvironment.springDusk);
      expect(spring.radarPrimaryAccent, const Color(0xFFFF4D67)); // Romantic Sunset Rose
      expect(spring.radarSecondaryAccent, const Color(0xFF7928CA)); // Electric Iris
      expect(spring.backgroundGradient.colors.first, const Color(0xFF120516));
    });

    test('AtmosphericDestinationsRegistry contains all required destination metadata', () {
      final destinations = AtmosphericDestinationsRegistry.defaultDestinations;
      expect(destinations.length, greaterThanOrEqualTo(4));

      // 1. Snow (Manali)
      expect(destinations[0].formattedPillText, contains('Solang Valley, Manali'));
      expect(destinations[0].environment, AtmosphericEnvironment.snow);

      // 2. Snow (Banff)
      expect(destinations[1].formattedPillText, contains('Banff National Park, Canada'));
      expect(destinations[1].environment, AtmosphericEnvironment.snow);

      // 3. Spring Dusk (Tokyo)
      expect(destinations[2].formattedPillText, contains('Meguro River, Tokyo'));
      expect(destinations[2].environment, AtmosphericEnvironment.springDusk);

      // 4. Rain (Mumbai)
      expect(destinations[3].formattedPillText, contains('Marine Drive, Mumbai'));
      expect(destinations[3].environment, AtmosphericEnvironment.rain);
    });
  });

  group('Atmospheric Particle Painters Rendering & Zero Memory Churn Tests', () {
    test('SnowCanvasPainter paints 85 snowflakes without error', () {
      final flakes = <SnowFlake>[];
      for (int i = 0; i < 85; i++) {
        flakes.add(SnowFlake(
          x: 100.0 + i,
          y: 200.0 + i,
          depth: SnowDepth.front,
          radius: 3.5,
          opacity: 0.8,
          speed: 35.0,
          swayFrequency: 1.0,
          swayAmplitude: 12.0,
          swayPhase: 0.5,
        ));
      }

      final painter = SnowCanvasPainter(flakes: flakes, time: 1.25);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('RainCanvasPainter paints rain streaks and splashes without error', () {
      final rainDrops = <RainDrop>[
        RainDrop(x: 50, y: 100, length: 22, speed: 450, opacity: 0.8, width: 1.2),
      ];
      final splashes = <RippleSplash>[
        RippleSplash(x: 50, y: 700, radius: 2.0, opacity: 0.65),
      ];

      final painter = RainCanvasPainter(rainDrops: rainDrops, splashes: splashes);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('AutumnFoliagePainter paints tumbling maple and oak leaves without error', () {
      final leaves = <AutumnLeaf>[
        AutumnLeaf(
          x: 100,
          y: 100,
          size: 15,
          rotation: 0.5,
          rotationSpeed: 1.0,
          tumblePhase: 0.2,
          tumbleSpeed: 1.5,
          speedX: 25,
          speedY: 45,
          color: const Color(0xFFF59E0B),
          isMaple: true,
        ),
      ];

      final painter = AutumnFoliagePainter(leaves: leaves, time: 2.0);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('SakuraPetalsPainter paints fluttering petals without error', () {
      final petals = <SakuraPetal>[
        SakuraPetal(
          x: 150,
          y: 150,
          size: 12,
          rotation: 0.8,
          rotationSpeed: 0.9,
          swayPhase: 0.3,
          speed: 30,
          color: const Color(0xFFFFB7B2),
        ),
      ];

      final painter = SakuraPetalsPainter(petals: petals, time: 3.0);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 800));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('WelcomeScreen Atmospheric Engine & Weather Pill Tests', () {
    testWidgets('WelcomeScreen renders Manali Snow Mode by default with single non-overlapping pill text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(
            initialDestinationIndex: 0,
            isDemoPreviewMode: false,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // 1. AtmosphericParticleCanvas is active
      expect(find.byType(AtmosphericParticleCanvas), findsOneWidget);

      // 2. Formatted pill text: [Weather Icon] [Temperature] · [Destination/Region]
      expect(find.textContaining('Solang Valley, Manali'), findsOneWidget);

      // 3. Aura brand logo
      expect(find.text('Aura'), findsOneWidget);

      // 4. Solid white Continue with Google CTA button & Continue with Apple CTA
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Use Phone Number / OTP'), findsOneWidget);

      // 5. Compliance footer
      expect(
        find.text('18+ Only · DPDP & PIPEDA Encrypted · Zero Screenshot Guarantee'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping the top location pill cycles immediately through all 4 themes cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: WelcomeScreen(
            initialDestinationIndex: 0,
            isDemoPreviewMode: false,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      // 1. Manali (Snow)
      expect(find.textContaining('Solang Valley, Manali'), findsOneWidget);

      // Tap pill -> 2. Mumbai (Rain)
      await tester.tap(find.textContaining('Solang Valley, Manali'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Banff'), findsOneWidget);

      // Tap pill -> 3. Montreal (Autumn)
      await tester.tap(find.textContaining('Banff'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Tokyo'), findsOneWidget);

      // Tap pill -> 4. Tokyo (Spring Dusk)
      await tester.tap(find.textContaining('Tokyo'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Mumbai'), findsOneWidget);
    });
  });
}
