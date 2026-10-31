#!/usr/bin/env python3
"""Audit original atlas pixels and describe isolated frame ownership.

This writes metadata only: source PNGs are never edited. Godot decodes each
frame from its own pixel runs, retaining weapons that cross nominal grid cells.
"""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
CAT_HEADS = [(.58,.24,0),(.58,.24,0),(.58,.24,0),(.64,.46,0),
             (.55,.26,0),(.55,.28,0),(.43,.28,0),(.46,.23,0),
             (.42,.25,-.2),(.60,.26,0),(.52,.28,0),(.54,.32,0),
             (.54,.32,0),(.59,.33,0),(.35,.28,-.35),(.78,.55,1.25)]
SHEETS = {'meme_fighters_atlas.png': 6, 'gugu_actions.png': 4, 'cat_actions.png': 4}


def describe(path, columns):
    rgba = np.asarray(Image.open(path).convert('RGBA'))
    height, width = rgba.shape[:2]
    strong = rgba[:, :, 3] > 32
    labels, _ = ndimage.label(strong, np.ones((3, 3), dtype=bool))
    sizes = np.bincount(labels.ravel())
    objects = ndimage.find_objects(labels)
    primary = np.flatnonzero(sizes >= 10000)
    primary = primary[primary != 0]
    if len(primary) != columns * 4:
        raise ValueError(f'{path.name}: expected {columns * 4} separate body cores, found {len(primary)}')
    core_owner = np.zeros_like(labels, dtype=np.uint16)
    frames = [None] * (columns * 4)
    cell_w, cell_h = width / columns, height / 4
    for component in primary:
        ys, xs = objects[component - 1]
        col = min(columns - 1, int((xs.start + xs.stop) * 0.5 / cell_w))
        row = min(3, int((ys.start + ys.stop) * 0.5 / cell_h))
        index = row * columns + col
        if frames[index] is not None:
            raise ValueError(f'{path.name}: two body cores in slot {index}')
        core_owner[labels == component] = index + 1
        # A shared foot baseline avoids per-pose vertical jumps. Weapons do not
        # affect this anchor: the main body core determines its contact point.
        ref_h = cell_h - 20
        frames[index] = {
            'slot': [col, row], 'core_area': int(sizes[component]),
            'core_box': [xs.start, ys.start, xs.stop - xs.start, ys.stop - ys.start],
            'reference': [col * cell_w + 10, ys.stop - ref_h * 23 / 24, cell_w - 20, ref_h],
        }
    if any(frame is None for frame in frames):
        raise ValueError(f'{path.name}: missing body core')
    distance, nearest = ndimage.distance_transform_edt(core_owner == 0, return_indices=True)
    nearest_owner = core_owner[tuple(nearest)]
    owner = core_owner.copy()
    # Attach a disconnected weapon, tear, or effect as a complete component,
    # based on its closest contact to a body. Do not split long sword tips by
    # grid lines or a per-pixel nearest-body Voronoi boundary.
    for component, box in enumerate(objects, 1):
        if box is None or component in primary:
            continue
        ys, xs = box
        part = labels[ys, xs] == component
        local_distance = np.where(part, distance[ys, xs], np.inf)
        y, x = np.unravel_index(np.argmin(local_distance), local_distance.shape)
        target = int(nearest_owner[ys.start + y, xs.start + x])
        owner[ys, xs][part] = target
    # Retain the original anti-aliased edge pixels up to 3px from the strong
    # silhouette. Faint background bridges between poses are not sprite parts.
    edge_distance, edge_nearest = ndimage.distance_transform_edt(owner == 0, return_indices=True)
    soft = (rgba[:, :, 3] > 0) & (owner == 0) & (edge_distance <= 3)
    owner[soft] = owner[tuple(edge_nearest)][soft]
    if np.any(strong & (owner == 0)):
        raise ValueError('Visible sprite pixels lost during frame assignment')
    for index, frame in enumerate(frames):
        ys, xs = np.nonzero(owner == index + 1)
        x0, y0 = max(0, int(xs.min()) - 3), max(0, int(ys.min()) - 3)
        x1, y1 = min(width, int(xs.max()) + 4), min(height, int(ys.max()) + 4)
        frame['box'] = [x0, y0, x1 - x0, y1 - y0]
        runs = []
        pixel_count = 0
        for y in range(y0, y1):
            row = owner[y, x0:x1] == index + 1
            edges = np.flatnonzero(np.diff(np.pad(row.astype(np.int8), (1, 1))))
            for left, right in zip(edges[::2], edges[1::2]):
                # output pixel offset, run length, original atlas pixel offset
                runs.extend([(y - y0) * (x1 - x0) + int(left), int(right - left), y * width + x0 + int(left)])
                pixel_count += int(right - left)
        frame['runs'] = runs
        frame['pixels'] = pixel_count
        if path.name == 'cat_actions.png':
            u, v, angle = CAT_HEADS[index]
            col, row = frame['slot']
            anchor = (col*cell_w+u*cell_w, row*cell_h+v*cell_h)
            frame['head_anchor'] = list(anchor)
            frame['attachments'] = []
            for side in [-1, 1]:
                points = []
                for dx, dy in [(side*.03*cell_w, 0), (side*.16*cell_w, -.14*cell_h), (side*.17*cell_w, .05*cell_h)]:
                    points.append([anchor[0]+dx*math.cos(angle)-dy*math.sin(angle),
                                   anchor[1]+dx*math.sin(angle)+dy*math.cos(angle)])
                frame['attachments'].append(points)
    return {'width': width, 'height': height, 'columns': columns, 'rows': 4,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'frames': frames}


def main():
    sheets = {name: describe(ROOT / 'assets/art' / name, columns) for name, columns in SHEETS.items()}
    manifest = {'version': 1, 'method': 'alpha components, complete fragment ownership, original pixel runs',
                'sheets': sheets}
    output = ROOT / 'assets/art/frame_manifest.json'
    output.write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
    for name, sheet in sheets.items():
        print(f'{name}: {len(sheet["frames"])} isolated frames, all strong pixels retained')
    print(f'{output.name}: {output.stat().st_size} bytes')


if __name__ == '__main__':
    main()
