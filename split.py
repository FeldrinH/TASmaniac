from pathlib import Path
import sys
import time
from watchdog.events import FileModifiedEvent
from watchdog.observers import Observer


def do_split(input_file: Path, output_file: Path):
    with open(input_file, mode='r') as f:
        inputs = f.read().splitlines()

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
    
    for inputs in [out_left, out_right]:
        last_frame = 0
        for i, (frame, key) in enumerate(inputs):
            offset = frame - last_frame
            last_frame = frame
            inputs[i] = f'{offset} {key}'
    
    with open(output_file, mode='w') as f:
        f.write('# Left\n')
        f.write('\n'.join(out_left))
        f.write('\n\n# Right\n')
        f.write('\n'.join(out_right))
    
    print(f"Written split output to {output_file}")

def do_combine(input_file: Path, output_file: Path):
    with open(input_file, mode='r') as f:
        inputs = f.read().splitlines()
    
    left_found, right_found = False, False
    frame = 0
    inputs_out = []
    for line in inputs:
        line = line.strip()
        if not line:
            continue
        if line.startswith('#'):
            section = line.removeprefix('#').strip()
            if section == 'Left':
                if left_found:
                    print("ERROR: Multiple left sections found")
                    sys.exit(1)
                left_found = True
                frame = 0
            elif section == 'Right':
                if right_found:
                    print("ERROR: Multiple right sections found")
                    sys.exit(1)
                right_found = True
                frame = 0
            else:
                print(f"ERROR: Unknown section: {section}")
                sys.exit(1)
            continue
        offset, keys = line.split(maxsplit=1)
        frame += int(offset)
        inputs_out.append((frame, keys))
    inputs_out.sort()

    with open(output_file, mode='w') as f:
        f.write('\n'.join(f'{f} {k}' for f, k in inputs_out))
    
    print(f"Written combined output to {output_file}")

if __name__ == '__main__':
    if sys.argv[1] == 'split':
        input_file = Path(sys.argv[2])
        output_file = input_file.with_stem(input_file.stem + '_split')
        func = lambda: do_split(input_file, output_file)
    elif sys.argv[1] == 'combine':
        input_file = Path(sys.argv[2])
        output_file = input_file.with_stem(input_file.stem.removesuffix('_split') + '_combined')
        func = lambda: do_combine(input_file, output_file)
    else:
        print(f"ERROR: Unknown command: {sys.argv[1]}")
        sys.exit(1)
    
    if '--watch' in sys.argv[1:]:
        from watchdog.events import FileModifiedEvent, FileSystemEventHandler

        class EventHandler(FileSystemEventHandler):
            def on_modified(self, event):
                if event.src_path == str(input_file):
                    func()

        observer = Observer()
        observer.schedule(EventHandler(), str(input_file.parent), event_filter=[FileModifiedEvent])
        observer.start()
        try:
            func()
            while True:
                time.sleep(1000)
        finally:
            observer.stop()
            observer.join()
    else:
        func()