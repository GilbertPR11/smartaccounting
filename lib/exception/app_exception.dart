/// A business-rule violation the user can understand and fix.
/// Repositories throw this; Blocs catch it and put [message] in their state.
/// Anything else that's thrown is a bug and should surface as one.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
