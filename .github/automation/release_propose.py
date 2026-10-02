import json
import os
import subprocess
from pathlib import Path

from common import api, git, pages, repo
from release_metadata import STATE_PATH, build


def propose():
    root = Path(os.environ['RELEASE_DIR'])
    state = json.loads((root / 'state.json').read_text())
    if api(f'repos/{repo()}/git/ref/heads/master')['object']['sha'] != state['source_sha']:
        raise ValueError('Master advanced during analysis; rerun release preparation')
    if any(pr['head']['ref'].startswith('release/') for pr in pages(
        f'repos/{repo()}/pulls?state=open&base=master'
    )):
        raise ValueError('An open release PR already exists')
    build(root)
    branch = f"release/{state['version']}-{os.environ['GITHUB_RUN_ID']}"
    git('checkout', '-b', branch)
    git('config', 'user.name', 'github-actions[bot]')
    git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    git('add', '--', 'CHANGELOG.md', STATE_PATH)
    git('commit', '-m', f"chore: prepare release {state['version']}")
    subprocess.run(['git', 'push', 'origin', f'HEAD:refs/heads/{branch}'], check=True)
    notes = (root / 'notes.md').read_text().strip()
    source_url = f"{os.environ['GITHUB_SERVER_URL']}/{repo()}/commit/{state['source_sha']}"
    run_url = f"{os.environ['GITHUB_SERVER_URL']}/{repo()}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
    body = (
        f"# {state['version']} release review\n\n"
        f"Release source: [`{state['source_sha'][:12]}`]({source_url}) "
        '(the master commit used for this comparison). '
        'This PR changes only release metadata.\n\n'
        f"{notes}\n\n"
        f"Review the notes and migration steps against the [preparation evidence]({run_url}). "
        'Merging this PR publishes these notes.\n\n'
        'If master advances before this is merged, close this PR and prepare a fresh release.'
    )
    pr = api(f'repos/{repo()}/pulls', 'POST', {
        'title': f"chore: release {state['version']}", 'head': branch, 'base': 'master', 'body': body,
    })
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a') as stream:
            stream.write(f"Release review PR: {pr['html_url']}\n")


if __name__ == '__main__':
    propose()
