from typing import Sequence
from pathlib import Path
from queue import PriorityQueue, Empty
import random
from server import connect, play_level


def split(inputs: list[str]) -> tuple[list[int], list[str], int]:
    out_left = []
    out_right = []
    for line in inputs:
        if not line:
            continue
        frame, *keys = line.split()
        for key in keys:
            if key[1] in {'W', 'A', 'D'}:
                out_left.append((int(frame), key))
            else:
                out_right.append((int(frame), key))
    
    offsets = []
    keys = []
    split_index = len(out_left)
    for out in (out_left, out_right):
        last_frame = 0
        for frame, key in out:
            offset = frame - last_frame
            last_frame = frame
            offsets.append(offset)
            keys.append(key)
    
    return offsets, keys, split_index

def combine(offsets: Sequence[int], keys: Sequence[str], split_index: int) -> list[str]:
    frame = 0
    inputs_out = []
    for i, (offset, key) in enumerate(zip(offsets, keys)):
        if i == split_index:
            frame = 0
        frame += offset
        inputs_out.append((frame, key))
    inputs_out.sort()
    return [f'{f} {k}' for f, k in inputs_out]

if __name__ == '__main__':
    # 0 and 101 are excluded for now, because 0 needs some kind of timeout to avoid infinite runs
    # and 101 is just too long to optimize with such a brute force method.
    for level in range(1, 101):
        inputs_file = sorted(Path('recordings').glob(f'lvl{level:03d}_*.txt'))[0]

        with open(inputs_file, mode='r') as f:
            base_inputs = f.read().splitlines()

        with connect() as connection:
            base_offsets, keys, split_index = split(base_inputs)
            base_offsets = tuple(base_offsets)

            base_completed, base_duration = play_level(connection, level, base_inputs)
            if not base_completed:
                raise AssertionError(f"Optimizing {inputs_file}: Base inputs in did not complete level")
            print(f"Optimizing {inputs_file}: {base_duration} frames, {len(base_offsets)} offsets")

            visited = set[tuple[int, ...]]()
            queue = PriorityQueue[tuple[int, tuple[int, ...]]]()
            visited.add(base_offsets)
            queue.put((base_duration, base_offsets))

            best_duration = base_duration
            best_inputs = base_inputs

            rng = random.Random()

            for _ in range(20):
                try:
                    _, offsets = queue.get_nowait()
                except Empty:
                    break
                
                for _ in range(20):
                    new_offsets = list(offsets)
                    random_index = rng.randrange(len(new_offsets))
                    random_offset = rng.randint(-10, 10)
                    new_offsets[random_index] += random_offset
                    new_offsets = tuple(new_offsets)
                    if new_offsets[random_index] < 0 or new_offsets in visited:
                        continue
                    new_inputs = combine(new_offsets, keys, split_index)
                    completed, duration = play_level(connection, level, new_inputs)
                    if completed:
                        if duration < best_duration:
                            best_duration = duration
                            best_inputs = new_inputs
                            print(f"New best: {duration} frames")
                        visited.add(new_offsets)
                        queue.put((duration, new_offsets))
                
                print(f"Queue: {queue.qsize()} items, Visited: {len(visited)} items")
            print()

            if best_duration < base_duration:
                with open(inputs_file.with_stem(f'{inputs_file.stem.split('_')[0]}_{best_duration / 60:05.2f}_optimized'), mode='w') as f:
                    f.write('\n'.join(best_inputs))
