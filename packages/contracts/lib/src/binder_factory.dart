import 'binder.dart';

/// Фабрика для создания Binder.
/// Позволяет подменять реализацию DI контейнера (например, на GetItBinder или SimpleBinder).
abstract class BinderFactory {
  Binder create([Binder? parent]);
}
