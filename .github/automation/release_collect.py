import datetime
import json
import os
import subprocess
from pathlib import Path

from common import eligible, git, next_version, pages, repo, version_tuple


def collect():
    if os.environ['GITHUB_REF'] != 'refs/heads/master':
        raise ValueError('Prepare releases from master only')
    target = git('rev-parse', 'HEAD')
    releases = pages(f'repos/{repo()}/releases')
    stable = []
    for release in releases:
        if release['draft'] or release['prerelease']:
            continue
        try:
            stable.append((version_tuple(release['tag_name']), release))
        except ValueError:
            continue
    if not stable:
        raise ValueError('A published stable release is required as the baseline')
    previous = max(stable, key=lambda item: item[0])[1]
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
    version = next_version(base_tag, os.environ['RELEASE_BUMP'])
    if version in git('tag', '--list').splitlines():
        raise ValueError('The proposed version tag already exists')
    root = Path(os.environ['RELEASE_DIR'])
    root.mkdir(parents=True, exist_ok=True)
    records, excluded, prs = [], set(), {}

    def add(kind, identity, content):
        records.append({'id': f'{kind}:{identity}', 'content': content})

    add('previous-release', base_tag, previous.get('body') or '')
    for sha in commits:
        add('commit', sha, git('show', '-s', '--format=%B', sha))
        paths = git('diff-tree', '--root', '-m', '--no-commit-id', '--name-only', '-r', sha).splitlines()
        allowed = sorted({p for p in paths if eligible(p)})
        excluded.update(p for p in paths if not eligible(p))
        if allowed:
            add('commit-diff', sha, git('show', '--format=', '--diff-merges=first-parent', '--no-ext-diff', '--no-textconv',
                                      '--no-renames', sha, '--', *allowed))
        for pr in pages(f'repos/{repo()}/commits/{sha}/pulls'):
            merged = pr.get('merge_commit_sha')
            if pr.get('merged_at') and merged:
                if merged in commits:
                    prs[pr['number']] = pr
    for number, pr in sorted(prs.items()):
        add('pr', str(number), json.dumps({
            'number': number, 'title': pr['title'], 'body': pr.get('body'),
            'author': pr['user']['login'], 'labels': [x['name'] for x in pr['labels']],
        }))
    for ref, prefix in [(base, 'before'), (target, 'after')]:
        tree = subprocess.check_output(['git', 'ls-tree', '-rz', ref]).split(b'\0')
        for entry in filter(None, tree):
            metadata, raw_path = entry.split(b'\t', 1)
            path = raw_path.decode('utf-8')
            if not eligible(path):
                excluded.add(path)
                continue
            mode, kind, oid = metadata.decode().split()
            if mode == '160000':
                add(prefix, path, f'Submodule pointer {oid}; contents not inspected')
                continue
            data = subprocess.check_output(['git', 'cat-file', 'blob', oid])
            try:
                text = data.decode('utf-8')
                if '\0' in text:
                    raise UnicodeError()
            except UnicodeError:
                text = f'Binary asset: {len(data)} bytes, object {oid}; visual contents not inspected'
            add(prefix, path, text)
    paths = git('diff', '--name-only', base, target).splitlines()
    allowed = [p for p in paths if eligible(p)]
    if allowed:
        add('net-diff', f'{base_tag}..{version}', git(
            'diff', '--no-ext-diff', '--no-textconv', '--no-renames', base, target, '--', *allowed
        ))
    state = {'version': version, 'base_tag': base_tag, 'base_sha': base, 'source_sha': target,
             'date': datetime.date.today().isoformat()}
    (root / 'state.json').write_text(json.dumps(state, indent=2) + '\n')
    (root / 'evidence.json').write_text(json.dumps(records, ensure_ascii=False))
    (root / 'inventory.json').write_text(json.dumps({
        'records': [r['id'] for r in records], 'commits': commits,
        'changed_files': paths, 'excluded_paths': sorted(excluded),
    }, indent=2) + '\n')


if __name__ == '__main__':
    collect()
