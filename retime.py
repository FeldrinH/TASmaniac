import sys
from typing import Sequence
from pathlib import Path
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
    if len(sys.argv) == 2:
        start = int(sys.argv[1])
        end = start + 1
    elif len(sys.argv) == 3:
        start = int(sys.argv[1])
        end = int(sys.argv[2]) + 1
    else:
        print(f"ERROR: Expected 1 or 2 arguments")
        sys.exit(1)

    with TASExecutor(max_workers=6) as executor:
        for level in range(start, end):
            inputs_file = sorted(Path('recordings').glob(f'lvl{level:03d}_*.txt'))[0]

            expected_time = float(inputs_file.stem.split('_')[1])
            
            with open(inputs_file, mode='r') as f:
                base_inputs = f.read().splitlines()

            repeats = 20
            durations = [] 

            for completed, duration in executor.map(lambda conn, _: play_level(conn, level, base_inputs), range(repeats)):
                if completed:
                    durations.append(duration)
            
            if len(durations) < repeats:
                print(f"{inputs_file}: Unreliable inputs: {len(durations) / repeats * 100:.0f}% of runs completed successfully")
                continue
            
            distinct_durations = set(durations)
            if len(distinct_durations) != 1:
                print(f"{inputs_file}: Inconsistent times: {min(distinct_durations) / 60:.2f} - {max(distinct_durations) / 60:.2f} seconds")
                continue

            if float(f"{durations[0] / 60:.2f}") != expected_time:
                print(f"{inputs_file}: Mismatched time: expected {expected_time:.2f} seconds, got {durations[0] / 60:.2f} seconds")
                continue
            
            print(f"{inputs_file}: Time matches")
