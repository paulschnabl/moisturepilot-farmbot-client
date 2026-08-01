import hashlib
import importlib.util
import json
import os
import tempfile
import unittest
import zipfile
from pathlib import Path


os.environ.setdefault("MP_BACKUP_API_URL", "https://moisture.test")
SPEC = importlib.util.spec_from_file_location(
    "moisturepilot_sync", Path(__file__).with_name("moisturepilot_sync.py")
)
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class SyncSecurityTests(unittest.TestCase):
    def test_manifest_verification_accepts_complete_run(self):
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary) / "run-1"
            (run / "input").mkdir(parents=True)
            (run / "output").mkdir()
            (run / "input" / "photo.jpg").write_bytes(b"photo")
            (run / "research_report.pdf").write_bytes(b"%PDF-test")
            files = []
            for path in (run / "input" / "photo.jpg", run / "research_report.pdf"):
                files.append({
                    "path": str(path.relative_to(run)),
                    "bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                })
            manifest = run / "manifest.json"
            manifest.write_text(json.dumps({"files": files}))
            sync.verify_run(run, sync.sha256_file(manifest))

    def test_safe_extract_rejects_parent_traversal(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "bad.zip"
            with zipfile.ZipFile(archive, "w") as output:
                output.writestr("../escape.txt", "bad")
            with self.assertRaises(ValueError):
                sync.safe_extract(archive, root / "output")


if __name__ == "__main__":
    unittest.main()
