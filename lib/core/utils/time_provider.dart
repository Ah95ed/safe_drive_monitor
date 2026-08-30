/// Abstract interface for clock time, enabling predictable unit tests.
abstract class TimeProvider {
  DateTime now();
}

/// Default system clock provider.
class SystemTimeProvider implements TimeProvider {
  const SystemTimeProvider();

  @override
  DateTime now() => DateTime.now();
}
