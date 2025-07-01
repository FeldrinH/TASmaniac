
"""
Tries to minimize the number of inputs in the file by deleting pairs of inputs as long as the level passes with no time loss.
"""

import sys
import time
import random
from pathlib import Path
from tas_server import TASExecutor, play_level


def normalize(inputs: list[str]) -> list[str]:
    out = []
    
    for line in inputs:
        if not line:
            continue
        frame, *keys = line.split()
        for key in keys:
            out.append(f'{frame} {key}')
    
    return out

def find_input_pair(first_input: str, inputs: list[str]) -> tuple[int | None, int | None]:
    try:
        first_index = inputs.index(first_input)
    except ValueError:
        return None, None
    
    target = first_input.split()[1]
    if target.startswith('+'):
        target = target.replace('+', '-')
    else:
        target = target.replace('-', '+')
    for i in range(first_index + 1, len(inputs)):
        if inputs[i].endswith(target):
            return first_index, i
    
    return first_index, None

def minimize_level(connection, level: int):            
    inputs_file = sorted(Path('recordings').glob(f'lvl{level:03d}_*.txt'))[0]

    with open(inputs_file, mode='r') as f:
        base_inputs = normalize(f.read().splitlines())

    for _ in range(5):
        base_completed, base_duration = play_level(connection, level, base_inputs)
        if base_completed:
            break
        time.sleep(0.5)
    else:
        raise AssertionError(f"Minimizing {inputs_file}: Base inputs in did not complete level")

    # print(f"Minimizing {inputs_file}: {len(base_inputs)} inputs")

    best_duration = base_duration
    best_inputs = base_inputs

    rng = random.Random()

    first_inputs = base_inputs.copy()
    rng.shuffle(first_inputs)

    for first_input in first_inputs:
        new_inputs = best_inputs.copy()
        first_index, second_index = find_input_pair(first_input, new_inputs)
        if first_index is None:
            continue
        if second_index is not None:
            del new_inputs[second_index]
        del new_inputs[first_index]

        new_completed, new_duration = play_level(connection, level, new_inputs)
        if new_completed and new_duration <= best_duration:
            best_duration = new_duration
            best_inputs = new_inputs
    
    return inputs_file, best_duration, base_inputs, best_inputs

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

    with TASExecutor(max_workers=10) as executor:
        for inputs_file, best_duration, base_inputs, best_inputs in executor.map(minimize_level, range(start, end)):
            if len(best_inputs) != len(base_inputs):
                print(f"Minimized {inputs_file} from {len(base_inputs)} inputs to {len(best_inputs)} inputs")

                with open(inputs_file.with_stem(f'{inputs_file.stem.split('_')[0]}_{best_duration / 60:05.2f}_minimized_{len(base_inputs)}_{len(best_inputs)}'), mode='w') as f:
                    f.write('\n'.join(best_inputs))
            else:
                print(f"Minimized {inputs_file}, no change")
