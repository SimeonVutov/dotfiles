import datetime
import json
import re
import subprocess
from pathlib import Path

from common import git, next_version, version_parts
from release_analyze import validate_notes


STATE_PATH = '.github/release-state.json'
RELEASE_PATHS = {STATE_PATH, 'CHANGELOG.md'}


def build(root):
    state = json.loads((root / 'state.json').read_text())
    if git('rev-parse', 'HEAD') != state['source_sha']:
        raise ValueError('Master advanced during analysis; prepare a fresh release')
    notes = validate_notes((root / 'notes.md').read_text())
    path = Path('CHANGELOG.md')
    previous = path.read_text() if path.exists() else '# Changelog\n'
    if f"## {state['version']} - " in previous:
        raise ValueError('Changelog already contains this version')
    if not previous.startswith('# Changelog\n'):
        raise ValueError('Unexpected changelog format')
    entry = f"## {state['version']} - {state['date']}\n\n" + re.sub(
        r'^(#{2,5}) ', lambda match: '#' + match.group(1) + ' ', notes, flags=re.M
    )
    path.write_text('# Changelog\n\n' + entry + '\n' + previous[len('# Changelog\n'):].lstrip())
    Path(STATE_PATH).write_text(json.dumps(state, indent=2) + '\n')


def validate(ref='HEAD'):
    state = json.loads(git('show', f'{ref}:{STATE_PATH}'))
    version_parts(state['version'])
    version_parts(state['base_tag'])
    if state['version'] != next_version(state['base_tag'], state['bump'], state['channel']):
        raise ValueError('Invalid version increment')
    datetime.date.fromisoformat(state['date'])
    for field in ('source_sha', 'base_sha'):
        if not re.fullmatch('[0-9a-f]{40}', state[field]):
            raise ValueError(f'Invalid {field}')
    subprocess.run(['git', 'merge-base', '--is-ancestor', state['base_sha'], state['source_sha']], check=True)
    subprocess.run(['git', 'merge-base', '--is-ancestor', state['source_sha'], ref], check=True)
    if git('rev-parse', f"{state['base_tag']}^{{commit}}") != state['base_sha']:
        raise ValueError('Previous release tag no longer matches the frozen baseline')
    changed = set(git('diff', '--name-only', state['source_sha'], ref).splitlines())
    if changed != RELEASE_PATHS:
        raise ValueError('Release must contain only the changelog and release state; master may have advanced')
    changelog = git('show', f'{ref}:CHANGELOG.md')
    marker = f"# Changelog\n\n## {state['version']} - {state['date']}\n\n"
    if not changelog.startswith(marker):
        raise ValueError('Release state does not match the top changelog entry')
    content = changelog[len(marker):]
    notes, separator, history = content.partition('\n## ')
    notes = validate_notes(re.sub(
        r'^(#{3,6}) ', lambda match: match.group(1)[1:] + ' ', notes, flags=re.M
    ))
    old = git('ls-tree', state['source_sha'], '--', 'CHANGELOG.md')
    previous = git('show', f"{state['source_sha']}:CHANGELOG.md") if old else '# Changelog'
    restored = '# Changelog\n\n' + ('## ' + history if separator else '')
    if restored.strip() != previous.strip():
        raise ValueError('Existing changelog history was modified')
    return state, notes
