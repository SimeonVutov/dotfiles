import datetime
import json
import os
import subprocess
from pathlib import Path

from common import ANALYSIS_REVISION, eligible, git, next_version, pages, repo, version_key


def collect():
    if os.environ['GITHUB_REF'] != 'refs/heads/master':
        raise ValueError('Prepare releases from master only')
    target = git('rev-parse', 'HEAD')
    releases = pages(f'repos/{repo()}/releases')
    published = []
    for release in releases:
        if release['draft']:
            continue
        try:
            published.append((version_key(release['tag_name']), release))
        except ValueError:
            continue
    if not published:
        raise ValueError('A published release is required as the baseline')
    previous = max(published, key=lambda item: item[0])[1]
    base_tag = previous['tag_name']
    base = git('rev-parse', f'{base_tag}^{{commit}}')
    subprocess.run(['git', 'merge-base', '--is-ancestor', base, target], check=True)
    commits = git('rev-list', '--reverse', f'{base}..{target}').splitlines()
    if not commits:
        raise ValueError('No commits since the previous release')
    if any(pr['head']['ref'].startswith('release/') for pr in pages(
        f'repos/{repo()}/pulls?state=open&base=master'
    )):
        raise ValueError('Review or close the existing release PR before preparing another')
    bump = os.environ['RELEASE_BUMP']
    channel = os.environ.get('RELEASE_CHANNEL', 'stable')
    version = next_version(base_tag, bump, channel)
    if version in git('tag', '--list').splitlines():
        raise ValueError('The proposed version tag already exists')
    root = Path(os.environ['RELEASE_DIR'])
    root.mkdir(parents=True, exist_ok=True)
    records = []
    paths = git('diff', '--name-only', '--no-renames', base, target).splitlines()
    allowed = [path for path in paths if eligible(path)]
    excluded = sorted(set(paths) - set(allowed))
    touched = {path: [] for path in allowed}
    messages = {}
    pull_requests = {}
    prs_by_commit = {}
    for sha in commits:
        commit_paths = set(git('diff-tree', '--root', '-m', '--no-commit-id',
                               '--name-only', '-r', sha).splitlines())
        relevant = commit_paths.intersection(touched)
        if not relevant:
            continue
        messages[sha] = git('show', '-s', '--format=%B', sha)
        for path in relevant:
            touched[path].append(sha)
        prs_by_commit[sha] = []
        for pr in pages(f'repos/{repo()}/commits/{sha}/pulls'):
            if not pr.get('merged_at'):
                continue
            number = pr['number']
            prs_by_commit[sha].append(number)
            pull_requests[number] = {
                'number': number, 'title': pr['title'], 'body': pr.get('body') or '',
            }

    def add(kind, identity, content):
        records.append({'id': f'{kind}:{identity}', 'content': content})

    add('previous-release', base_tag, previous.get('body') or '')

    def snapshot(ref, path):
        entry = subprocess.check_output(['git', 'ls-tree', '-z', ref, '--', path])
        if not entry:
            return None
        metadata, _ = entry.rstrip(b'\0').split(b'\t', 1)
        mode, kind, oid = metadata.decode().split()
        if mode == '160000':
            return f'Submodule pointer {oid}; contents not inspected'
        data = subprocess.check_output(['git', 'cat-file', 'blob', oid])
        try:
            text = data.decode('utf-8')
            if '\0' in text:
                raise UnicodeError()
            return text
        except UnicodeError:
            return f'Binary asset: {len(data)} bytes, object {oid}; visual contents not inspected'

    for path in allowed:
        before = snapshot(base, path)
        after = snapshot(target, path)
        diff = git('diff', '--no-ext-diff', '--no-textconv', '--no-renames', base, target, '--', path)
        related_commits = touched[path]
        related_prs = sorted({number for sha in related_commits for number in prs_by_commit[sha]})
        add('file-change', path, json.dumps({
            'path': path, 'before': before, 'after': after, 'net_diff': diff,
            'history_context': {
                'commits': [{'sha': sha, 'message': messages[sha]} for sha in related_commits],
                'pull_requests': [pull_requests[number] for number in related_prs],
            },
        }, ensure_ascii=False))
    state = {'version': version, 'base_tag': base_tag, 'base_sha': base, 'source_sha': target,
             'bump': bump, 'channel': channel, 'analysis_revision': ANALYSIS_REVISION,
             'date': datetime.date.today().isoformat()}
    (root / 'state.json').write_text(json.dumps(state, indent=2) + '\n')
    (root / 'evidence.json').write_text(json.dumps(records, ensure_ascii=False))
    (root / 'inventory.json').write_text(json.dumps({
        'records': [r['id'] for r in records], 'commits': commits,
        'changed_files': paths, 'excluded_paths': excluded,
    }, indent=2) + '\n')


if __name__ == '__main__':
    collect()
