import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common import ANALYSIS_REVISION, eligible, next_version, version_key
from commit_checks import valid
from config_checks import jsonc, qml_javascript_for_node
from release_analyze import (CATEGORIES, CopilotResponseError, analyze, analyze_chunk,
                             analysis_records, batches, candidate_inventory, chunk_key,
                             evidence_source, finalize, parse_copilot_output, record_parts,
                             previous_release_notes, render_notes, reusable_reviews, split_text,
                             subsystem,
                             validate_batch_result,
                             validate_final, validate_notes)
from release_collect import collect
from release_metadata import build, validate
from release_probe import probe


def file_record(path, before='old\n', after='new\n', diff='+new\n', commits=None, prs=None):
    return {
        'id': f'file-change:{path}',
        'content': json.dumps({
            'path': path, 'before': before, 'after': after, 'net_diff': diff,
            'history_context': {'commits': commits or [], 'pull_requests': prs or []},
        }),
    }


def sample_evidence():
    return [
        {'id': 'previous-release:v0.0.7', 'content': 'Previous release notes.'},
        file_record('.config/example.conf', commits=[{'sha': 'a' * 40, 'message': 'feat: control audio'}],
                    prs=[{'number': 12, 'title': 'Audio controls', 'body': 'Add controls'}]),
    ]


def batch_result(chunk, description='Audio controls are available.'):
    return {
        'covered_ids': sorted(part['id'] for part in chunk),
        'candidates': [{
            'description': description, 'category': 'Added',
            'refs': [part['id'] for part in chunk if part['role'] == 'change'][:1],
            'intent': '',
        }],
        'ignored': [], 'uncertainties': [],
    }


def final_result(candidate_ids):
    changes = {category: [] for category in CATEGORIES}
    changes['Added'] = [{'text': 'Audio controls are available.', 'ids': candidate_ids}]
    return {
        'highlight': 'Audio controls are now available.',
        'highlight_ids': candidate_ids[:1],
        'migration': [], 'changes': changes, 'omitted': [], 'uncertainties': [],
    }


class Formats(unittest.TestCase):
    def test_versions(self):
        self.assertEqual(next_version('v0.0.7', 'minor', 'alpha'), 'v0.1.0-alpha.1')
        self.assertEqual(next_version('v0.1.0-alpha.1', 'prerelease', 'alpha'),
                         'v0.1.0-alpha.2')
        self.assertEqual(next_version('v0.1.0-alpha.2', 'promote', 'stable'), 'v0.1.0')
        self.assertEqual(next_version('v0.0.7', 'major'), 'v1.0.0')
        self.assertLess(version_key('v0.1.0-alpha.2'), version_key('v0.1.0'))
        for tag in ['0.0.7', 'v1.2.3-beta', 'v01.2.3']:
            with self.assertRaises(ValueError):
                next_version(tag, 'patch')

    def test_excluded_paths(self):
        for path in ['.env', 'sample/.env.local', 'sample/private.key', '.ssh/id_rsa']:
            self.assertFalse(eligible(path))
        self.assertTrue(eligible('.config/hypr/conf/environments/hybrid.conf'))

    def test_commit_messages(self):
        for message in ['feat: add planets', 'fix(quickshell): repair audio',
                        'refactor!: replace bar']:
            self.assertTrue(valid(message))
        for message in ['update config', 'fix:', 'feat: ', 'fix: first\nsecond']:
            self.assertFalse(valid(message))

    def test_jsonc_preserves_strings(self):
        self.assertEqual(jsonc('{/* comment */"url":"https://example.com", "text":",}",}'),
                         {'url': 'https://example.com', 'text': ',}'})

    def test_qml_javascript_directives_are_removed_for_node(self):
        source = '.pragma library\n.import "OrbitalMotion.js" as Motion\nconst value = 1;\n'
        self.assertEqual(qml_javascript_for_node(source), '\n\nconst value = 1;\n')

    def test_evidence_split_preserves_final_diff_and_context(self):
        long_diff = '+feature\n' * 10000
        record = file_record('.config/example.conf', diff=long_diff)
        chunks = list(batches([record]))
        parts = [part for chunk in chunks for part in chunk]
        diff = ''.join(json.loads(part['content'])['text'] for part in parts
                       if part['role'] == 'change')
        self.assertEqual(diff, long_diff)
        self.assertTrue(any(part['role'] == 'context' for part in parts))
        self.assertTrue(all('history_context' in json.loads(part['content'])
                            for part in parts if part['role'] == 'change'))
        self.assertEqual(len({part['id'] for part in parts}), len(parts))

    def test_unbroken_evidence_line_is_split_without_losing_text(self):
        value = 'a' * 20000 + '😀' * 1000 + '\nnext line\n'
        pieces = list(split_text(value, 1000))
        self.assertEqual(''.join(pieces), value)
        self.assertTrue(all(len(json.dumps(piece)) <= 1000 for piece in pieces))

    def test_long_pr_body_is_preserved_in_context_parts(self):
        body = 'A long pull request explanation. ' * 2000
        record = file_record('.config/example.conf', prs=[{
            'number': 12, 'title': 'Describe the change', 'body': body,
        }])
        parts = list(record_parts(record))
        history = ''.join(json.loads(part['content'])['text'] for part in parts
                          if json.loads(part['content'])['field'] == 'history_context')
        self.assertEqual(json.loads(history)['pull_requests'][0]['body'], body)

    def test_related_legacy_and_current_ui_files_share_a_subsystem(self):
        self.assertEqual(subsystem(file_record('.config/rofi/launcher.sh')),
                         subsystem(file_record('.config/quickshell/topbar/Launcher/Search.js')))
        self.assertEqual(subsystem(file_record('.config/waybar/config.jsonc')),
                         subsystem(file_record('.config/quickshell/topbar/Bar/Bar.qml')))

    def test_unclassified_tracked_area_is_still_batched(self):
        records = [file_record('.config/tmux/tmux.conf'),
                   file_record('.config/quickshell/topbar/Services/Connectivity.qml')]
        seen = {part['id'].split('@')[0] for chunk in batches(records) for part in chunk}
        self.assertEqual(seen, {record['id'] for record in records})
        self.assertIn('Maintenance', CATEGORIES)
        self.assertIn('Documentation', CATEGORIES)

    def test_evidence_references_are_exact(self):
        known = {'file-change:sample.txt'}
        self.assertEqual(evidence_source('file-change:sample.txt@3', known),
                         'file-change:sample.txt')
        for ref in ['0', 'ANALYSES 2', 'file-change:unknown.txt@0']:
            with self.assertRaises(ValueError):
                evidence_source(ref, known)

    def test_batch_response_requires_complete_coverage_and_net_diff_refs(self):
        chunk = list(batches(analysis_records(sample_evidence())))[0]
        result = batch_result(chunk)
        self.assertEqual(validate_batch_result(result, chunk), result)
        with self.assertRaises(ValueError):
            validate_batch_result(dict(result, covered_ids=[]), chunk)
        with self.assertRaises(ValueError):
            validate_batch_result(dict(result, candidates=[dict(result['candidates'][0],
                                                                refs=['0'])]), chunk)
        with self.assertRaises(ValueError):
            validate_batch_result(dict(result, candidates=[dict(result['candidates'][0],
                                                                refs=[[]])]), chunk)

    def test_batch_requires_reason_for_unpublished_comparison(self):
        chunk = list(batches(analysis_records(sample_evidence())))[0]
        empty = {'covered_ids': [part['id'] for part in chunk], 'candidates': [],
                 'ignored': [], 'uncertainties': []}
        with self.assertRaises(ValueError):
            validate_batch_result(empty, chunk)
        empty['ignored'] = [{'id': chunk[0]['id'], 'reason': 'Only an internal default changed.'}]
        self.assertEqual(validate_batch_result(empty, chunk), empty)

    def test_batch_retry_preserves_strict_format(self):
        chunk = list(batches(analysis_records(sample_evidence())))[0]
        valid = batch_result(chunk)
        responses = iter([dict(valid, covered_ids=[]), valid])
        prompts = []

        def request(prompt):
            prompts.append(prompt)
            return next(responses)

        self.assertEqual(analyze_chunk(chunk, 'Policy', request, 1), valid)
        self.assertEqual(len(prompts), 2)
        self.assertIn('CHANGE_IDS:', prompts[0])
        self.assertIn('PREVIOUS_RESPONSE_REJECTED', prompts[1])

    def test_batch_stops_after_three_invalid_responses(self):
        chunk = list(batches(analysis_records(sample_evidence())))[0]
        with self.assertRaisesRegex(ValueError, 'Batch 7 response invalid after 3 attempts'):
            analyze_chunk(chunk, 'Policy', lambda _: {'covered_ids': []}, 7)

    def test_copilot_jsonl_extracts_last_assistant_message(self):
        output = '\n'.join(json.dumps(event) for event in [
            {'type': 'session.start', 'data': {}},
            {'type': 'assistant.message', 'data': {'content': '{"covered_ids": []}'}},
            {'type': 'assistant.message', 'data': {'content': '{"covered_ids": ["exact"]}'}},
        ])
        self.assertEqual(parse_copilot_output(output)['covered_ids'], ['exact'])
        for content in ['{} extra', '```json\n{}\n```']:
            output = json.dumps({'type': 'assistant.message', 'data': {'content': content}})
            with self.assertRaises(CopilotResponseError):
                parse_copilot_output(output)

    def test_candidate_ledger_and_public_notes(self):
        records = sample_evidence()
        chunk = list(batches(analysis_records(records)))[0]
        review = batch_result(chunk)
        candidates = candidate_inventory(records, [review])
        self.assertEqual(candidates[0]['id'], 'B1-C1')
        self.assertEqual(candidates[0]['refs'], ['file-change:.config/example.conf'])
        final = final_result(['B1-C1'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            finalize(records, [review], {'version': 'v0.1.0-alpha.1'}, root,
                     'Policy', lambda _: final)
            notes = (root / 'notes.md').read_text()
            report = (root / 'review.md').read_text()
            self.assertIn('## Highlights\n\nAudio controls', notes)
            self.assertIn('## Added\n\n- Audio controls', notes)
            self.assertNotIn('B1-C1', notes)
            self.assertIn('file-change:.config/example.conf', report)
            self.assertIn('aaaaaaaaaaaa', report)
            self.assertIn('#12', report)

    def test_every_candidate_is_published_or_explicitly_omitted(self):
        candidates = [{'id': 'B1-C1'}, {'id': 'B2-C1'}]
        final = final_result(['B1-C1'])
        with self.assertRaises(ValueError):
            validate_final(final, candidates)
        final['omitted'] = [{'id': 'B2-C1', 'reason': 'Duplicate of the audio control.'}]
        self.assertEqual(validate_final(final, candidates), final)
        final['omitted'][0]['id'] = []
        with self.assertRaises(ValueError):
            validate_final(final, candidates)

    def test_migration_follows_the_detailed_change_lists(self):
        final = final_result(['B1-C1'])
        final['migration'] = [{
            'text': 'Existing users must install the new desktop package.',
            'ids': ['B1-C1'],
        }]
        notes = render_notes(final)
        self.assertLess(notes.index('## Added'), notes.index('## Migration'))

    def test_finalization_retries_invalid_candidate_ids(self):
        records = sample_evidence()
        review = batch_result(list(batches(analysis_records(records)))[0])
        invalid = final_result(['ANALYSES 2'])
        valid = final_result(['B1-C1'])
        prompts = []
        responses = iter([invalid, valid])

        def request(prompt):
            prompts.append(prompt)
            return next(responses)

        with tempfile.TemporaryDirectory() as directory:
            finalize(records, [review], {}, Path(directory), 'Policy', request)
        self.assertEqual(len(prompts), 2)
        self.assertIn('PREVIOUS_RELEASE_NOTES:', prompts[0])
        self.assertIn('PREVIOUS_RESPONSE_REJECTED', prompts[1])

    def test_resume_reuses_only_matching_final_state_evidence(self):
        records = sample_evidence()
        chunk = list(batches(analysis_records(records)))[0]
        review = batch_result(chunk)
        reusable = reusable_reviews(records, [review])
        self.assertEqual(reusable[chunk_key(chunk)], review)
        changed = [records[0], file_record('.config/example.conf', diff='+different\n')]
        changed_chunk = list(batches(analysis_records(changed)))[0]
        self.assertNotIn(chunk_key(changed_chunk), reusable)

    def test_analysis_and_probe_use_same_candidate_contract(self):
        records = sample_evidence()
        chunk = list(batches(analysis_records(records)))[0]
        review = batch_result(chunk)
        final = final_result(['B1-C1'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'evidence.json').write_text(json.dumps(records))
            (root / 'state.json').write_text(json.dumps({
                'version': 'v0.1.0-alpha.1', 'analysis_revision': ANALYSIS_REVISION,
            }))
            with patch.dict(os.environ, {'RELEASE_DIR': directory, 'RELEASE_MAX_AI_CALLS': '5',
                                         'RELEASE_RESUME_RUN_ID': ''}):
                with patch('release_analyze.ask', side_effect=[review, final]):
                    analyze()
            self.assertTrue((root / 'notes.md').exists())
            with patch.dict(os.environ, {'RELEASE_RESUME_DIR': directory,
                                         'RELEASE_PROBE_BATCH': 'final'}):
                with patch('release_probe.ask', return_value=final):
                    probe()
            with patch.dict(os.environ, {'RELEASE_RESUME_DIR': directory,
                                         'RELEASE_PROBE_BATCH': '1'}):
                with patch('release_probe.ask', return_value=review):
                    probe()

    def test_release_sections_reject_internal_citations(self):
        valid = '## Highlights\n\nNew controls are available.\n\n## Added\n\n- Control audio.\n'
        self.assertEqual(validate_notes(valid), valid)
        for notes in ['', '## Fixes\n\n- Audio.',
                      '## Highlights\n\nA.\n\n## Highlights\n\nB.',
                      '## Highlights\n\nA.\n\n## Fixed\n\n- Fix audio.\n\n## Added\n\n- A.',
                      '## Highlights\n\nA. [0, 1]\n\n## Added\n\n- Audio.',
                      '## Highlights\n\nA.\n\n## Added\n\n- Audio (B1-C1).',
                      '## Highlights\n\nA.\n\n## Added\n\n- Audio.\n\nFull Changelog: x']:
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
        Path('CHANGELOG.md').write_text(
            '# Changelog\n\n## v0.0.7 - 2026-09-01\n\n### Highlights\n\nOld release.\n')
        self.commit('fix: baseline')
        self.git('tag', 'v0.0.7')
        self.base = self.git('rev-parse', 'HEAD')
        Path('config.txt').write_text('new\n')
        self.commit('feat: new configuration')
        self.source = self.git('rev-parse', 'HEAD')
        self.bundle = Path('bundle')
        self.bundle.mkdir()
        state = {'version': 'v0.1.0-alpha.1', 'base_tag': 'v0.0.7', 'base_sha': self.base,
                 'source_sha': self.source, 'date': '2026-10-01', 'bump': 'minor',
                 'channel': 'alpha', 'analysis_revision': ANALYSIS_REVISION}
        (self.bundle / 'state.json').write_text(json.dumps(state))
        (self.bundle / 'notes.md').write_text(
            '## Highlights\n\nNew configuration is available.\n\n'
            '## Added\n\n- Configure the new control.\n')
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
        self.git('commit', '-qm', 'chore: prepare alpha release')

    def test_round_trip_preserves_history_and_full_notes(self):
        self.release()
        state, notes = validate()
        self.assertEqual(state['source_sha'], self.source)
        self.assertEqual(notes, (self.bundle / 'notes.md').read_text())
        self.assertIn('### Added', Path('CHANGELOG.md').read_text())
        self.assertIn('Old release.', Path('CHANGELOG.md').read_text())

    def test_collector_uses_only_net_changed_paths_with_history_context(self):
        self.git('tag', 'v0.1.0-alpha.1', self.source)
        Path('transient.txt').write_text('temporary\n')
        self.git('add', 'transient.txt')
        self.git('commit', '-qm', 'feat: try temporary file')
        self.git('rm', 'transient.txt')
        self.git('commit', '-qm', 'revert: remove temporary file')
        Path('config.txt').write_text('final\n')
        self.commit('fix: final config')

        def fake_pages(path):
            if path.endswith('/releases'):
                return [{'draft': False, 'tag_name': 'v0.1.0-alpha.1',
                         'body': 'Earlier release'}]
            return []

        settings = {'GITHUB_REF': 'refs/heads/master', 'GITHUB_REPOSITORY': 'test/repo',
                    'RELEASE_BUMP': 'prerelease', 'RELEASE_CHANNEL': 'alpha',
                    'RELEASE_DIR': str(self.bundle)}
        with patch.dict(os.environ, settings), patch('release_collect.pages', fake_pages):
            collect()
        records = json.loads((self.bundle / 'evidence.json').read_text())
        self.assertEqual(previous_release_notes(records), 'Earlier release')
        file_records = analysis_records(records)
        self.assertEqual([record['id'] for record in file_records], ['file-change:config.txt'])
        comparison = json.loads(file_records[0]['content'])
        self.assertEqual(comparison['before'], 'new\n')
        self.assertEqual(comparison['after'], 'final\n')
        self.assertIn('+final', comparison['net_diff'])
        self.assertTrue(any('final config' in item['message']
                            for item in comparison['history_context']['commits']))
        self.assertEqual(json.loads((self.bundle / 'state.json').read_text())['version'],
                         'v0.1.0-alpha.2')

    def test_stale_preparation_is_rejected(self):
        Path('config.txt').write_text('third\n')
        self.commit('fix: another change')
        with self.assertRaises(ValueError):
            build(self.bundle)

    def test_unrelated_changes_are_rejected(self):
        self.release()
        Path('config.txt').write_text('third\n')
        self.commit('fix: unexpected change')
        with self.assertRaises(ValueError):
            validate()

    def test_history_edit_is_rejected(self):
        self.release()
        Path('CHANGELOG.md').write_text(
            Path('CHANGELOG.md').read_text().replace('Old release.', 'Changed history.'))
        self.git('add', 'CHANGELOG.md')
        self.git('commit', '-qm', 'docs: alter history')
        with self.assertRaises(ValueError):
            validate()


if __name__ == '__main__':
    unittest.main()
