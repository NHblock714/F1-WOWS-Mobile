import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// JSON 文件缓存 (与 PC 端 cache.Cache 等价).
/// Key 用文件名, 带 TTL 检查.
class Cache {
  static Cache? _instance;
  static Cache get instance => _instance ??= Cache._();

  Cache._();

  Directory? _dir;

  Future<Directory> _getDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    _dir = Directory('${base.path}/cache');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    return _dir!;
  }

  File _file(Directory dir, String key) => File('${dir.path}/$key.json');

  Future<T?> get<T>(String key, Duration ttl) async {
    try {
      final dir = await _getDir();
      final file = _file(dir, key);
      if (!await file.exists()) return null;
      final age = DateTime.now().difference(await file.lastModified());
      if (age > ttl) return null;
      final raw = await file.readAsString();
      return jsonDecode(raw) as T?;
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String key, dynamic value) async {
    final dir = await _getDir();
    final file = _file(dir, key);
    await file.writeAsString(jsonEncode(value));
  }

  Future<void> clear() async {
    final dir = await _getDir();
    if (await dir.exists()) {
      await for (final f in dir.list()) {
        if (f is File) await f.delete();
      }
    }
  }

  Future<Map<String, Duration>> ages() async {
    final dir = await _getDir();
    final result = <String, Duration>{};
    if (!await dir.exists()) return result;
    await for (final f in dir.list()) {
      if (f is File) {
        final key = f.path.split(Platform.pathSeparator).last.replaceAll('.json', '');
        result[key] = DateTime.now().difference(await f.lastModified());
      }
    }
    return result;
  }
}
