import datetime
import os
import time


LOG = "./boxmon.log"
logfile = open(LOG, 'a')


# Process display codes
REFERENCE = 0
ADDED = 1
REMOVED = 2


class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class Process:
    def __init__(self, pid, cmdline, parent):
        self.pid = pid
        self.cmdline = cmdline
        self.parent = parent

        # Defaults for display only
        self.display = REFERENCE
        self.disp_children: list[Process] = []

    def paint(self, prefix="", pass_down_prefix="  "):
        indicator = {
            REFERENCE: "",
            ADDED: f"{Colors.GREEN}+",
            REMOVED: f"{Colors.RED}-"
        }[self.display]
        end = {
            REFERENCE: "",
            ADDED: Colors.END,
            REMOVED: Colors.END
        }[self.display]
        print(f"{prefix}{indicator}{self.pid}: {self.cmdline}{end}")
        for c in self.disp_children:
            c.paint(prefix + pass_down_prefix, pass_down_prefix)


def processes():
    _res = dict()
    for _pid in os.listdir("/proc"):
        try:
            _pid = int(_pid)
            cmdline = open(f'/proc/{_pid}/cmdline').read()
            ppid = None
            for l in open(f'/proc/{_pid}/status').readlines():
                if l.startswith('PPid:'):
                    try:
                        ppid = int(l[len('PPid:\t'):].strip())
                    except:
                        pass
            _res[_pid] = Process(_pid, cmdline, ppid)
        except:
            pass
    return _res


p = processes()
p2 = p

changes = []

while True:
    p3 = p2
    p2 = processes()

    print("***  CHANGES  ***")

    t = datetime.datetime.now()

    if p2 != p3:
        p_i = set(p3.keys())
        p2_i = set(p2.keys())

        for proc_id in p2_i - p_i:
            proc = p2[proc_id]
            changes.insert(0, (t, Colors.GREEN, f"+{proc.pid} {proc.cmdline}{Colors.END}"))
            logfile.write(f"{t.isoformat()} NEW  +{proc.pid} {proc.cmdline}\n"
                          f"\tparent: {p2[proc.parent].pid} {p2[proc.parent].cmdline}\n"
                          f"\tparent: {p2[p2[proc.parent].parent].pid} {p2[p2[proc.parent].parent].cmdline}\n")
            logfile.flush()
        for proc_id in p_i - p2_i:
            proc = p3[proc_id]
            changes.insert(0,(t, Colors.RED, f"-{proc.pid} {proc.cmdline}{Colors.END}"))
            logfile.write(f"{t.isoformat()} KILL -{proc.pid} {proc.cmdline}\n")
            logfile.flush()

    for c in changes:
        print(f"{c[1]}{str(t - c[0]).split('.')[0]}: {c[2]}")

    print("\n\n***  TREE  ***")

    for proc in p.values():
        if proc.pid not in p2.keys():
            if proc.parent in p2.keys():
                p2[proc.parent].disp_children.append(proc)
            proc.display = REMOVED

    for proc in p2.values():
        if proc.parent in p2.keys():
            p2[proc.parent].disp_children.append(proc)
        if proc.pid not in p.keys():
            proc.display = ADDED


    # p = p2

    p2[1].paint()

    time.sleep(3)
    os.system("clear")
