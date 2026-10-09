import 'package:bsciapp/main.dart';
import 'package:bsciapp/screens/journal_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public dashboard fits an iPhone-sized viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp(hasToken: false));
    await tester.pump();

    expect(find.text('BSCI'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal details reader fits an iPhone-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: JournalDetailScreen(
          publication: {
            'title': 'BSCI Cardiovascular Intervention Review',
            'authors': 'BSCI Research Team',
            'issue_volume': 'Volume 1, Issue 1',
            'article_type': 'research',
            'abstract': 'A structured abstract for iPhone layout validation.',
            'description': 'Clinical study overview.',
            'views_count': 12,
            'downloads_count': 4,
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Article Details'), findsOneWidget);
    expect(find.text('PDF Reader'), findsOneWidget);
    expect(find.text('12 Views'), findsOneWidget);
    expect(find.text('4 Downloads'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
