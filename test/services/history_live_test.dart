import 'package:av_pointage/presentation/screens/services/history_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/fake_data.dart';
import '../visual/fake_services.dart';
import '../visual/visual_harness.dart';

void main() {
  testWidgets('should_show_net_time_when_day_has_30_min_break', (tester) async {
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime at(DateTime day, int h, [int m = 0]) =>
        DateTime(day.year, day.month, day.day, h, m);

    await setUpApp(
      user: fakeUser(),
      routes: [
        FakeRoute('GET', '/services/month', (_, _) => [
          // Service de nuit de la veille : sa pause après minuit reste à hier.
          fakeWorkService(
            'night',
            at(yesterday, 21),
            now: now,
            fin: at(today, 5),
            pauses: [(at(today, 1), at(today, 2))],
          ),
          fakeWorkService(
            'day',
            at(today, 8),
            now: now,
            fin: at(today, 16),
            pauses: [(at(today, 12), at(today, 12, 30))],
          ),
        ]),
      ],
    );

    await pumpScreen(tester, const HistoryScreen());

    expect(find.text('7h30 travaillées · 1 pause'), findsOneWidget);
    // Fil du jour : le service et sa pause (la légende porte aussi les mots).
    expect(find.text('Service'), findsNWidgets(2));
    expect(find.text('Pause'), findsNWidgets(2));
    expect(find.text('08:00 → 16:00'), findsOneWidget);
    expect(find.text('12:00 → 12:30'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
