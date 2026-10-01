import json
import os
from pathlib import Path
from fnmatch import fnmatch

from common import api, pages, repo


def main():
    pr = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())['pull_request']
    rules = json.loads(Path('.github/label-rules.json').read_text())
    files = [item['filename'] for item in pages(f'repos/{repo()}/pulls/{pr["number"]}/files')]
    if len(files) >= 3000:
        raise ValueError('GitHub PR file API may be truncated; refusing incomplete labeling')
    desired = {label for label, patterns in rules.items() if any(
        fnmatch(path, pattern) for path in files for pattern in patterns
    )}
    existing = {item['name'] for item in api(f'repos/{repo()}/issues/{pr["number"]}/labels')}
    repo_labels = {item['name'] for item in pages(f'repos/{repo()}/labels')}
    for label in sorted(desired - repo_labels):
        api(f'repos/{repo()}/labels', 'POST', {'name': label, 'color': '64748b',
                                           'description': f'Changes affecting {label.split(": ")[-1]}'})
    for label in sorted(existing.intersection(rules) - desired):
        from urllib.parse import quote
        api(f'repos/{repo()}/issues/{pr["number"]}/labels/{quote(label, safe="")}', 'DELETE')
    if desired - existing:
        api(f'repos/{repo()}/issues/{pr["number"]}/labels', 'POST', {'labels': sorted(desired - existing)})


if __name__ == '__main__':
    main()
