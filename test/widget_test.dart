import 'package:bi_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BiApp muestra el proyecto Firebase conectado', (tester) async {
    await tester.pumpWidget(const BiApp(projectId: 'bi-app-ae0d1'));

    expect(find.textContaining('bi-app-ae0d1'), findsOneWidget);
  });
}
