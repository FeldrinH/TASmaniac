import sys
from pathlib import Path
from tas_server import TASExecutor, play_level


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
