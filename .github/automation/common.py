import json
import os
import re
import subprocess
from pathlib import PurePosixPath


ANALYSIS_REVISION = 4


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def git(*args):
    return run('git', *args)


def api(path, method='GET', payload=None):
    args = ['gh', 'api', '--method', method, path]
    if payload is not None:
        args += ['--input', '-']
    result = subprocess.check_output(
        args, input=json.dumps(payload) if payload is not None else None, text=True
    )
    return json.loads(result) if result.strip() else None


def pages(path):
    result, page = [], 1
    while True:
        batch = api(f'{path}{"&" if "?" in path else "?"}per_page=100&page={page}')
        result.extend(batch)
        if len(batch) < 100:
            return result
        page += 1


def repo():
    return os.environ['GITHUB_REPOSITORY']


def eligible(path):
    parts = PurePosixPath(path.lower()).parts
    return not any(
        part == '.env' or part.startswith('.env.')
        or part.endswith(('.key', '.pem', '.p12', '.pfx', '.kdbx', '.lic', '.token'))
        or part.startswith(('id_rsa', 'id_ed25519'))
        or 'credential' in part or 'secret' in part or 'password' in part
        or part in {'.ssh', '.npmrc', '.pypirc', '.netrc', '.git-credentials',
                    'cookie', 'cookies', 'keyring', 'keyrings', 'auth.json'}
        for part in parts
    )


VERSION = re.compile(
    r'v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
    r'(?:-alpha\.([1-9][0-9]*))?'
)


def version_parts(tag):
    match = VERSION.fullmatch(tag)
    if not match:
        raise ValueError(f'Not a supported version tag: {tag}')
    major, minor, patch, alpha = match.groups()
    return int(major), int(minor), int(patch), int(alpha) if alpha else None


def version_key(tag):
    major, minor, patch, alpha = version_parts(tag)
    return major, minor, patch, alpha is None, alpha or 0


def next_version(tag, bump, channel='stable'):
    major, minor, patch, alpha = version_parts(tag)
    if channel not in ('stable', 'alpha'):
        raise ValueError('Choose stable or alpha')
    if bump == 'prerelease':
        if channel != 'alpha' or alpha is None:
            raise ValueError('prerelease requires an alpha baseline and alpha channel')
        return f'v{major}.{minor}.{patch}-alpha.{alpha + 1}'
    if bump == 'promote':
        if channel != 'stable' or alpha is None:
            raise ValueError('promote requires an alpha baseline and stable channel')
        return f'v{major}.{minor}.{patch}'
    if bump == 'major':
        core = f'v{major + 1}.0.0'
    elif bump == 'minor':
        core = f'v{major}.{minor + 1}.0'
    elif bump == 'patch':
        core = f'v{major}.{minor}.{patch + 1}'
    else:
        raise ValueError('Choose patch, minor, major, prerelease, or promote')
    return core + ('-alpha.1' if channel == 'alpha' else '')


def output(name, value):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
        stream.write(f'{name}={value}\n')
