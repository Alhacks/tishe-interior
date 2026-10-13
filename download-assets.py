from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import urllib.parse
import urllib.request

root = Path(__file__).parent / 'dist'
assets = root / 'assets'
assets.mkdir(parents=True, exist_ok=True)
photos = {
    'hero': 'photo-1600210492486-724fe5c67fb0',
    'apartment': 'photo-1600607687920-4e2a09cf159d',
    'detail': 'photo-1600566753190-17f0baa2a6c3',
    'studio': 'photo-1600210491892-03d54c0aaf87',
}
font_url = 'https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;1,400;1,500&family=Manrope:wght@400;500;600;700&display=swap'

def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(request, timeout=45) as response:
        return response.read()

def photo_url(name, photo):
    width = '2200' if name == 'hero' else '1400'
    return f'https://images.unsplash.com/{photo}?auto=format&fit=crop&w={width}&q=85'

def download_photo(item):
    name, photo = item
    target = assets / f'{name}.jpg'
    if not target.exists():
        data = fetch(photo_url(name, photo))
        if len(data) < 1024:
            raise ValueError(f'Image response is too small: {name}')
        target.write_bytes(data)
    print(name, target.stat().st_size, flush=True)

with ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(download_photo, photos.items()))

font_css = assets / 'fonts.css'
if not font_css.exists():
    css = fetch(font_url).decode('utf-8')
    urls = list(dict.fromkeys(re.findall(r'url\(([^)]+)\)', css)))
    for index, url in enumerate(urls):
        remote_url = url.strip("'\"")
        suffix = Path(urllib.parse.urlparse(remote_url).path).suffix or '.woff2'
        filename = f'font-{index}{suffix}'
        (assets / filename).write_bytes(fetch(remote_url))
        css = css.replace(url, './' + filename)
    font_css.write_text(css, encoding='utf-8')
    print(f'Fonts downloaded: {len(urls)}', flush=True)

index_path = root / 'index.html'
markup = index_path.read_text(encoding='utf-8')
for name, photo in photos.items():
    markup = markup.replace(photo_url(name, photo), f'assets/{name}.jpg')
markup = markup.replace(font_url, 'assets/fonts.css')
markup = re.sub(r'  <link rel="preconnect" href="https://fonts\.(?:googleapis|gstatic)\.com"[^>]*>\n', '', markup)
index_path.write_text(markup, encoding='utf-8')
print('Website now uses locally hosted photos and fonts.', flush=True)
