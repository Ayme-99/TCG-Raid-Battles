import 'package:flutter_test/flutter_test.dart';
import 'package:incursiones_app/almacen/almacen.dart';
import 'package:incursiones_app/envios/cola_envios.dart';

Map<String, Object?> registro(String id) => {
      'version': 2,
      'partidaId': id,
      'eventos': <Object?>[],
    };

void main() {
  test('encolar guarda la partida y no la duplica', () async {
    final cola = ColaEnvios(AlmacenMemoria());
    await cola.encolar(registro('a'));
    await cola.encolar(registro('a'));
    await cola.encolar(registro('b'));
    expect((await cola.pendientes()).map((e) => e.partidaId), ['a', 'b']);
  });

  test('la cola sobrevive a crear otra instancia sobre el mismo almacén',
      () async {
    final almacen = AlmacenMemoria();
    await ColaEnvios(almacen).encolar(registro('a'));
    expect((await ColaEnvios(almacen).pendientes()).single.partidaId, 'a');
  });

  test('quitar saca la partida de la cola', () async {
    final cola = ColaEnvios(AlmacenMemoria());
    await cola.encolar(registro('a'));
    await cola.encolar(registro('b'));
    await cola.quitar('a');
    expect((await cola.pendientes()).map((e) => e.partidaId), ['b']);
  });

  test('registrarFallo cuenta los intentos de esa partida', () async {
    final cola = ColaEnvios(AlmacenMemoria());
    await cola.encolar(registro('a'));
    await cola.encolar(registro('b'));
    expect(await cola.registrarFallo('a'), 1);
    expect(await cola.registrarFallo('a'), 2);
    final pendientes = await cola.pendientes();
    expect(pendientes.first.intentos, 2);
    expect(pendientes.last.intentos, 0);
  });

  test('rechazar aparta la partida con el motivo y no se vuelve a encolar',
      () async {
    final cola = ColaEnvios(AlmacenMemoria());
    await cola.encolar(registro('a'));
    await cola.rechazar('a', 'el resumen no cuadra');
    expect(await cola.pendientes(), isEmpty);
    final rechazadas = await cola.rechazadas();
    expect(rechazadas.single.partidaId, 'a');
    expect(rechazadas.single.error, 'el resumen no cuadra');

    await cola.encolar(registro('a'));
    expect(await cola.pendientes(), isEmpty);

    await cola.descartarRechazadas();
    expect(await cola.rechazadas(), isEmpty);
  });

  test('un almacén estropeado se lee como cola vacía', () async {
    final almacen = AlmacenMemoria()..datos['envios_pendientes'] = 'no es json';
    expect(await ColaEnvios(almacen).pendientes(), isEmpty);
  });

  test('la espera entre reintentos crece y tiene tope', () {
    expect(esperaTrasFallo(1), const Duration(seconds: 30));
    expect(esperaTrasFallo(2), const Duration(minutes: 1));
    expect(esperaTrasFallo(3), const Duration(minutes: 2));
    expect(esperaTrasFallo(6), const Duration(minutes: 15));
    expect(esperaTrasFallo(50), const Duration(minutes: 15));
    expect(esperaTrasFallo(0), const Duration(seconds: 30));
  });
}
