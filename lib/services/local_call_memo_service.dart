import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalCallMemoService {
  LocalCallMemoService._();
  static final instance = LocalCallMemoService._();

  Map<String, String>? _cache;

  Future<String?> getMemo(String callId) async {
    final key = callId.trim();
    if (key.isEmpty) return null;
    final map = await _readAll();
    final value = map[key];
    if (value == null) return null;
    return value;
  }

  Future<void> setMemo(String callId, String memo) async {
    final key = callId.trim();
    if (key.isEmpty) return;
    final map = await _readAll();
    final value = memo;
    if (value.trim().isEmpty) {
      map.remove(key);
    } else {
      map[key] = value;
    }
    await _writeAll(map);
  }

  Future<void> removeMemo(String callId) async {
    final key = callId.trim();
    if (key.isEmpty) return;
    final map = await _readAll();
    map.remove(key);
    await _writeAll(map);
  }

  Future<Map<String, String>> _readAll() async {
    if (_cache != null) return _cache!;
    final file = await _memoFile();
    if (!await file.exists()) {
      _cache = <String, String>{};
      return _cache!;
    }
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        _cache = <String, String>{};
        return _cache!;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _cache = <String, String>{};
        return _cache!;
      }
      _cache = decoded.map((key, value) => MapEntry(key, '$value'));
      return _cache!;
    } catch (_) {
      _cache = <String, String>{};
      return _cache!;
    }
  }

  Future<void> _writeAll(Map<String, String> map) async {
    _cache = Map<String, String>.from(map);
    final file = await _memoFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_cache));
  }

  Future<File> _memoFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/call_memos.json');
  }
}
