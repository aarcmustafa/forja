import os

urls_env = os.environ.get('PLAYLIST_URLS', '')
# فصل الروابط بناءً على الفاصلة، وإزالة المسافات الزائدة
urls = [url.strip() for url in urls_env.split(',') if url.strip()]

print("const List<List<String>> securePlaylists = [")
for url in urls:
    print(f"  ['{url}'],")
print("];")
