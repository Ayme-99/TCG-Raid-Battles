import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/app.dart';

void main() {
  testWidgets('la app arranca en el setup de la partida', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: IncursionesApp()));
    expect(find.text('Nueva partida'), findsOneWidget);
    expect(find.text('Jugadores y su mejor ataque'), findsOneWidget);
  });
}
