import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common import eligible, next_version
from commit_checks import valid
from config_checks import jsonc, qml_javascript_for_node
from release_analyze import (CopilotResponseError, analyze, analyze_chunk, batches, chunk_key,
                             evidence_source, parse_copilot_output, resolve_final_refs,
                             reusable_reviews, summary_source, validate_notes)
from release_collect import collect
from release_metadata import build, validate
from release_probe import probe


class Formats(unittest.TestCase):
    def test_versions(self):
        for bump, expected in [('patch', 'v0.0.8'), ('minor', 'v0.1.0'), ('major', 'v1.0.0')]:
            self.assertEqual(next_version('v0.0.7', bump), expected)
        for tag in ['0.0.7', 'v1.2.3-beta', 'v01.2.3']:
            with self.assertRaises(ValueError):
                next_version(tag, 'patch')

    def test_excluded_paths(self):
        for path in ['.env', 'sample/.env.local', 'sample/private.key', '.ssh/id_rsa']:
            self.assertFalse(eligible(path))
        self.assertTrue(eligible('.config/hypr/conf/environments/hybrid.conf'))

    def test_commit_messages(self):
        for message in ['feat: add planets', 'fix(quickshell): repair audio', 'refactor!: replace bar']:
            self.assertTrue(valid(message))
        for message in ['update config', 'fix:', 'feat: ', 'fix: first\nsecond']:
            self.assertFalse(valid(message))

    def test_jsonc_preserves_strings(self):
        self.assertEqual(jsonc('{/* comment */"url":"https://example.com", "text":",}",}'),
                         {'url': 'https://example.com', 'text': ',}'})

    def test_qml_javascript_directives_are_removed_for_node(self):
        source = '.pragma library\n.import "OrbitalMotion.js" as Motion\nconst value = 1;\n'
        self.assertEqual(qml_javascript_for_node(source), '\n\nconst value = 1;\n')

    def test_evidence_is_not_truncated(self):
        text = 'source\n' * 20000
        chunks = list(batches([{'id': 'file:a', 'content': text}]))
        self.assertEqual(''.join(part['content'] for chunk in chunks for part in chunk), text)
        self.assertEqual(len({part['id'] for chunk in chunks for part in chunk}),
                         sum(map(len, chunks)))

    def test_evidence_part_references_resolve_to_originals(self):
        known = {'after:sample.txt'}
        self.assertEqual(evidence_source('after:sample.txt@35000', known), 'after:sample.txt')
        with self.assertRaises(ValueError):
            evidence_source('after:unknown.txt@0', known)

    def test_final_summary_references_resolve_without_accepting_unknown_ids(self):
        known = {'commit:a', 'after:sample.txt'}
        summaries = {'0': {'commit:a', 'after:sample.txt'}}
        self.assertEqual(summary_source('0@0', summaries), '0')
        self.assertEqual(resolve_final_refs(['0', 'commit:a@0'], known, summaries),
                         (['after:sample.txt', 'commit:a'], ['0']))
        with self.assertRaises(ValueError):
            resolve_final_refs(['missing'], known, summaries)

    def test_final_report_accepts_numbered_summary_and_marks_broad_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'evidence.json').write_text(json.dumps([
                {'id': 'commit:a', 'content': 'Final change'},
            ]))
            (root / 'state.json').write_text(json.dumps({'version': 'v1.0.0'}))
            responses = [
                {'covered_ids': ['commit:a@0'], 'findings': 'Final change: commit:a@0',
                 'uncertainties': []},
                {'notes': '## Highlights\n\nFinal change.',
                 'evidence': [{'claim': 'Final change', 'refs': ['0']}], 'uncertainties': []},
            ]
            with patch.dict(os.environ, {'RELEASE_DIR': directory, 'RELEASE_MAX_AI_CALLS': '3',
                                         'RELEASE_RESUME_RUN_ID': ''}):
                with patch('release_analyze.ask', side_effect=responses):
                    analyze()
            review = (root / 'review.md').read_text()
            self.assertIn('commit:a', review)
            self.assertIn('via analysis summaries 0', review)
            self.assertTrue((root / 'final-candidate.json').exists())

    def test_reduced_summary_keeps_original_evidence_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'evidence.json').write_text(json.dumps([
                {'id': 'after:sample.txt', 'content': 'Final content'},
            ]))
            (root / 'state.json').write_text(json.dumps({'version': 'v1.0.0'}))
            calls = []

            def respond(prompt):
                calls.append(prompt)
                if prompt.startswith('Analyze this evidence batch'):
                    return {'covered_ids': ['after:sample.txt@0'],
                            'findings': 'Change ' + 'x' * 71000, 'uncertainties': []}
                if prompt.startswith('Reconcile these analyses'):
                    return {'findings': 'Change: after:sample.txt@0', 'uncertainties': []}
                return {'notes': '## Highlights\n\nFinal change.',
                        'evidence': [{'claim': 'Final change', 'refs': ['0']}],
                        'uncertainties': []}

            with patch.dict(os.environ, {'RELEASE_DIR': directory, 'RELEASE_MAX_AI_CALLS': '10',
                                         'RELEASE_RESUME_RUN_ID': ''}):
                with patch('release_analyze.ask', side_effect=respond):
                    analyze()
            self.assertTrue(any(prompt.startswith('Reconcile these analyses') for prompt in calls))
            self.assertIn('after:sample.txt', (root / 'review.md').read_text())

    def test_copilot_jsonl_extracts_the_final_assistant_message(self):
        output = '\n'.join(json.dumps(event) for event in [
            {'type': 'session.start', 'data': {}},
            {'type': 'assistant.message', 'data': {'content': '{"covered_ids": []}'}},
            {'type': 'assistant.message', 'data': {'content': '{"covered_ids": ["commit:a"]}'}},
        ])
        self.assertEqual(parse_copilot_output(output)['covered_ids'], ['commit:a'])

    def test_copilot_jsonl_rejects_extra_response_data(self):
        output = json.dumps({'type': 'assistant.message', 'data': {'content': '{} extra'}})
        with self.assertRaises(CopilotResponseError):
            parse_copilot_output(output)

    def test_resume_reuses_only_identical_completed_evidence(self):
        records = [{'id': 'commit:a', 'content': 'Original diff'}]
        review = {'covered_ids': ['commit:a@0'], 'findings': 'Change', 'uncertainties': []}
        reusable = reusable_reviews(records, [review])
        self.assertEqual(reusable[chunk_key(list(batches(records))[0])], review)
        changed = [{'id': 'commit:a', 'content': 'Different diff'}]
        self.assertNotIn(chunk_key(list(batches(changed))[0]), reusable)
        with self.assertRaises(ValueError):
            reusable_reviews(records, [dict(review, covered_ids=[])])

    def test_probe_replays_selected_evidence_batch(self):
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, 'evidence.json').write_text(json.dumps([
                {'id': 'commit:a', 'content': 'A'},
            ]))
            response = {'covered_ids': ['commit:a@0'], 'findings': 'Change', 'uncertainties': []}
            with patch.dict(os.environ, {'RELEASE_RESUME_DIR': directory, 'RELEASE_PROBE_BATCH': '1'}):
                with patch('release_probe.ask', return_value=response) as request:
                    probe()
            self.assertIn('REQUIRED_IDS:', request.call_args.args[0])

    def test_final_probe_reuses_completed_batches_and_checks_final_notes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'evidence.json').write_text(json.dumps([
                {'id': 'commit:a', 'content': 'A'},
            ]))
            (root / 'state.json').write_text(json.dumps({'version': 'v1.0.0'}))
            (root / 'analysis.json').write_text(json.dumps([
                {'covered_ids': ['commit:a@0'], 'findings': 'Change: commit:a@0',
                 'uncertainties': []},
            ]))
            response = {'notes': '## Highlights\n\nFinal change.',
                        'evidence': [{'claim': 'Final change', 'refs': ['0']}],
                        'uncertainties': []}
            with patch.dict(os.environ, {'RELEASE_RESUME_DIR': directory,
                                         'RELEASE_PROBE_BATCH': 'final'}):
                with patch('release_probe.ask', return_value=response) as request:
                    probe()
            self.assertEqual(request.call_count, 1)
            self.assertIn('commit:a', (root / 'review.md').read_text())
            self.assertTrue((root / 'notes.md').exists())

    def test_incomplete_batch_is_retried_without_accepting_missing_evidence(self):
        chunk = [{'id': 'commit:a', 'content': 'A'}, {'id': 'commit:b', 'content': 'B'}]
        responses = iter([
            {'covered_ids': ['commit:a'], 'findings': 'Partial', 'uncertainties': []},
            {'covered_ids': ['commit:a', 'commit:b'], 'findings': 'Complete', 'uncertainties': []},
        ])
        prompts = []

        def request(prompt):
            prompts.append(prompt)
            return next(responses)

        self.assertEqual(analyze_chunk(chunk, 'Policy', request, 1)['findings'], 'Complete')
        self.assertEqual(len(prompts), 2)
        self.assertIn('REQUIRED_IDS:', prompts[0])

    def test_incomplete_batch_stops_after_three_attempts(self):
        attempts = []

        def request(prompt):
            attempts.append(prompt)
            return {'covered_ids': [], 'findings': 'Partial', 'uncertainties': []}

        with self.assertRaisesRegex(ValueError, 'Batch 7 response invalid after 3 attempts'):
            analyze_chunk([{'id': 'commit:a', 'content': 'A'}], 'Policy', request, 7)
        self.assertEqual(len(attempts), 3)

    def test_release_sections(self):
        validate_notes('## Highlights\n\nNew release.\n\n## Minor changes\n\n- Fix audio.')
        for notes in ['', '## Fixes\n- Fix audio.', '## Highlights\nA\n## Highlights\nB',
                      '## Highlights\nA\n## Minor changes\nB\n## Major changes\nC',
                      '## Highlights\nhttps://github.com/a/b/compare/v1...v2']:
            with self.assertRaises(ValueError):
                validate_notes(notes)


class ReleaseMetadata(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.cwd = os.getcwd()
        os.chdir(self.workspace.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.invalid')
        Path('config.txt').write_text('old\n')
        Path('CHANGELOG.md').write_text('# Changelog\n\n## v0.0.7 - 2026-09-01\n\n### Highlights\n\nOld release.\n')
        self.commit('fix: baseline')
        self.git('tag', 'v0.0.7')
        self.base = self.git('rev-parse', 'HEAD')
        Path('config.txt').write_text('new\n')
        self.commit('feat: new configuration')
        self.source = self.git('rev-parse', 'HEAD')
        self.bundle = Path('bundle')
        self.bundle.mkdir()
        state = {'version': 'v0.1.0', 'base_tag': 'v0.0.7', 'base_sha': self.base,
                 'source_sha': self.source, 'date': '2026-10-01'}
        (self.bundle / 'state.json').write_text(json.dumps(state))
        (self.bundle / 'notes.md').write_text('## Highlights\n\nNew configuration.\n')
        Path('.github').mkdir()

    def tearDown(self):
        os.chdir(self.cwd)
        self.workspace.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', *args], text=True).strip()

    def commit(self, message):
        self.git('add', 'config.txt', 'CHANGELOG.md')
        self.git('commit', '-qm', message)

    def release(self):
        build(self.bundle)
        self.git('add', 'CHANGELOG.md', '.github/release-state.json')
        self.git('commit', '-qm', 'chore: prepare release v0.1.0')

    def test_round_trip_and_history_preserved(self):
        self.release()
        state, notes = validate()
        self.assertEqual(state['source_sha'], self.source)
        self.assertEqual(notes, (self.bundle / 'notes.md').read_text())
        self.assertIn('Old release.', Path('CHANGELOG.md').read_text())

    def test_collector_inventories_snapshots_commits_and_net_diff(self):
        Path('untracked-example.txt').write_text('Not part of Git history.\n')

        def fake_pages(path):
            if path.endswith('/releases'):
                return [{'draft': False, 'prerelease': False, 'tag_name': 'v0.0.7',
                         'body': 'Earlier release'}]
            return []

        settings = {'GITHUB_REF': 'refs/heads/master', 'GITHUB_REPOSITORY': 'test/repo',
                    'RELEASE_BUMP': 'minor', 'RELEASE_DIR': str(self.bundle)}
        with patch.dict(os.environ, settings), patch('release_collect.pages', fake_pages):
            collect()
        records = json.loads((self.bundle / 'evidence.json').read_text())
        ids = {r['id'] for r in records}
        self.assertIn('before:config.txt', ids)
        self.assertIn('after:config.txt', ids)
        self.assertTrue(any(i.startswith('commit-diff:') for i in ids))
        self.assertIn('net-diff:v0.0.7..v0.1.0', ids)
        self.assertNotIn('after:untracked-example.txt', ids)
        inventory = json.loads((self.bundle / 'inventory.json').read_text())
        self.assertIn('config.txt', inventory['changed_files'])
        self.assertNotIn('untracked-example.txt', inventory['changed_files'])

    def test_stale_preparation(self):
        Path('config.txt').write_text('third\n')
        self.commit('fix: another change')
        with self.assertRaises(ValueError):
            build(self.bundle)

    def test_unrelated_changes_rejected(self):
        self.release()
        Path('config.txt').write_text('third\n')
        self.commit('fix: unexpected change')
        with self.assertRaises(ValueError):
            validate()

    def test_history_edit_rejected(self):
        self.release()
        Path('CHANGELOG.md').write_text(Path('CHANGELOG.md').read_text().replace('Old release.', 'Changed history.'))
        self.git('add', 'CHANGELOG.md')
        self.git('commit', '-qm', 'docs: alter history')
        with self.assertRaises(ValueError):
            validate()


if __name__ == '__main__':
    unittest.main()
