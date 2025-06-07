import json
import subprocess
from threading import Lock
from concurrent.futures import Future, ThreadPoolExecutor
from contextvars import ContextVar
from typing import Callable, Iterable
import websockets.sync.client as client
from websockets.sync.connection import Connection


# Before running this script start the TASmaniac WebSocket server by running launch_tasmaniac_server.bat.
# Required libraries: `pip install websockets`.


_lock = Lock()
_next_port = 7112

_connection = ContextVar[Connection]('connection')

class TASExecutor:
    """
    Thread pool executor that starts a new TASmaniac server for each worker thread.
    The corresponding connection is passed as an argument to functions executed using `submit` and `map`.
    This allows you to run multiple commands in parallel on separate servers, to take better advantage of having multiple CPU cores.
    """

    def __init__(self, max_workers: int) -> None:
        self._max_workers = max_workers
        self._executor = ThreadPoolExecutor(max_workers=max_workers, initializer=self._create_connection)
        self._processes = []
        self._connections = []
    
    def _create_connection(self):
        global _next_port
        with _lock:
            port = _next_port
            _next_port += 1
            process = subprocess.Popen(['.\\launch_tasmaniac_server.bat', f'--server={port}'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self._processes.append(process)
            connection = connect(f'ws://localhost:{port}')
            self._connections.append(connection)
        _connection.set(connection)
    
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self._executor.shutdown(wait=True, cancel_futures=True)
        for connection in self._connections:
            connection.close()
        for process in self._processes:
            process.terminate() # TODO: This does not work on Windows due to some quirk with how .bat files start subprocesses
    
    def submit[T](self, fn: Callable[[Connection], T]) -> Future[T]:
        return self._executor.submit(lambda: fn(_connection.get()))

    def map[V, T](self, fn: Callable[[Connection, V], T], iterable: Iterable[V]) -> Iterable[T]:
        return self._executor.map(lambda v: fn(_connection.get(), v), iterable)


def connect(url = 'ws://localhost:7111') -> Connection:
    """
    Connect to TASmaniac WebSocket server. Use this with a `with` block to automatically clean up the connection.
    """
    return client.connect(url)

def play_level(connection: Connection, level: int, inputs: list[str], start_positions: list[tuple[float, float]] | None = None) -> tuple[bool, int]:
    """
    Play a level with the given inputs and return a result indicating if the level was completed successfully and how many ticks it took to finish.

    If start_positions is given then the players will be teleported to the given positions at the start of the level.
    """

    connection.send(json.dumps({'command': 'play_level', 'level': level, 'inputs': inputs, 'start_positions': start_positions}))
    response = json.loads(connection.recv(decode=True))

    if response['status'] != 'executed':
        raise AssertionError(f"Unexpected response from TAS: {response}")
    if response['duration_ticks'] <= 0:
        raise AssertionError(f"Suspicious duration: {response['duration_ticks']}")

    return response['level_completed'], response['duration_ticks']

if __name__ == '__main__':
    # Usage example

    level = 22
    inputs_file = 'recordings/lvl022_05.32.txt'

    with open(inputs_file, mode='r') as f:
        inputs = f.read().splitlines()

    with connect() as connection:
        print(play_level(connection, level, inputs))
