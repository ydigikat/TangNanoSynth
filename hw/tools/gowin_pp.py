#!/usr/bin/env python3
import sys
import re
from pathlib import Path

# This applies additional pre-processing to my SystemVerilog files before the
# Gowin EDA tools build them. The build will only apply this process when the
# --preprocess option is given to the build.tcl script.
#
# The following fixups are made to a copy of the source file which is subsequently
# used for the compilation, the original file is not changed.
#
# 1. iVerilog does not support the var keyword but Gowin EDA requires this to be used
#    with default nettype none.  Add the var keyword to input ports etc.
#

# Patterns to recognise the code where var keyword needs to be added, these are specific
# to my personal coding style.
port_patterns = [
    # input logic [WIDTH-1:0] sig, sig2,
    (re.compile(r'(\binput\s+)(logic\b)(\s*(\[[^\]]+\])?\s+)',
                re.IGNORECASE),
     r'\1var \2\3'),
    # output logic [WIDTH-1:0] sig, sig2,
    (re.compile(r'(\boutput\s+)(logic\b)(\s*(\[[^\]]+\])?\s+)',
                re.IGNORECASE),
     r'\1var \2\3'),
    # inout logic ...
    (re.compile(r'(\binout\s+)(logic\b)(\s*(\[[^\]]+\])?\s+)',
                re.IGNORECASE),
     r'\1var \2\3'),
]

# Rewrite the files adding the var keyword and output to a different directory from
# the original source, the build is modified to use this alternative folder.
def rewrite_file(src_path: Path, dst_path: Path):
    text = src_path.read_text()

    # Only rewrite when default_nettype none is present; otherwise leave file untouched.
    if '`default_nettype none' not in text:
        dst_path.write_text(text)
        return

    new_text = text
    for pattern, repl in port_patterns:
        new_text = pattern.sub(repl, new_text)

    dst_path.write_text(new_text)



def main():
    if len(sys.argv) < 3:
        print("Usage: gowin_pp.py <src_dir> <dst_dir>", file=sys.stderr)
        sys.exit(1)

    src_dir = Path(sys.argv[1]).resolve()
    dst_dir = Path(sys.argv[2]).resolve()
    dst_dir.mkdir(parents=True, exist_ok=True)

    # Process all .sv files.
    for src_path in src_dir.rglob("*"):
        if not src_path.is_file():
            continue
        if src_path.suffix not in {".sv", ".v"}:
            continue

        rel = src_path.relative_to(src_dir)
        dst_path = dst_dir / rel
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        rewrite_file(src_path, dst_path)

if __name__ == "__main__":
    main()