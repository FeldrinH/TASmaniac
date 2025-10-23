import os
import sys
from typing import Sequence
from pathlib import Path
from queue import PriorityQueue, Empty
import random
from tas_server import TASExecutor, play_level


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

def combine(offsets: Sequence[int], keys: Sequence[str], split_index: int) -> list[str] | None:
    frame = 0
    inputs_out = []
    for i, (offset, key) in enumerate(zip(offsets, keys)):
        if i == split_index:
            frame = 0
        frame += offset
        inputs_out.append((frame, key))
    inputs_out.sort()
    if inputs_out[0][0] < 0:
        return None
    else:
        return [f'{f} {k}' for f, k in inputs_out]

if __name__ == '__main__':
    if len(sys.argv) == 2:
        start = int(sys.argv[1])
        end = start + 1
    elif len(sys.argv) == 3:
        start = int(sys.argv[1])
        end = int(sys.argv[2]) + 1
    else:
        print("ERROR: Expected 1 or 2 arguments")
        sys.exit(1)
    
    MAX_WORKERS = int(os.getenv("TASMANIAC_MAX_WORKERS") or "10")
    NUM_ITERATIONS = int(os.getenv("TASMANIAC_NUM_ITERATIONS") or "20")
    ITERATION_NUM_CANDIDATES = int(os.getenv("TASMANIAC_ITERATION_NUM_CANDIDATES") or "80")

    with TASExecutor(max_workers=MAX_WORKERS) as executor:
        for level in range(start, end):
            inputs_file = sorted(Path('recordings').glob(f'lvl{level:03d}_*.txt'))[0]

            with open(inputs_file, mode='r') as f:
                base_inputs = f.read().splitlines()

            base_offsets, keys, split_index = split(base_inputs)
            base_offsets = tuple(base_offsets)

            base_completed, base_duration = executor.submit(lambda conn: play_level(conn, level, base_inputs)).result()
            if not base_completed:
                raise AssertionError(f"Optimizing {inputs_file}: Base inputs in did not complete level")
            print(f"Optimizing {inputs_file}: {base_duration} frames ({base_duration / 60:.2f} seconds), {len(base_offsets)} offsets")

            visited = set[tuple[int, ...]]()
            queue = PriorityQueue[tuple[int, tuple[int, ...]]]()
            visited.add(base_offsets)
            queue.put((base_duration, base_offsets))

            best_duration = base_duration
            best_offsets = base_offsets

            rng = random.Random()

            for _ in range(NUM_ITERATIONS):
                try:
                    _, offsets = queue.get_nowait()
                except Empty:
                    break
                
                all_new_offsets = []
                for _ in range(ITERATION_NUM_CANDIDATES):
                    new_offsets = list(offsets)
                    random_index = rng.randrange(len(new_offsets))
                    random_offset = rng.randint(-10, 10)
                    new_offsets[random_index] += random_offset
                    new_offsets = tuple(new_offsets)
                    if new_offsets in visited:
                        continue
                    all_new_offsets.append(new_offsets)
                    visited.add(new_offsets)
                
                def evaluate(connection, new_offsets):
                    new_inputs = combine(new_offsets, keys, split_index)
                    if new_inputs is None:
                        completed, duration = False, 0
                    else:
                        completed, duration = play_level(connection, level, new_inputs)
                    return completed, duration, new_offsets
                
                for completed, duration, new_offsets in executor.map(evaluate, all_new_offsets):
                    if completed:
                        if duration < best_duration:
                            best_duration = duration
                            best_offsets = new_offsets
                            print(f"New best: {duration} frames ({duration / 60:.2f} seconds)")
                        queue.put((duration, new_offsets))
                
                print(f"Queue: {queue.qsize()} items, Visited: {len(visited)} items")
            print()

            if best_duration < base_duration:
                best_inputs = combine(best_offsets, keys, split_index)
                assert best_inputs is not None
                with open(inputs_file.with_stem(f'{inputs_file.stem.split('_')[0]}_{best_duration / 60:05.2f}_optimized'), mode='w') as f:
                    f.write('\n'.join(best_inputs))
