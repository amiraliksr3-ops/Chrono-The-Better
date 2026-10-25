import 'package:clock_app/settings/types/setting.dart';
import 'package:clock_app/settings/widgets/slider_setting_card.dart';
import 'package:clock_app/system/logic/system_volume.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel channel = MethodChannel('com.vicolo.chrono/alarm');

/// A stand-in for Android's alarm stream: 7 steps, which Android shows as
/// 14% through 100%, holding the value the same way the platform handlers do
/// (rounding what it is asked for to the nearest step it has).
class FakeAlarmStream {
  int index = 3;
  final List<double> setCalls = [];
  int getCalls = 0;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'getSystemVolume':
        getCalls++;
        return {'percent': index * 100.0 / 7, 'min': 1, 'max': 7};
      case 'setSystemVolume':
        final percent = (call.arguments as Map)['percent'] as double;
        setCalls.add(percent);
        index = (percent / 100 * 7).round().clamp(1, 7);
        return index * 100.0 / 7;
      default:
        return null;
    }
  }
}

/// The alarm volume slider wired exactly like alarm_settings_schema.dart.
SliderSetting volumeSetting() => SliderSetting(
      'Volume',
      (context) => 'Volume',
      0,
      100,
      100,
      unit: '%',
      systemValue: getSystemVolume,
      integerDisplay: true,
      onChange: (context, value) => setSystemVolume(value),
    );

void main() {
  late FakeAlarmStream stream;

  setUp(() {
    stream = FakeAlarmStream();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, stream.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> renderCard(WidgetTester tester, SliderSetting setting) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SliderSettingCard(setting: setting)),
    ));
    // Let the mirror read from Android finish before asserting on the grid.
    await tester.pumpAndSettle();
  }

  /// Lets the debounced read-back run and the frame it schedules render.
  Future<void> settleReadBack(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  group('SliderSettingCard', () {
    testWidgets('shows only the steps Android has, as whole numbers',
        (tester) async {
      final setting = volumeSetting();
      await renderCard(tester, setting);

      final slider = tester.widget<Slider>(find.byType(Slider));
      // Android's first step (1 of 7) up to its last, one position per step.
      expect(slider.min, closeTo(100 / 7, 0.001));
      expect(slider.max, 100);
      expect(slider.divisions, 6);
      // The slider mirrors Android's current step: 3 of 7 = 42.857...%.
      expect(slider.value, closeTo(300 / 7, 0.001));
      expect(setting.value, closeTo(300 / 7, 0.001));
      // Shown rounded: 42.857... reads as 43, never as 42.9.
      expect(find.text('43'), findsOneWidget);

      expect(stream.getCalls, 1);
      expect(stream.setCalls, isEmpty);
    });

    testWidgets('dragging moves Android\'s volume to a step it has',
        (tester) async {
      final setting = volumeSetting();
      await renderCard(tester, setting);

      await tester.drag(find.byType(Slider), const Offset(300.0, 0.0));
      await tester.pump();

      expect(stream.setCalls, isNotEmpty);
      final asked = stream.setCalls.last;
      expect(asked, greaterThan(300 / 7));
      // Whatever was asked for lands on a real Android step.
      expect((asked * 7 / 100) - (asked * 7 / 100).round(), closeTo(0, 0.001));

      // The read-back shows the value Android stored.
      await settleReadBack(tester);
      expect(setting.value, closeTo(stream.index * 100 / 7, 0.001));
      expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          closeTo(stream.index * 100 / 7, 0.001));
    });

    testWidgets('a typed value snaps to the step Android stores',
        (tester) async {
      final setting = volumeSetting();
      await renderCard(tester, setting);

      await tester.enterText(find.byType(TextField), '20');
      await tester.pump();
      expect(stream.setCalls, [20]);

      // Android only has whole steps: it rounds 20% down to step 1 of 7.
      await settleReadBack(tester);
      expect(stream.index, 1);
      expect(setting.value, closeTo(100 / 7, 0.001));
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('keeps the stored value when Android cannot be read',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'unavailable');
      });

      final setting = volumeSetting();
      await renderCard(tester, setting);

      // Android's default steps (1 of 7) are used for the grid...
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, closeTo(100 / 7, 0.001));
      expect(slider.divisions, 6);
      // ...but nothing overwrites the value the alarm already has.
      expect(setting.value, 100);
      expect(find.text('100'), findsOneWidget);
      expect(stream.setCalls, isEmpty);
    });

    testWidgets('sliders without a system hook keep their own snapping',
        (tester) async {
      final setting = SliderSetting(
        'Lead Time',
        (context) => 'Lead Time',
        0,
        60,
        15,
        snapLength: 5,
      );
      await renderCard(tester, setting);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 0);
      expect(slider.divisions, 12);
      expect(setting.value, 15);
      expect(stream.getCalls, 0);
      expect(stream.setCalls, isEmpty);
    });
  });
}
