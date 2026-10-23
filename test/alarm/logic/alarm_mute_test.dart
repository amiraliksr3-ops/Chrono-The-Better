import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:clock_app/alarm/logic/alarm_isolate.dart';
import 'package:clock_app/alarm/logic/alarm_mute.dart';
import 'package:clock_app/alarm/widgets/alarm_mute_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReceivePort? mutePort;
  final received = <List<dynamic>>[];

  setUp(() {
    // Short countdown so tests don't have to wait 30 seconds.
    AlarmMuteController.debugMuteDuration = const Duration(milliseconds: 100);
    IsolateNameServer.removePortNameMapping(alarmMutePortName);
    mutePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
        mutePort!.sendPort, alarmMutePortName);
    received.clear();
    mutePort!.listen((message) => received.add(message as List<dynamic>));
  });

  tearDown(() {
    AlarmMuteController.instance.cancel();
    AlarmMuteController.debugMuteDuration = null;
    IsolateNameServer.removePortNameMapping(alarmMutePortName);
    mutePort?.close();
    mutePort = null;
  });

  test('start sends mute message and auto-unmutes when countdown expires',
      () async {
    AlarmMuteController.instance.setTargetVolume(70);
    AlarmMuteController.instance.start();

    expect(AlarmMuteController.instance.isMuted, isTrue);

    // Port messages are delivered asynchronously.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(received, isNotEmpty);
    expect(received.first[0], 'mute');
    expect(received.first[2], 70);

    // Wait long enough for the 100 ms countdown to expire.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(AlarmMuteController.instance.isMuted, isFalse);
    var unmuteMessages =
        received.where((message) => message[0] == 'unmute').toList();
    expect(unmuteMessages, hasLength(1));
    // The unmute message carries the stored target volume and fade seconds.
    expect(unmuteMessages[0][1], 70);
    expect(unmuteMessages[0][2], 5);
  });

  test('mission interaction extends the countdown', () async {
    AlarmMuteController.instance.start();
    // Restart the countdown before it expires.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    AlarmMuteController.instance.interact();

    // 25 ms later the original +100 ms deadline has passed, but the renewed
    // one (ending at +150 ms) is still running.
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(AlarmMuteController.instance.isMuted, isTrue);
    expect(received.where((m) => m[0] == 'renew'), hasLength(1));

    // The renewed countdown expires after another 100 ms plus margin.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(AlarmMuteController.instance.isMuted, isFalse);
  });

  test('cancel ends the mute without an unmute message', () async {
    AlarmMuteController.instance.start();
    AlarmMuteController.instance.cancel();

    expect(AlarmMuteController.instance.isMuted, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(received.where((m) => m[0] == 'unmute'), isEmpty);
  });

  testWidgets('mute bar shows while muted and hides when cancelled',
      (WidgetTester tester) async {
    // Keep the countdown long enough to outlive the test pumps.
    AlarmMuteController.debugMuteDuration = const Duration(seconds: 30);
    AlarmMuteController.instance.start();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: const Stack(
          children: [Align(alignment: Alignment.topCenter, child: AlarmMuteBar())],
        ),
      ),
    ));

    expect(find.byType(FractionallySizedBox), findsOneWidget);

    AlarmMuteController.instance.cancel();
    await tester.pump();

    expect(find.byType(FractionallySizedBox), findsNothing);
  });
}
