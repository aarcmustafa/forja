import os

urls_env = os.environ.get('PLAYLIST_URLS', '')
urls = [url.strip() for url in urls_env.split(',') if url.strip()]

print("class SecureConfig {")
print("  static const List<String> urls = [")
for url in urls:
    print(f"    '{url}',")
print("  ];")
print("}")
