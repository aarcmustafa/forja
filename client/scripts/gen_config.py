#!/usr/bin/env python3
import os
import base64
import sys

key = bytes([0x7A, 0x3F, 0x91, 0x2C, 0xE5, 0x88, 0x4B, 0xD6, 0x13, 0x6A, 0xBF, 0x50, 0x27, 0x9E, 0xC4, 0x71, 0xA2, 0x5D, 0x38, 0x94, 0xCB, 0x1F, 0x66, 0xD9])

urls_raw = os.environ.get('PLAYLIST_URLS', '')
urls = [u.strip() for u in urls_raw.split('\n') if u.strip()]

if not urls:
    print('ERROR: no URLs', file=sys.stderr)
    sys.exit(1)

lines = []
lines.append("import 'dart:convert';")
lines.append('')
lines.append('class SecureConfig {')
lines.append('  static const List<int> _k = [')
lines.append('    ' + ', '.join(f'0x{b:02X}' for b in key) + ',')
lines.append('  ];')
lines.append('')
lines.append('  static const List<List<String>> _parts = [')

for url in urls:
    url_bytes = url.encode('utf-8')
    xored = bytes([url_bytes[i] ^ key[i % len(key)] for i in range(len(url_bytes))])
    b64 = base64.b64encode(xored).decode('ascii')
    n = len(b64)
    chunk = (n + 2) // 3
    parts = [b64[i:i+chunk] for i in range(0, n, chunk)]
    while len(parts) < 3:
        parts.append('')
    lines.append("    ['" + "', '".join(parts) + "'],")

lines.append('  ];')
lines.append('')
lines.append('  static String _decode(List<String> p) {')
lines.append('    try {')
lines.append('      final bytes = base64Decode(p.join());')
lines.append('      final out = <int>[];')
lines.append('      for (int i = 0; i < bytes.length; i++) {')
lines.append('        out.add(bytes[i] ^ _k[i % _k.length]);')
lines.append('      }')
lines.append('      return utf8.decode(out, allowMalformed: true);')
lines.append('    } catch (_) {')
lines.append("      return '';")
lines.append('    }')
lines.append('  }')
lines.append('')
lines.append('  static List<String> getPlaylistUrls() {')
lines.append('    final r = <String>[];')
lines.append('    for (final p in _parts) {')
lines.append('      final u = _decode(p);')
lines.append('      if (u.isNotEmpty) r.add(u);')
lines.append('    }')
lines.append('    return r;')
lines.append('  }')
lines.append('')
lines.append('  static List<String>? _cache;')
lines.append('  static List<String> get urls {')
lines.append('    _cache ??= getPlaylistUrls();')
lines.append('    return _cache!;')
lines.append('  }')
lines.append('}')

print('\n'.join(lines))
