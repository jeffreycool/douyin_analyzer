import 'package:flutter_test/flutter_test.dart';

import 'package:douyin_analyzer/main.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const DouyinAnalyzerApp());
    expect(find.text('Douyin Analyzer'), findsOneWidget);
  });
}
