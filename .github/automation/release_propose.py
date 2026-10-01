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
    body = (
        f"Prepare **{state['version']}** from `{state['source_sha']}`.\n\n"
        'Review the generated changelog, especially superseded changes and migration steps. '
        'This PR changes only release metadata. Merging it publishes the reviewed notes.\n\n'
        f"The full evidence and coverage report is in the artifact for "
        f"[the preparation run]({os.environ['GITHUB_SERVER_URL']}/{repo()}/actions/runs/"
        f"{os.environ['GITHUB_RUN_ID']}).\n\n"
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
