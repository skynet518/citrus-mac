from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parent.parent
binary_dir = subprocess.check_output(['swift', 'build', '--package-path', str(root / 'native'), '-c', 'release', '--show-bin-path'], text=True).strip()
binary = Path(binary_dir) / 'CitrusNative'
output = root / 'test-output'
output.mkdir(exist_ok=True)
main_run = subprocess.run([str(binary), '--verify', str(output / 'functional')], capture_output=True, text=True)
(output / 'functional.log').write_text(main_run.stdout + main_run.stderr)
result = json.loads((output / 'functional/latest.json').read_text())
assert main_run.returncode == 0, result.get('runner_error')
assert result['status'] == 'PASS' and result['passed'] == 108 and result['failed'] == 0 and result['skipped'] == 0, result
probe = subprocess.run([str(binary), '--verify', str(output / 'failure-probe'), '--failure-probe'], capture_output=True, text=True)
(output / 'failure-probe.log').write_text(probe.stdout + probe.stderr)
failure = json.loads((output / 'failure-probe/latest.json').read_text())
assert probe.returncode != 0 and failure['status'] == 'FAIL' and failure['failed'] == 1
assert failure['checks'][0]['name'] == 'forced_failure_probe'
receipt = {'functional_passed': result['passed'], 'functional_failed': 0, 'functional_skipped': 0,
           'failure_receipt_probe': 'PASS', 'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}
(output / 'summary.json').write_text(json.dumps(receipt, indent=2))
print(json.dumps(receipt, indent=2))
