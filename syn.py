#!/usr/bin/env python3

import os
import sys
import subprocess

N=sys.argv[1]

os.system('sed -i "24s/.*/\/\/\`define DEBUG 1/" verilog/sys_defs.svh')
os.system(f'sed -i "31s/.*/\`define N {N}/" verilog/sys_defs.svh')

low_p = 8
high_p = 12
inc = 1


while (high_p - low_p) > 0.5:
    mid = (high_p + low_p) / 2
    os.system(f'sed -i "99s/.*/export CLOCK_PERIOD={mid}/" Makefile')
    subprocess.call(["make", "nuke"], stdout=subprocess.DEVNULL)
    subprocess.call(["make", "syn_simv"], stdout=subprocess.DEVNULL)

    print(f"Synthesizing CLOCK_PERIOD={mid}")
    violated = os.system(f"grep -E \"VIOLATED\" tmp/{mid}.rep") # 0 if violated, 256 else

    if(violated == 0):
        print(f"CLOCK_PERIOD={mid} VIOLATED")
        low_p = mid
    else:
        print(f"CLOCK_PERIOD={mid} MADE")
        high_p = mid
