"""Dependency-free, manifest-only public addon packager and CurseForge uploader."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
import zipfile

PUBLIC_ADDONS = {'Tranquility', 'Tranquility_Auctions', 'Tranquility_DB',
    'Tranquility_Dungeon', 'Tranquility_Gear', 'Tranquility_Info',
    'Tranquility_LFP', 'Tranquility_Loot', 'Tranquility_Phases', 'Tranquility_PvP',
    'Tranquility_Recruitment', 'Tranquility_Regions', 'Tranquility_Summons',
    'Uber', 'FlightPathFinder', 'LookingForProfession', 'TranquilityLFG', 'WorldNavigation'}

def package(root, env):
    root = root.resolve()
    cfg = json.loads((root / 'release.json').read_text(encoding='utf-8-sig'))
    primary = (root / cfg['primary']).resolve()
    if not primary.is_relative_to(root) or primary.name not in PUBLIC_ADDONS:
        raise ValueError('Primary addon must be a public addon inside the checkout')
    toc = (primary / (primary.name + '.toc')).read_text(encoding='utf-8-sig')
    match = re.search(r'^## Version:\s*([^\r\n]+)', toc, re.M)
    if not match: raise ValueError('Missing primary addon version')
    version = match[1].strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?', version):
        raise ValueError('Invalid addon version: ' + version)
    name = cfg['name']
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]+', name): raise ValueError('Unsafe package name')
    tagged = env.get('GITHUB_REF', '').startswith('refs/tags/')
    if tagged and env.get('GITHUB_REF_NAME') != 'v' + version:
        raise ValueError('Release tag must match v' + version)
    sha = env.get('GITHUB_SHA', '')[:8]
    if sha and not re.fullmatch(r'[a-fA-F0-9]{8}', sha): raise ValueError('Invalid commit SHA')
    label = version + ('-build.' + sha if sha and not tagged else '')
    entries = {}
    for folder in cfg['addons']:
        source = (root / folder).resolve()
        if not source.is_relative_to(root) or source.name not in PUBLIC_ADDONS:
            raise ValueError('Private or external addon excluded: ' + folder)
        addon = source.name
        manifest = (source / (addon + '.toc')).read_text(encoding='utf-8-sig')
        variant = source / (addon + '_Camelot.toc')
        if variant.exists() and variant.read_text(encoding='utf-8-sig') != manifest:
            raise ValueError('Client manifest mismatch: ' + addon)
        files = [addon + '.toc'] + ([variant.name] if variant.exists() else [])
        files += [line.strip() for line in manifest.splitlines()
                  if line.strip() and not line.lstrip().startswith('#')]
        files += [p.name for p in source.iterdir() if p.name in
                  ('LICENSE', 'README.md', 'CHANGELOG.md') or p.suffix.lower() == '.tga']
        for filename in dict.fromkeys(files):
            if not re.fullmatch(r'[A-Za-z0-9_.-]+', filename) or Path(filename).suffix.lower() not in ('.lua', '.toc', '.md', '.tga', ''):
                raise ValueError('Unsupported package entry: ' + filename)
            path = (source / filename).resolve()
            if not path.is_relative_to(source) or not path.is_file(): raise ValueError('Missing/unsafe file: ' + filename)
            key = addon + '/' + filename
            if key in entries: raise ValueError('Duplicate addon path: ' + key)
            entries[key] = path
    out = root / 'dist'
    out.mkdir(exist_ok=True)
    archive = out / (name + '-' + label + '.zip')
    temporary = archive.with_suffix('.zip.building')
    with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as z:
        for key, path in sorted(entries.items()): z.write(path, key)
    with zipfile.ZipFile(temporary) as z:
        if z.testzip() is not None or set(z.namelist()) != set(entries): raise ValueError('Archive verification failed')
    temporary.replace(archive)
    checksum = archive.with_suffix('.zip.sha256')
    checksum.write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n', encoding='ascii')
    print('Prepared ' + archive.name + ' (' + str(len(entries)) + ' files)')
    return archive, cfg, version, label

def upload(archive, cfg, version, label, env):
    token = env.get('CF_API_TOKEN', '').strip()
    project = env.get('CF_PROJECT_ID', '').strip()
    if not token: raise ValueError('Missing repository secret CF_API_TOKEN; upload was NOT performed')
    if not re.fullmatch(r'[1-9][0-9]*', project): raise ValueError('CF_PROJECT_ID must be the numeric CurseForge project ID')
    release_type = 'alpha' if not env.get('GITHUB_REF', '').startswith('refs/tags/') or 'alpha' in version else 'beta' if 'beta' in version else 'release'
    metadata = {'displayName': cfg['name'] + ' ' + label, 'releaseType': release_type,
        'changelogType': 'text', 'changelog': 'Source commit ' + env.get('GITHUB_SHA', 'local') + '. See bundled changelog and README.'}
    ids = env.get('CF_GAME_VERSION_IDS', '').strip()
    # 16001 is the WoW TOC Interface number, not a CurseForge version ID.
    if ids and ids != '16001':
        if not re.fullmatch(r'[1-9][0-9]*(?:\s*,\s*[1-9][0-9]*)*', ids):
            raise ValueError('CF_GAME_VERSION_IDS must contain comma-separated positive IDs')
        metadata['gameVersions'] = [int(v.strip()) for v in ids.split(',')]
    else:
        metadata['gameVersionNames'] = cfg.get('gameVersionNames', ['1.60.1'])
        if ids: print('::notice::16001 is a TOC Interface number; using CurseForge gameVersionNames=1.60.1 instead.')
    boundary = 'AddonRelease' + uuid.uuid4().hex
    body = ('--' + boundary + '\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n' + json.dumps(metadata) + '\r\n').encode()
    body += ('--' + boundary + '\r\nContent-Disposition: form-data; name="file"; filename="' + archive.name + '"\r\nContent-Type: application/zip\r\n\r\n').encode()
    body += archive.read_bytes() + ('\r\n--' + boundary + '--\r\n').encode()
    request = urllib.request.Request('https://www.curseforge.com/api/projects/' + project + '/upload-file', data=body,
        headers={'X-Api-Token': token, 'Content-Type': 'multipart/form-data; boundary=' + boundary,
                 'User-Agent': 'PublicAddonRelease/1.0'}, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=120) as response: result = json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read(4096).decode('utf-8', 'replace').replace(token, '[REDACTED]')
        raise ValueError('CurseForge upload failed (HTTP ' + str(error.code) + '): ' + detail) from None
    if not isinstance(result, dict) or not result.get('id'):
        raise ValueError('CurseForge returned no file ID; verify the project files before retrying')
    print('Submitted CurseForge file ID: ' + str(result['id']))
    receipt = {'projectId': int(project), 'fileId': result['id'], 'archive': archive.name,
               'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}
    archive.with_suffix('.zip.upload.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    summary = env.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as f:
            f.write('Uploaded **' + archive.name + '** to CurseForge project **' + project + '**. File ID: **' + str(result['id']) + '**.\n')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upload', action='store_true')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        archive, cfg, version, label = package(args.root, os.environ)
        if os.environ.get('GITHUB_OUTPUT'):
            with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as f:
                f.write('archive=' + str(archive) + '\nchecksum=' + str(archive.with_suffix('.zip.sha256')) + '\ntag=v' + label + '\n')
        if args.upload: upload(archive, cfg, version, label, os.environ)
    except (ValueError, OSError, KeyError, urllib.error.URLError) as error:
        print('::error::' + str(error), file=sys.stderr)
        return 1
    return 0

if __name__ == '__main__': sys.exit(main())
