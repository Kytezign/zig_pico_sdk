# Just runs zig build load
# Not great at VS code and I like single button build/run.
import os, sys

sys.tracebacklimit = 2

def system(cmd):
    ret = os.system(cmd)
    if ret:
        raise RuntimeError(f"Command Failed: {cmd} \n    ret:{ret}")

if __name__ == "__main__":
    os.chdir("src")
    system("clear")
    system('zig build load')