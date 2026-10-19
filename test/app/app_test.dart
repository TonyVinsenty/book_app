import 'package:book_app/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts and shows Russian placeholder', (tester) async {
    await tester.pumpWidget(const BookApp());
    await tester.pumpAndSettle();

    expect(find.text('Здесь появятся ваши книги'), findsOneWidget);
  });
}
