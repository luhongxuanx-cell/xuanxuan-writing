#!/usr/bin/env python3
"""Check the intended source distribution, not an entire personal workspace."""
from pathlib import Path
import json
import re
import sys

root = Path(__file__).resolve().parents[1]
allowed_top = {'README.md', 'LICENSE', '.gitignore', 'native-writing-app', 'xcode-app', 'mobile-sync', '萱萱写作.xcodeproj', 'Examples', 'docs', 'Tests', 'scripts'}
excluded = {'.git', '.demo-data', '.validation', 'build', 'DerivedData', '.build', '__pycache__'}
errors = []
files = []
for path in root.rglob('*'):
    rel = path.relative_to(root)
    if any(part in excluded for part in rel.parts):
        continue
    if path.is_symlink():
        errors.append(f'symlink: {rel}')
        continue
    if not path.is_file():
        continue
    files.append(path)
    if rel.parts[0] not in allowed_top:
        errors.append(f'unexpected root entry: {rel}')
    if any(part in {'xcuserdata', '.xuanxuan-sync', 'library', 'output', 'snapshots'} for part in rel.parts):
        errors.append(f'private/runtime directory: {rel}')
    if path.suffix.lower() in {'.p12', '.mobileprovision', '.xcuserstate'} or path.name.startswith('.env') or path.name == '.DS_Store':
        errors.append(f'private/runtime file: {rel}')
        continue
    if path.suffix.lower() == '.png':
        if rel.parts[:2] != ('docs', 'screenshots'):
            errors.append(f'unreviewed image: {rel}')
        continue
    text = path.read_text(encoding='utf-8')
    absolute_home = '/' + 'Users' + '/'
    if absolute_home in text or '\\/' + 'Users' + '\\/' in text:
        errors.append(f'absolute home path: {rel}')
    if re.search(r'DEVELOPMENT_TEAM\s*=\s*(?!""\s*;)[A-Za-z0-9]{5,}', text):
        errors.append(f'personal signing team: {rel}')
    if re.search(r'\b(?:sk-[A-Za-z0-9_-]{20,}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,})\b', text):
        errors.append(f'possible credential: {rel}')
registry = json.loads((root/'Examples/DemoWorkspace/projects.json').read_text())
if len(registry['projects']) != 1 or registry['projects'][0]['id'] != 'lighthouse-demo':
    errors.append('unexpected example project')
for project in registry['projects']:
    if project['path'] != 'projects/lighthouse-demo':
        errors.append('nonportable sample path')
    drafts = list((root/'Examples/DemoWorkspace'/project['path']/'drafts').glob('*.md'))
    if len(drafts) != 3:
        errors.append('expected three fictional chapters')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'PASS public source tree: {len(files)} files, one fictional project, portable paths, no detected runtime data/signing identity/credential patterns')
print('Pattern checks supplement manual review; they do not establish complete provenance or detect every secret.')
