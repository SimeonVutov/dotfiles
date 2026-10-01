import json
import os
from pathlib import Path

from release_analyze import (CopilotResponseError, analyze_chunk, ask, batches,
                             finalize, reusable_reviews)


def probe():
    root = Path(os.environ['RELEASE_RESUME_DIR'])
    selection = os.environ['RELEASE_PROBE_BATCH'].strip()
    records = json.loads((root / 'evidence.json').read_text())
    chunks = list(batches(records))
    policy = Path('.github/release-notes-instructions.md').read_text()
    max_calls = int(os.environ.get('RELEASE_MAX_AI_CALLS', '20'))
    calls = 0

    def request(prompt):
        nonlocal calls
        current_prompt = prompt
        for attempt in range(1, 4):
            if calls >= max_calls:
                raise ValueError('Probe AI-call budget exceeded; increase RELEASE_MAX_AI_CALLS')
            calls += 1
            try:
                return ask(current_prompt)
            except CopilotResponseError as error:
                if attempt == 3:
                    raise
                print(f'Copilot response invalid ({error}); retrying ({attempt}/2)', flush=True)
                current_prompt += ('\nPREVIOUS_RESPONSE_REJECTED: Output one valid JSON object '
                                   'with no Markdown fence, prefix, or trailing text.\n')

    if selection == 'final':
        reviews = json.loads((root / 'analysis.json').read_text())
        if len(reviews) != len(chunks):
            raise ValueError(f'Final probe needs all {len(chunks)} completed evidence batches')
        reusable_reviews(records, reviews)
        state = json.loads((root / 'state.json').read_text())
        finalize(records, reviews, state, root, policy, request)
        print(f'Final release-note probe passed using {len(reviews)} completed batches')
        return
    if not selection.isdecimal() or not 1 <= int(selection) <= len(chunks):
        raise ValueError(f'Choose an evidence batch from 1 to {len(chunks)}, or final')
    index = int(selection)
    review = analyze_chunk(chunks[index - 1], policy, request, index)
    print(f'Batch {index}/{len(chunks)} passed: {len(review["covered_ids"])} evidence IDs covered')


if __name__ == '__main__':
    probe()
