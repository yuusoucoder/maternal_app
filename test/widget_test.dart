import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aiovy/main.dart';
import 'package:aiovy/models/assessment_model.dart';
import 'package:aiovy/screens/danger_check_screen.dart';
import 'package:aiovy/screens/input_screen.dart';
import 'package:aiovy/screens/result_screen.dart';

void main() {
  group('Assessment.assess (hardcoded scoring)', () {
    test('clearly normal vitals → LOW', () {
      final r = Assessment.assess(
        age: 25,
        systolicBP: 110,
        diastolicBP: 70,
        bloodSugar: 5.5,
        temperature: 98.0,
        heartRate: 70,
      );
      expect(r.riskLevel, RiskLevel.low);
    });

    test('severe hypertension + high glucose → HIGH', () {
      final r = Assessment.assess(
        age: 38,
        systolicBP: 160,
        diastolicBP: 100,
        bloodSugar: 13,
        temperature: 98.6,
        heartRate: 80,
      );
      expect(r.riskLevel, RiskLevel.high);
      expect(r.features.first.featureName, 'Systolic BP');
    });

    test('features are sorted by absolute contribution', () {
      final r = Assessment.assess(
        age: 28,
        systolicBP: 120,
        diastolicBP: 80,
        bloodSugar: 6.5,
        temperature: 98.6,
        heartRate: 76,
      );
      final abs = r.features.map((f) => f.contribution.abs()).toList();
      for (var i = 1; i < abs.length; i++) {
        expect(abs[i - 1] >= abs[i], isTrue);
      }
      expect(r.features, hasLength(6));
    });
  });

  // The same end-to-end flow on a phone, a tablet and a desktop window.
  // Any layout overflow on any of them fails the test.
  const sizes = {
    'phone': Size(390, 844),
    'tablet': Size(820, 1180),
    'desktop': Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    testWidgets('flow works on ${entry.key}', (tester) async {
      SessionManager.clear();
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaternAIApp());
      expect(find.text('No assessments yet'), findsWidgets);

      // Desktop shows "New Assessment" in the side nav AND on the home
      // card; either one starts the flow.
      await tester.tap(find.text('New Assessment').first);
      await tester.pumpAndSettle();
      expect(find.byType(DangerCheckScreen), findsOneWidget);

      // Ticking a sign blocks the ML flow.
      final sign = find.text("Severe headache that won't go away");
      await tester.tap(sign);
      await tester.pumpAndSettle();
      expect(find.text('Immediate Referral Required'), findsOneWidget);
      await tester.tap(sign);
      await tester.pumpAndSettle();

      await tester.tap(find.text('No emergency signs — proceed →'));
      await tester.pumpAndSettle();
      expect(find.byType(InputScreen), findsOneWidget);
      expect(find.text('Case 1'), findsOneWidget);

      // Clinical info: bottom sheet on phones, dialog on wider screens.
      await tester.tap(find.text('Systolic BP'));
      await tester.pumpAndSettle();
      expect(find.text('Systolic Blood Pressure'), findsOneWidget);
      expect(
        find.byType(Dialog),
        entry.key == 'phone' ? findsNothing : findsOneWidget,
      );
      await tester.tapAt(const Offset(5, 5)); // tap outside to dismiss
      await tester.pumpAndSettle();

      final confirm = find.text('Confirm & View Full Results →');
      await tester.scrollUntilVisible(confirm, 300);
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsOneWidget);
      expect(SessionManager.count, 1);
      final disclaimer =
          find.textContaining('not replaces — clinical judgment');
      await tester.scrollUntilVisible(disclaimer, 300);
      expect(disclaimer, findsOneWidget);

      final home = find.text('Back to Home');
      await tester.scrollUntilVisible(home, 300);
      await tester.ensureVisible(home);
      await tester.pumpAndSettle();
      await tester.tap(home);
      await tester.pumpAndSettle();
      expect(find.text('Case 1'), findsWidgets);
    });
  }

  testWidgets('desktop uses side navigation, phone uses bottom bar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const MaternAIApp());
    expect(find.text('About Model'), findsOneWidget); // side-nav label
    expect(tester.getSize(find.byType(MainShell)).width, 1440);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('About Model'), findsNothing); // icon-only bottom bar
  });
}
