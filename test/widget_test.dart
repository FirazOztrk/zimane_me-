import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zimane_me/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('splash requires avatar selection before start', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ZimaneMeApp()));
    await tester.pumpAndSettle();

    expect(find.text('Ziman\u00EA Me'), findsOneWidget);
    expect(find.text('DEST P\u00CA BIKE'), findsOneWidget);

    final Finder startButton = find.byKey(const ValueKey('start_button'));
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.text('Nex\u015Fe'), findsNothing);
  });

  testWidgets('all main buttons are working across splash, map and game', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ZimaneMeApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('avatar_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('start_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Mal'), findsWidgets);
    expect(find.text('Xelat'), findsWidgets);
    expect(find.text('Nex\u015Fe'), findsWidgets);
    expect(find.text('Saz\u00EE'), findsWidgets);
    expect(find.text('Heywan'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Mal').first);
    await tester.pump();
    expect(find.text('Bi xosh hati'), findsOneWidget);

    await tester.tap(find.text('Xelat').first);
    await tester.pump();
    expect(find.text('Qonax\u00EAn qediyay\u00EE: 0'), findsOneWidget);

    await tester.tap(find.text('Saz\u00EE').first);
    await tester.pump();
    expect(find.text('M\u00EEheng \u00FB deng'), findsOneWidget);

    await tester.tap(find.text('Nex\u015Fe').first);
    await tester.pump();
    expect(find.byKey(const ValueKey('level_node_0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('level_node_tap_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('play_audio_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('start_quiz_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play_audio_button')));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey('game_back_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('level_node_0')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('level_node_tap_0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    for (int i = 0; i < 8; i++) {
      if (find
          .byKey(const ValueKey('complete_return_button'))
          .evaluate()
          .isNotEmpty) {
        break;
      }

      if (find
          .byKey(const ValueKey('start_quiz_button'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('start_quiz_button')));
        await tester.pump();
      }

      if (find.byKey(const ValueKey('quiz_option_0')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('quiz_option_0')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
      } else {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    expect(find.text('Afer\u00EEn!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('complete_return_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('complete_return_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Xelat').first);
    await tester.pump();
    expect(find.text('Qonax\u00EAn qediyay\u00EE: 1'), findsOneWidget);
  });
}
