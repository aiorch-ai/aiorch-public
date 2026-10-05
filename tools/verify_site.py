"""Check discoverability and linked website assets without third-party packages."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import json
import re
import sys
import xml.etree.ElementTree as ET
from urllib.robotparser import RobotFileParser

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = 'https://aiorch.ai'
ERRORS = []


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids = set()
        self.links = []
        self.canonical = []
        self.descriptions = []
        self.robots = ''
        self.h1 = 0
        self.title = ''
        self.in_title = False
        self.in_json = False
        self.json_text = ''
        self.json_blocks = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if 'id' in a:
            if a['id'] in self.ids:
                ERRORS.append(f'{self.path.relative_to(ROOT)}: duplicate id {a["id"]}')
            self.ids.add(a['id'])
        if tag == 'h1':
            self.h1 += 1
        if tag == 'title':
            self.in_title = True
        if tag == 'script' and a.get('type') == 'application/ld+json':
            self.in_json = True
            self.json_text = ''
        if tag == 'link' and a.get('rel') == 'canonical':
            self.canonical.append(a.get('href', ''))
        if tag == 'meta' and a.get('name') == 'description':
            self.descriptions.append(a.get('content', ''))
        if tag == 'meta' and a.get('name') == 'robots':
            self.robots = a.get('content', '')
        for key in ('href', 'src'):
            if key in a:
                self.links.append(a[key])
        if tag == 'meta' and a.get('property') == 'og:image':
            self.links.append(a.get('content', ''))

    def handle_data(self, data):
        if self.in_title:
            self.title += data
        if self.in_json:
            self.json_text += data

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False
        if tag == 'script' and self.in_json:
            self.json_blocks.append(json.loads(self.json_text))
            self.in_json = False


def resolve(path):
    raw = ROOT / unquote(path).lstrip('/')
    if raw.is_dir():
        return raw / 'index.html'
    if raw.is_file():
        return raw
    if not raw.suffix and raw.with_suffix('.html').is_file():
        return raw.with_suffix('.html')
    return None


files = [ROOT / name for name in ('index.html', 'privacy.html', 'terms.html', 'cookies.html', 'success.html', '404.html')]
files += sorted((ROOT / 'docs').glob('**/index.html'))
files += sorted((ROOT / 'guides').glob('**/index.html'))
pages = {path: Page(path) for path in files}
canonical = {}
titles = set()
for path, page in pages.items():
    name = str(path.relative_to(ROOT))
    if 'noindex' not in page.robots and page.h1 != 1:
        ERRORS.append(f'{name}: expected one h1, found {page.h1}')
    if not page.title or page.title in titles:
        ERRORS.append(f'{name}: missing or duplicate title')
    titles.add(page.title)
    if 'noindex' not in page.robots:
        if len(page.canonical) != 1 or not page.canonical[0].startswith(ORIGIN + '/'):
            ERRORS.append(f'{name}: expected one production canonical')
        else:
            url = page.canonical[0]
            if url in canonical:
                ERRORS.append(f'{name}: duplicate canonical {url}')
            canonical[url] = path
            if resolve(urlsplit(url).path) != path:
                ERRORS.append(f'{name}: canonical resolves to the wrong file')
        if len(page.descriptions) != 1 or not page.descriptions[0]:
            ERRORS.append(f'{name}: expected one nonempty description')
        if not page.json_blocks:
            ERRORS.append(f'{name}: missing structured data')
    for block in page.json_blocks:
        if block.get('@context') != 'https://schema.org':
            ERRORS.append(f'{name}: unexpected structured data context')
        nodes = block.get('@graph', [])
        ids = {node.get('@id') for node in nodes}
        for node in nodes:
            if node.get('@type') == 'BreadcrumbList':
                items = node['itemListElement']
                if [i['position'] for i in items] != list(range(1, len(items) + 1)):
                    ERRORS.append(f'{name}: invalid breadcrumb positions')
                page.links += [item['item'] for item in items]
            for prop in ('publisher', 'author', 'isPartOf', 'mainEntityOfPage', 'breadcrumb'):
                ref = node.get(prop, {}).get('@id')
                if ref and ref not in ids:
                    ERRORS.append(f'{name}: missing structured data reference {ref}')
    for link in page.links:
        parts = urlsplit(link)
        if parts.scheme in ('mailto', 'data', 'tel') or (parts.netloc and parts.netloc != 'aiorch.ai'):
            continue
        if parts.path.startswith('/') or parts.netloc:
            target = resolve(parts.path)
        elif parts.path:
            rel = path.parent / unquote(parts.path)
            target = resolve('/' + str(rel.relative_to(ROOT)))
        else:
            target = path
        if target is None or not target.is_file():
            ERRORS.append(f'{name}: missing target {link}')
        elif parts.fragment and target in pages and parts.fragment not in pages[target].ids:
            ERRORS.append(f'{name}: missing fragment {link}')

ns = {'s': 'http://www.sitemaps.org/schemas/sitemap/0.9'}
tree = ET.parse(ROOT / 'sitemap.xml')
urls = [node.text for node in tree.findall('s:url/s:loc', ns)]
if len(urls) != len(set(urls)) or set(urls) != set(canonical):
    ERRORS.append('Sitemap must list exactly the unique indexable canonical pages')
for url in urls:
    target = resolve(urlsplit(url).path)
    if target is None or 'noindex' in pages[target].robots:
        ERRORS.append(f'Sitemap contains a missing or noindex page: {url}')
for node in tree.findall('s:url/s:lastmod', ns):
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', node.text or ''):
        ERRORS.append('Sitemap has an invalid modification date')

robot = RobotFileParser()
robot.parse((ROOT / 'robots.txt').read_text().splitlines())
if ORIGIN + '/sitemap.xml' not in (robot.site_maps() or []):
    ERRORS.append('robots.txt does not advertise the sitemap')
for bot in ('Googlebot', 'Bingbot', 'OAI-SearchBot', 'Claude-SearchBot', 'PerplexityBot'):
    for url in urls:
        if not robot.can_fetch(bot, url):
            ERRORS.append(f'robots.txt blocks {bot}: {url}')
llms = (ROOT / 'llms.txt').read_text()
for url in re.findall(r'\]\((https://aiorch.ai[^)]+)\)', llms):
    if resolve(urlsplit(url).path) is None:
        ERRORS.append(f'llms.txt contains a missing page: {url}')
if 'noindex' not in pages[ROOT / 'success.html'].robots or 'noindex' not in pages[ROOT / '404.html'].robots:
    ERRORS.append('Success and 404 pages must be noindex')
if not (ROOT / 'assets/aiorch-social.jpg').is_file():
    ERRORS.append('Missing social image')
if ERRORS:
    print('\n'.join(ERRORS), file=sys.stderr)
    raise SystemExit(1)
print(f'PASS: {len(pages)} HTML pages; {len(urls)} canonical sitemap URLs; linked assets, anchors, structured data and search-bot policy.')
