#!/usr/bin/env python3
"""Fix invalid Lua 5.5 escape sequences in all .lua files under Content/src/"""
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "Content", "src")

# Valid Lua escape sequences after backslash
VALID_ESCAPES = set('abfnrtv\\\'\"[\]0123456789xzZu\n\r')

def fix_file(path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    original = content
    lines = content.split('\n')
    fixed_lines = []
    changes = []

    for i, line in enumerate(lines, 1):
        new_line = []
        j = 0
        changed = False
        while j < len(line):
            ch = line[j]
            if ch == '\\' and j + 1 < len(line):
                next_ch = line[j + 1]
                if next_ch in VALID_ESCAPES:
                    # Valid escape, keep as-is
                    new_line.append(ch)
                    new_line.append(next_ch)
                    j += 2
                else:
                    # Invalid escape - double the backslash
                    new_line.append('\\\\')
                    new_line.append(next_ch)
                    changes.append(f"  L{i}: \\{next_ch} -> \\\\{next_ch}")
                    changed = True
                    j += 2
            else:
                new_line.append(ch)
                j += 1

        fixed_lines.append(''.join(new_line))

    if changes:
        new_content = '\n'.join(fixed_lines)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"FIXED: {os.path.relpath(path, ROOT)} ({len(changes)} fixes)")
        for c in changes[:10]:
            print(c)
        if len(changes) > 10:
            print(f"  ... and {len(changes) - 10} more")
        return len(changes)
    return 0

total = 0
for dirpath, dirnames, filenames in os.walk(ROOT):
    for fn in filenames:
        if fn.endswith('.lua'):
            path = os.path.join(dirpath, fn)
            total += fix_file(path)

print(f"\nTotal fixes: {total}")
