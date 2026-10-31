import hashlib
import json
from pathlib import Path
import unittest
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class FrameOwnershipTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / 'assets/art/frame_manifest.json').read_text())
        cls.owners = {}
        for name, sheet in cls.manifest['sheets'].items():
            path = ROOT / 'assets/art' / name
            rgba = np.array(Image.open(path).convert('RGBA'))
            assert hashlib.sha256(path.read_bytes()).hexdigest() == sheet['sha256']
            owners = np.zeros(rgba.shape[:2], dtype=np.uint16)
            for i, frame in enumerate(sheet['frames']):
                x, y, w, h = frame['box']
                assert x >= 0 and y >= 0 and x+w <= sheet['width'] and y+h <= sheet['height']
                previous_end = 0
                count = 0
                for output, length, source in np.array(frame['runs']).reshape(-1, 3):
                    assert output >= previous_end and output+length <= w*h
                    sy, sx = divmod(source, sheet['width'])
                    oy, ox = divmod(output, w)
                    assert sy == y+oy and sx == x+ox and ox+length <= w
                    assert not np.any(owners[sy, sx:sx+length])
                    assert np.all(rgba[sy, sx:sx+length, 3] > 0)
                    owners[sy, sx:sx+length] = i+1
                    previous_end = output+length
                    count += length
                assert count == frame['pixels']
            cls.owners[name] = owners
            assert np.all(owners[rgba[:, :, 3] > 32] > 0), 'Strong original pixels must not be clipped'

    def test_all_fifty_six_frames_and_no_shared_pixels(self):
        self.assertEqual(sum(len(s['frames']) for s in self.manifest['sheets'].values()), 56)
        self.assertEqual(len(self.owners), 3)

    def test_dog_thrust_keeps_sword_beyond_old_grid(self):
        owner = self.owners['meme_fighters_atlas.png']
        y, x = np.nonzero(owner == 8)  # row 1, dog column 1, index 7
        self.assertGreaterEqual(x.max(), 534)
        self.assertGreater(np.count_nonzero((owner == 8)[:, 512:]), 80)
        # Neighbouring cat's visible core is explicitly owned by its own frame.
        self.assertEqual(int(owner[400, 600]), 9)

    def test_raised_sword_survives_above_old_row(self):
        owner = self.owners['meme_fighters_atlas.png']
        y, x = np.nonzero(owner == 20)  # row 3, dog column 1
        self.assertLessEqual(y.min(), 734)
        self.assertGreater(np.count_nonzero((owner == 20)[:768]), 100)

    def test_dedicated_sheets_keep_cross_cell_limb_pixels(self):
        owners = self.owners['cat_actions.png']
        self.assertGreater(np.nonzero(owners == 7)[1].max(), 940)
        owners = self.owners['gugu_actions.png']
        self.assertLess(np.nonzero(owners == 12)[1].min(), 940)


if __name__ == '__main__':
    unittest.main()
