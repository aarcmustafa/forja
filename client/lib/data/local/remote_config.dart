import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// يجلب الروابط المشفّرة من GitHub
class RemoteConfig {
  static const String remoteUrl =
      'https://raw.githubusercontent.com/aarcmustafa/forja/main/client/assets/remote/playlists.enc';

  static const String _boxName = 'remote_config';
  static const String _kCachedUrls = 'cached_urls';
  static const String _kLastUpdate = 'last_update';

  static const List<int> _key = [
    0x7A, 0x3F, 0x91, 0x2C, 0xE5, 0x88, 0x4B, 0xD6,
    0x13, 0x6A, 0xBF, 0x50, 0x27, 0x9E, 0xC4, 0x71,
    0xA2, 0x5D, 0x38, 0x94, 0xCB, 0x1F, 0x66, 0xD9,
  ];

  Box? _box;
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox(_boxName);
      _initialized = true;
    } catch (_) {}
  }

  Future<List<String>> loadCached() async {
    await _init();
    if (_box == null) return [];
    try {
      final raw = _box!.get(_kCachedUrls);
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  /// ✅ مهلة قصيرة 5 ثوانٍ (كما اقترح pcapDroid)
  Future<List<String>?> fetchRemote() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final ts = DateTime.now().millisecondsSinceEpoch;
      final response = await dio.get<String>(
        '$remoteUrl?t=$ts',
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final urls = _decodeContent(response.data!);
      if (urls.isEmpty) return null;

      await _saveToCache(urls);
      return urls;
    } catch (_) {
      return null;
    }
  }

  List<String> _decodeContent(String content) {
    try {
      final trimmed = content.trim();
      final bytes = base64Decode(trimmed);

      final decoded = <int>[];
      for (int i = 0; i < bytes.length; i++) {
        decoded.add(bytes[i] ^ _key[i % _key.length]);
      }

      final text = utf8.decode(decoded, allowMalformed: true);
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveToCache(List<String> urls) async {
    await _init();
    if (_box == null) return;
    try {
      await _box!.put(_kCachedUrls, urls);
      await _box!.put(_kLastUpdate, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  DateTime? getLastUpdate() {
    if (_box == null) return null;
    final ts = _box!.get(_kLastUpdate);
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts as int);
  }
}
