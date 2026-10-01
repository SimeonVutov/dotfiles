import subprocess

from common import api, git, pages, repo
from release_metadata import validate


def publish():
    sha = git('rev-parse', 'HEAD')
    state, notes = validate()
    if git('rev-parse', f'{sha}^') != state['source_sha']:
        raise ValueError('Master changed after preparation; refusing a stale release')
    prs = pages(f'repos/{repo()}/commits/{sha}/pulls')
    matching = [pr for pr in prs if pr.get('merged_at') and pr['merge_commit_sha'] == sha
                and pr['base']['ref'] == 'master'
                and pr['head']['ref'].startswith(f"release/{state['version']}-")
                and pr['head']['repo'] and pr['head']['repo']['full_name'] == repo()]
    if len(matching) != 1:
        raise ValueError('Publication requires the merge of a same-repository release review PR')
    changed = git('diff', '--name-only', f'{sha}^', sha).splitlines()
    if set(changed) != {'CHANGELOG.md', '.github/release-state.json'}:
        raise ValueError('The release merge contains changes outside release metadata')
    existing = subprocess.run(['git', 'rev-parse', '--verify', f"refs/tags/{state['version']}^{{commit}}"],
                              text=True, capture_output=True)
    if existing.returncode == 0:
        if existing.stdout.strip() != sha:
            raise ValueError('Existing version tag points to another commit')
    else:
        api(f'repos/{repo()}/git/refs', 'POST', {'ref': f"refs/tags/{state['version']}", 'sha': sha})
    releases = pages(f'repos/{repo()}/releases')
    existing_release = next((r for r in releases if r['tag_name'] == state['version']), None)
    if existing_release:
        if (existing_release.get('body') or '').strip() != notes.strip():
            raise ValueError('Existing release notes differ; refusing to overwrite them')
        print('Release already exists; no changes made')
        return
    api(f'repos/{repo()}/releases', 'POST', {
        'tag_name': state['version'], 'target_commitish': sha, 'name': state['version'],
        'body': notes, 'draft': False, 'prerelease': False,
    })
    print(f"Published {state['version']} at {sha}")


def sync():
    if pages(f'repos/{repo()}/pulls?state=open&base=develop&head={repo().split("/")[0]}:master'):
        return
    comparison = api(f'repos/{repo()}/compare/develop...master')
    if comparison['ahead_by'] == 0:
        return
    api(f'repos/{repo()}/pulls', 'POST', {
        'title': 'chore: sync release metadata into develop', 'head': 'master', 'base': 'develop',
        'body': 'Bring reviewed release metadata back into develop. Review and merge normally; '
                'this workflow does not merge or bypass branch protections.',
    })


if __name__ == '__main__':
    import sys
    sync() if sys.argv[1:] == ['sync'] else publish()
