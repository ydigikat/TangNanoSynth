#!/usr/bin/env python3
import sys
import re
from pathlib import Path

# Patterns: replace "input var logic" with "input logic"
port_patterns = [
    # input var logic [WIDTH-1:0] sig, sig2,
    (re.compile(r'(\binput\s+)var(\s+logic\b)(\s*(\[[^\]]+\])?\s+)',
                re.IGNORECASE),
     r'\1\2\3'),
    # Optional: output var logic ...
    (re.compile(r'(\boutput\s+)var(\s+logic\b)(\s*(\[[^\]]+\])?\s+)',
                re.IGNORECASE),
     r'\1\2\3'),
    # Optional: inout var logic ...
    (re.compile(r'(\binout\s+)var(\s+logic\b)(\s*(\[[^\]]+\])?\s+)',
                re.IGNORECASE),
     r'\1\2\3'),
]

def strip_var_in_ports(text: str) -> str:
    new_text = text
    for pattern, repl in port_patterns:
        new_text = pattern.sub(repl, new_text)
    return new_text

def rewrite_file(src_path: Path, dst_path: Path):
    text = src_path.read_text()
    new_text = strip_var_in_ports(text)
    dst_path.write_text(new_text)

def main():
    if len(sys.argv) < 3:
        print("Usage: iverilog_var_strip.py <src_dir> <dst_dir>", file=sys.stderr)
        sys.exit(1)

    src_dir = Path(sys.argv[1]).resolve()
    dst_dir = Path(sys.argv[2]).resolve()
    dst_dir.mkdir(parents=True, exist_ok=True)

    # Copy all .sv/.v/.svh files, stripping var from ports
    for src_path in src_dir.rglob("*"):
        if not src_path.is_file():
            continue
        if src_path.suffix not in {".sv", ".v", ".svh"}:
            continue

        rel = src_path.relative_to(src_dir)
        dst_path = dst_dir / rel
        dst_path.parent.mkdir(parents=True, exist_ok=True)
        rewrite_file(src_path, dst_path)

if __name__ == "__main__":
    main()