# app/

App Flutter para tablet ("tablet en medio de la mesa"). Es una interfaz fina: toda la lógica vive en `engine/`.

Se crea con `flutter create` cuando llegue la tarjeta T-10:

```
cd app
flutter create . --org dev.ayme99 --project-name incursiones_app
```
Después se añade `engine` como dependencia local (`path: ../engine`).
