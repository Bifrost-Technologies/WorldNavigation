from pathlib import Path
import hashlib, json, os, re, sys, urllib.request, urllib.error, uuid, zipfile
root = Path(__file__).resolve().parents[1]
cfg = json.loads((root / 'release.json').read_text(encoding='utf-8-sig'))
primary = root / cfg['primary']
toc = (primary / (primary.name + '.toc')).read_text(encoding='utf-8-sig')
version = re.search(r'^## Version: ([^\r\n]+)', toc, re.M).group(1).strip()
if not re.fullmatch(r'[0-9A-Za-z.+-]+', version): raise ValueError('Invalid version')
ref = os.environ.get('GITHUB_REF', '')
tag = os.environ.get('GITHUB_REF_NAME', '')
if ref.startswith('refs/tags/') and tag != 'v' + version: raise ValueError('Tag must match v' + version)
sha = os.environ.get('GITHUB_SHA', '')[:8]
label = version + ('-alpha.' + sha if sha and not ref.startswith('refs/tags/') else '')
out = root / 'dist'; out.mkdir(exist_ok=True)
archive = out / (cfg['name'] + '-' + label + '.zip')
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    for folder in cfg['addons']:
        source = (root / folder).resolve()
        if not source.is_relative_to(root.resolve()): raise ValueError('Source outside checkout')
        name = source.name
        if name.startswith('Titans') or name in ('companion', 'CombatWorldNavigation'): raise ValueError('Private addon excluded')
        manifest = (source / (name + '.toc')).read_text(encoding='utf-8-sig')
        variant = source / (name + '_Camelot.toc')
        if variant.exists() and variant.read_text(encoding='utf-8-sig') != manifest: raise ValueError('Manifest mismatch: ' + name)
        files = [name + '.toc'] + ([variant.name] if variant.exists() else [])
        files += [line.strip() for line in manifest.splitlines() if line.strip() and not line.startswith('#')]
        files += [p.name for p in source.iterdir() if p.name in ('LICENSE', 'README.md', 'CHANGELOG.md') or p.suffix == '.tga']
        for filename in dict.fromkeys(files):
            if not re.fullmatch(r'[A-Za-z0-9_.-]+', filename) or Path(filename).suffix.lower() not in ('.lua','.toc','.md','.tga',''):
                raise ValueError('Unsupported package entry: ' + filename)
            z.write(source / filename, name + '/' + filename)
archive.with_suffix('.zip.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '\n', encoding='ascii')
print('Prepared ' + archive.name)
if '--upload' not in sys.argv: sys.exit(0)
token = os.environ.get('CF_API_TOKEN', '')
project = os.environ.get('CF_PROJECT_ID', '')
if not token or not re.fullmatch(r'[1-9][0-9]*', project):
    print('::notice::Upload not enabled. Set secret CF_API_TOKEN and variable CF_PROJECT_ID. Package is available as an Actions artifact.')
    sys.exit(0)
release_type = 'alpha' if not ref.startswith('refs/tags/') or 'alpha' in version else 'beta' if 'beta' in version else 'release'
metadata = {'displayName': cfg['name'] + ' ' + label, 'releaseType': release_type,
            'changelogType': 'text',
            'changelog': 'Commit ' + os.environ.get('GITHUB_SHA', 'local') + '. See bundled changelog and README. Tests skipped by owner request.'}
ids = os.environ.get('CF_GAME_VERSION_IDS', '')
if not re.fullmatch(r'[1-9][0-9]*(?:\s*,\s*[1-9][0-9]*)*', ids):
    raise SystemExit('Set CF_GAME_VERSION_IDS to the actual CurseForge version IDs for Forever WoW 1.60.1; no game version is guessed.')
if ids:
    metadata['gameVersions'] = [int(v.strip()) for v in ids.split(',')]

boundary = 'UberRelease' + uuid.uuid4().hex
body = ('--' + boundary + '\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n' + json.dumps(metadata) + '\r\n').encode()
body += ('--' + boundary + '\r\nContent-Disposition: form-data; name="file"; filename="' + archive.name + '"\r\nContent-Type: application/zip\r\n\r\n').encode()
body += archive.read_bytes() + ('\r\n--' + boundary + '--\r\n').encode()
request = urllib.request.Request('https://www.curseforge.com/api/projects/' + project + '/upload-file', data=body,
    headers={'X-Api-Token': token, 'Content-Type': 'multipart/form-data; boundary=' + boundary}, method='POST')
try:
    with urllib.request.urlopen(request, timeout=120) as response: result = json.load(response)
except urllib.error.HTTPError as error:
    raise SystemExit('CurseForge upload failed (HTTP ' + str(error.code) + '). Check project/token/game-version configuration in repository settings.')
print('Submitted CurseForge file ID: ' + str(result.get('id', 'unknown')))
