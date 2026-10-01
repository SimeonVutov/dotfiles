import json
import os
import re
import sys
from pathlib import Path

from common import git


CONVENTIONAL = re.compile(r'^(feat|fix|perf|refactor|docs|style|test|build|ci|chore|revert)(\([a-zA-Z0-9_./-]+\))?!?: \S.*$')


def valid(message):
    return bool(CONVENTIONAL.fullmatch(message))


def main():
    pr = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())['pull_request']
    promotion = (pr['head']['repo'] and pr['base']['repo']
                 and pr['head']['repo']['full_name'] == pr['base']['repo']['full_name']
                 and (pr['head']['ref'], pr['base']['ref']) in {('develop', 'master'), ('master', 'develop')})
    if promotion:
        print('Promotion/synchronization PR: preserve existing commit history; no title convention required')
        return
    messages = git('log', '--no-merges', '--format=%s',
                   f"{pr['base']['sha']}..{pr['head']['sha']}").splitlines()
    invalid = [message for message in [pr['title'], *messages] if not valid(message)]
    if invalid:
        print(f'{len(invalid)} non-conventional PR titles or commit messages.', file=sys.stderr)
        print('Use type(scope): description; scope is optional. Check every non-merge commit.', file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
