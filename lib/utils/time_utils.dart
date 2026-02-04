import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TimeUtils {
  TimeUtils._();

  static bool _initialized = false;
  static final tz.Location _eastern = tz.getLocation('America/New_York');

  static void initialize() {
    if (_initialized) return;
    tz.initializeTimeZones();
    _initialized = true;
  }

  static tz.TZDateTime nowEt() {
    _ensureInitialized();
    return tz.TZDateTime.now(_eastern);
  }

  static tz.TZDateTime toEt(DateTime input) {
    _ensureInitialized();
    return tz.TZDateTime.from(input, _eastern);
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    initialize();
  }
}
