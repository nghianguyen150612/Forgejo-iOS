"""Negative fixtures for scan coverage, truncation and external termination."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCANNER = Path(__file__).with_name('p028-govulncheck.py').resolve()


class ScanEvidenceTests(unittest.TestCase):
    def run_case(self, case):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, binaries = root / 'repo', root / 'bin'
            source.mkdir()
            binaries.mkdir()
            subprocess.run(['git', 'init', '-q', str(source)], check=True)
            (source / 'tracked-marker').write_text('exact source')
            subprocess.run(['git', 'add', '.'], cwd=source, check=True)
            subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], cwd=source, check=True)
            (source / 'untracked-toolchain-test.go').write_text('deliberately invalid')
            go = binaries / 'go'
            go.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
if sys.argv[1] == 'env':
 print(json.dumps({'GOVERSION':'go1.26.11','GOOS':'linux','GOARCH':'amd64','CGO_ENABLED':'1'}))
else:
 assert pathlib.Path('tracked-marker').is_file()
 assert not pathlib.Path('untracked-toolchain-test.go').exists()
 assert sys.argv[1:] == ['list','-tags=sqlite,sqlite_unlock_notify','./...']
 if os.environ['SCAN_FIXTURE_CASE'] == 'inventory-failure': sys.exit(1)
 print('fixture/root\\nfixture/application')
''')
            tool = binaries / 'govulncheck'
            tool.write_text('''#!/usr/bin/env python3
import json, os, sys
if '-version' in sys.argv: print('govulncheck fixture'); sys.exit(0)
level = next(a.split('=',1)[1] for a in sys.argv if a.startswith('-scan='))
if level != 'module': assert sys.argv[-2:] == ['-tags=sqlite,sqlite_unlock_notify','./...']
print(json.dumps({'SBOM':{'modules':[]}}))
case = os.environ['SCAN_FIXTURE_CASE']
if case == 'killed' and level == 'symbol': sys.exit(137)
if case == 'truncated' and level == 'symbol': print('{'); sys.exit(0)
if case == 'advisory':
 print(json.dumps({'finding':{'osv':'GO-fixture','trace':[{'module':'fixture/dependency'}]}}))
''')
            go.chmod(0o755)
            tool.chmod(0o755)
            env = {**os.environ, 'PATH': str(binaries) + os.pathsep + os.environ['PATH'], 'SCAN_FIXTURE_CASE': case}
            output = root / 'evidence'
            result = subprocess.run(['python3', str(SCANNER), '--output', str(output), '--tool', str(tool)], cwd=source, env=env, capture_output=True, text=True)
            self.assertTrue((output / 'report.json').is_file(), result.stderr)
            return result.returncode, json.loads((output / 'report.json').read_text())

    def test_complete_inventory_keeps_all_application_packages(self):
        code, report = self.run_case('clean')
        self.assertEqual(code, 0)
        self.assertEqual(report['status'], 'VERIFIED PASS')
        self.assertEqual(report['application_packages'], ['fixture/root', 'fixture/application'])
        self.assertEqual(set(report['scans']), {'module', 'package', 'symbol'})
        self.assertEqual(report['excluded_packages'], [])

    def test_module_advisory_is_not_reachable_symbol_evidence(self):
        code, report = self.run_case('advisory')
        self.assertEqual(code, 3)
        self.assertEqual(report['status'], 'FAILED')
        self.assertTrue(all(f['evidence_level'] == 'required-module' for f in report['advisories']['GO-fixture']['findings']))

    def test_killed_or_truncated_symbol_scan_cannot_pass(self):
        for case in ('killed', 'truncated'):
            with self.subTest(case=case):
                code, report = self.run_case(case)
                self.assertEqual(code, 2)
                self.assertEqual(report['status'], 'BLOCKED')
                self.assertFalse(report['scans']['symbol']['complete'])

    def test_failed_inventory_cannot_claim_partial_coverage(self):
        code, report = self.run_case('inventory-failure')
        self.assertEqual(code, 2)
        self.assertEqual(report['status'], 'BLOCKED')
        self.assertEqual(report['scans'], {})


if __name__ == '__main__':
    unittest.main()
