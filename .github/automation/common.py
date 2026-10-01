import json
import os
import re
import subprocess
from pathlib import PurePosixPath


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


def version_tuple(tag):
    if not re.fullmatch(r'v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)', tag):
        raise ValueError(f'Not a stable version tag: {tag}')
    return tuple(map(int, tag[1:].split('.')))


def next_version(tag, bump):
    major, minor, patch = version_tuple(tag)
    if bump == 'major':
        return f'v{major + 1}.0.0'
    if bump == 'minor':
        return f'v{major}.{minor + 1}.0'
    if bump == 'patch':
        return f'v{major}.{minor}.{patch + 1}'
    raise ValueError('Choose patch, minor, or major')


def output(name, value):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
        stream.write(f'{name}={value}\n')
