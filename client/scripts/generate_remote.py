#!/usr/bin/env python3
"""يولّد ملف playlists.enc من PLAYLIST_URLS"""

import os
import base64
import sys

key = bytes([
    0x7A, 0x3F, 0x91, 0x2C, 0xE5, 0x88, 0x4B, 0xD6,
    0x13, 0x6A, 0xBF, 0x50, 0x27, 0x9E, 0xC4, 0x71,
    0xA2, 0x5D, 0x38, 0x94, 0xCB, 0x1F, 0x66, 0xD9,
])

urls_raw = os.environ.get('PLAYLIST_URLS', '')
urls = [u.strip() for u in urls_raw.split('\n') if u.strip()]

if not urls:
    print('ERROR: no URLs found', file=sys.stderr)
    sys.exit(1)

text = '\n'.join(urls)
data = text.encode('utf-8')
xored = bytes([data[i] ^ key[i % len(key)] for i in range(len(data))])
b64 = base64.b64encode(xored).decode('ascii')

print(b64)
