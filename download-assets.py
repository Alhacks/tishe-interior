from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import urllib.request, re
p = Path(__file__).parent / 'dist' / 'assets'
photos = {'hero':'photo-1600210492486-724fe5c67fb0', 'apartment':'photo-1600607687920-4e2a09cf159d', 'detail':'photo-1600566753190-17f0baa2a6c3', 'studio':'photo-1600210491892-03d54c0aaf87'}
def get(item):
    name, photo = item
    url = 'https://images.unsplash.com/' + photo + '?auto=format&fit=crop&w=' + ('2200' if name == 'hero' else '1400') + '&q=85'
    with urllib.request.urlopen(url, timeout=45) as r: data = r.read()
    (p / (name + '.jpg')).write_bytes(data)
    print(name, len(data))
with ThreadPoolExecutor(max_workers=4) as pool: list(pool.map(get, photos.items()))
req = urllib.request.Request('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;1,400;1,500&family=Manrope:wght@400;500;600;700&display=swap', headers={'User-Agent':'Mozilla/5.0'})
with urllib.request.urlopen(req, timeout=30) as r: css = r.read().decode()
for i, url in enumerate(dict.fromkeys(re.findall(r'url\(([^)]+)\)', css))):
    with urllib.request.urlopen(url, timeout=30) as r: data = r.read()
    name = f'font-{i}.woff2'
    (p / name).write_bytes(data)
    css = css.replace(url, './' + name)
(p / 'fonts.css').write_text(css)
print('Fonts downloaded')
