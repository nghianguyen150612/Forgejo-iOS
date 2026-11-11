#!/usr/bin/env python3
"""Full-graph, resource-measured govulncheck; incomplete scans fail closed.

No package partition or exclusion is used. JSON streams and stderr remain in
the output directory, together with explicit application-package coverage.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def json_stream(path):
    data = path.read_text()
    decoder = json.JSONDecoder()
    while data.strip():
        data = data.lstrip()
        item, end = decoder.raw_decode(data)
        yield item
        data = data[end:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--tool', default='govulncheck')
    parser.add_argument('--tags', default='sqlite,sqlite_unlock_notify')
    parser.add_argument('--timeout', type=int, default=1800)
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    # Native toolchain builds unpack the Go distribution below build/ios.
    # Scan exactly the committed application, never those compiler test trees
    # or untracked assets. No tracked application package is filtered out.
    snapshot = tempfile.TemporaryDirectory(prefix='source-', dir=args.output)
    source_root = Path(snapshot.name)
    with subprocess.Popen(['git', 'archive', 'HEAD'], stdout=subprocess.PIPE) as archive:
        subprocess.run(['tar', '-xf', '-', '-C', str(source_root)], stdin=archive.stdout, check=True)
        archive.stdout.close()
        if archive.wait() != 0:
            raise RuntimeError('cannot archive the exact source commit')
    env = dict(os.environ)
    env.setdefault('GOMEMLIMIT', '3GiB')
    env.setdefault('GOMAXPROCS', '2')
    env.setdefault('GOFLAGS', '-p=2')
    report = {
        'timestamp_utc': datetime.now(timezone.utc).isoformat(),
        'source_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
        'tags': args.tags, 'patterns': ['./...'], 'excluded_packages': [],
        'source_selection': 'git archive HEAD; all tracked application packages, no generated compiler test tree',
        'tool_version': subprocess.check_output([args.tool, '-version'], text=True, env=env).strip(),
        'go_env': json.loads(subprocess.check_output(['go', 'env', '-json', 'GOVERSION', 'GOOS', 'GOARCH', 'CGO_ENABLED', 'GOTOOLCHAIN', 'GOFLAGS'], env=env, text=True)),
        'limits': {k: env[k] for k in ('GOMEMLIMIT', 'GOMAXPROCS', 'GOFLAGS')},
        'platform_scope': 'host source graph; native iOS binary requires separate validation',
        'scans': {}, 'advisories': {},
    }
    def cgroup():
        return {name: Path('/sys/fs/cgroup', name).read_text().strip()
                for name in ('memory.max', 'memory.events', 'pids.max')
                if Path('/sys/fs/cgroup', name).is_file()}
    report['cgroup_before'] = cgroup()
    listed = subprocess.run(['go', 'list', '-tags=' + args.tags, './...'], cwd=source_root, env=env, text=True, capture_output=True)
    (args.output / 'packages.txt').write_text(listed.stdout)
    (args.output / 'packages.stderr').write_text(listed.stderr)
    report['application_packages'] = listed.stdout.splitlines()
    report['package_list_exit'] = listed.returncode
    blocked = listed.returncode != 0
    if not blocked:
        for level in ('module', 'package', 'symbol'):
            command = [args.tool, '-json', '-scan=' + level]
            if level != 'module':
                command += ['-tags=' + args.tags, './...']
            timing = args.output / (level + '.time')
            command = ['/usr/bin/time', '-v', '-o', str(timing), 'timeout', '--signal=TERM', '--kill-after=30', str(args.timeout)] + command
            start = time.monotonic()
            output = args.output / (level + '.json')
            with output.open('w') as stdout, (args.output / (level + '.stderr')).open('w') as stderr:
                result = subprocess.run(command, cwd=source_root, env=env, stdout=stdout, stderr=stderr)
            scan = {'command': command, 'exit_code': result.returncode, 'seconds': round(time.monotonic() - start, 3), 'complete': False}
            try:
                messages = list(json_stream(output))
                scan['complete'] = result.returncode in (0, 3) and any('SBOM' in m or 'sbom' in m for m in messages)
                scan['finding_count'] = sum('finding' in m for m in messages)
                for message in messages:
                    if 'osv' in message:
                        osv = message['osv']
                        advisory = report['advisories'].setdefault(osv['id'], {'levels': [], 'findings': []})
                        advisory.update(summary=osv.get('summary'), aliases=osv.get('aliases', []), affected=osv.get('affected', []), references=osv.get('references', []))
                    if 'finding' in message:
                        finding = message['finding']
                        advisory = report['advisories'].setdefault(finding['osv'], {'levels': [], 'findings': []})
                        if level not in advisory['levels']:
                            advisory['levels'].append(level)
                        trace = finding.get('trace', [])
                        evidence_level = 'reachable-symbol' if any(f.get('function') for f in trace) else ('imported-package' if any(f.get('package') for f in trace) else 'required-module')
                        advisory['findings'].append({'scan': level, 'evidence_level': evidence_level, **finding})
            except (ValueError, KeyError) as error:
                scan['parse_error'] = str(error)
            if timing.exists():
                scan['resource_measurement'] = timing.read_text()
            report['scans'][level] = scan
            blocked |= not scan['complete']
    report['cgroup_after'] = cgroup()
    findings = any(a['findings'] for a in report['advisories'].values())
    report['status'] = 'BLOCKED' if blocked else ('FAILED' if findings else 'VERIFIED PASS')
    report['coverage'] = 'all listed packages; no exclusions' if not blocked else 'incomplete; inspect per-scan completion and package list'
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('source_sha', 'status', 'coverage')}, indent=2))
    snapshot.cleanup()
    return 2 if blocked else (3 if findings else 0)


if __name__ == '__main__':
    raise SystemExit(main())
