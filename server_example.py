import json
from websockets.sync.client import connect
from websockets.sync.connection import Connection


# Before running this script start the TASmaniac WebSocket server by running launch_tasmaniac_server.bat.
# Required libraries: `pip install websockets`.

def play_level(websocket: Connection, level: int, inputs: list[str], start_positions: list[tuple[float, float]] | None = None) -> tuple[bool, int]:
    """
    Play a level with the given inputs and return a result indicating if the level was completed successfully and how many ticks it took to finish.

    If start_positions is given then the players will be teleported to the given positions at the start of the level.
    """

    websocket.send(json.dumps({'command': 'play_level', 'level': level, 'inputs': inputs, 'start_positions': start_positions}))
    response = json.loads(websocket.recv(decode=True))

    if response['status'] != 'executed':
        raise AssertionError(f"Unexpected response from TAS: {response}")
    if response['duration_ticks'] <= 0:
        raise AssertionError(f"Suspicious duration: {response['duration_ticks']}")

    return response['level_completed'], response['duration_ticks']

if __name__ == '__main__':

    level = 22
    inputs_file = 'recordings/lvl022_05.32.txt'

    with open(inputs_file, mode='r') as f:
        inputs = f.read().splitlines()

    with connect('ws://localhost:7111') as websocket:
        print(play_level(websocket, level, inputs))
