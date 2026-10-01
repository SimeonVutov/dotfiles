import json
import os
from pathlib import Path

from release_analyze import CopilotResponseError, analyze_chunk, ask, batches


def probe():
    index = int(os.environ['RELEASE_PROBE_BATCH'])
    records = json.loads((Path(os.environ['RELEASE_RESUME_DIR']) / 'evidence.json').read_text())
    chunks = list(batches(records))
    if not 1 <= index <= len(chunks):
        raise ValueError(f'Choose an evidence batch from 1 to {len(chunks)}')
    policy = Path('.github/release-notes-instructions.md').read_text()

    def request(prompt):
        for attempt in range(1, 4):
            try:
                return ask(prompt)
            except CopilotResponseError as error:
                if attempt == 3:
                    raise
                print(f'Copilot response invalid ({error}); retrying ({attempt}/2)', flush=True)

    review = analyze_chunk(chunks[index - 1], policy, request, index)
    print(f'Batch {index}/{len(chunks)} passed: {len(review["covered_ids"])} evidence IDs covered')


if __name__ == '__main__':
    probe()
