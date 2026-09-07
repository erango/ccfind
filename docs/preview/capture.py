#!/usr/bin/env python3
"""Run a command inside a pty of an exact size and dump the raw bytes it writes."""
import os, pty, sys, fcntl, termios, struct, select

cols, rows = int(sys.argv[1]), int(sys.argv[2])
cmd = sys.argv[3:]

pid, fd = pty.fork()
if pid == 0:
    # size the tty from inside the child, before the command can read it
    os.execvp("sh", ["sh", "-c", f'stty rows {rows} cols {cols}; exec "$@"', "sh", *cmd])

fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

out = b""
answered = False
while True:
    try:
        r, _, _ = select.select([fd], [], [], 1.5)
    except OSError:
        break
    if not r:
        if answered:
            break
        # the command is sitting at its prompt; answer it and keep reading
        os.write(fd, os.environ.get("CAPTURE_ANSWER", "q\n").encode())
        answered = True
        continue
    try:
        chunk = os.read(fd, 65536)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
os.waitpid(pid, 0)
sys.stdout.buffer.write(out)
