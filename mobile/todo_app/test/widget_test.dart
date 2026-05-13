import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const TodoApp());
    expect(find.text('Список задач'), findsOneWidget);
  });
}
