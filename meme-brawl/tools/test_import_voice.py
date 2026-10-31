import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("import_voice", Path(__file__).with_name("import_voice.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ImportVoiceTests(unittest.TestCase):
    def test_conversion_provenance_and_preservation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "fixture.wav"
            subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i",
                            "sine=frequency=440:duration=1", str(source)], check=True)
            arguments = (source, root / "out", "cat", "ca", 0.1, 0.3,
                         "https://example.com/test-fixture", "Synthetic test fixture, not a meme recording")
            clip = module.import_voice(*arguments)
            self.assertGreater(clip.stat().st_size, 100)
            record = json.loads((clip.parent / "sources.json").read_text())["recordings"][clip.name]
            self.assertEqual(len(record["sha256"]), 64)
            self.assertAlmostEqual(record["duration_seconds"], 0.3, delta=0.05)
            before = clip.read_bytes()
            with self.assertRaises(FileExistsError):
                module.import_voice(*arguments)
            self.assertEqual(clip.read_bytes(), before)
            with self.assertRaises(ValueError):
                module.import_voice(source, root / "out", "cat", "ca", -1, 1, "invalid", "")


if __name__ == "__main__":
    unittest.main()
