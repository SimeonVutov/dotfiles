import os

from release_metadata import validate


if __name__ == '__main__':
    state, _ = validate(os.environ['RELEASE_HEAD'])
    if state['source_sha'] != os.environ['RELEASE_BASE']:
        raise ValueError('Master advanced after release preparation; close and regenerate the release PR')
