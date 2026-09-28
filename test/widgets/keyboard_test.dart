import 'package:av_pointage/presentation/screens/services/kilometrage_required_screen.dart';
import 'package:av_pointage/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../visual/fake_data.dart';
import '../visual/visual_harness.dart';

const _screen = Size(390, 844);

/// Clavier de 300 dp (valeurs physiques : `pumpScreen` rend en × 3).
void _openKeyboard(WidgetTester tester) {
  tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
}

void main() {
  testWidgets('should_keep_dock_button_above_keyboard_when_keyboard_opens',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpScreen(
      tester,
      AppPage(
        title: 'Test',
        body: const AppScrollView(children: [TextField()]),
        dock: AppDock(
          actions: [
            DockAction(label: 'Valider', icon: Icons.check, onPressed: () {}),
          ],
        ),
      ),
    );
    expect(tester.getRect(find.text('Valider')).bottom, greaterThan(700));

    _openKeyboard(tester);
    await tester.pump();

    expect(
      tester.getRect(find.text('Valider')).bottom,
      lessThanOrEqualTo(_screen.height - 300),
    );
  });

  testWidgets(
      'should_show_validate_button_and_field_above_keyboard_on_kilometrage',
      (tester) async {
    addTearDown(tester.view.reset);
    await setUpApp(user: fakeUser(), routes: [
      FakeRoute('GET', '/vehicules', (_, _) {
        return {'success': true, 'vehicules': vehicules};
      }),
    ]);
    await pumpScreen(tester, const KilometrageRequiredScreen(isRequired: true));

    final field = find.widgetWithText(TextFormField, 'Ex. 125000');
    await tester.tap(field);
    _openKeyboard(tester);
    await settle(tester);

    final keyboardTop = _screen.height - 300;
    final button = tester.getRect(find.text('Valider le kilométrage'));
    expect(button.bottom, lessThanOrEqualTo(keyboardTop));
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(button.top));
  });

  testWidgets('should_close_keyboard_on_tap_outside_but_not_on_scroll',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardTapOutside(child: child!),
        home: Scaffold(
          body: ListView(
            children: [
              TextField(focusNode: focus),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    // Faire défiler la page ne ferme pas le clavier.
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -100));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    // Toucher ailleurs le ferme.
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
