"""Prints the folder that holds one sub-folder per dish (the one with the most
sub-folders that contain photos), wherever a dataset's zip put it."""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
exts = {".jpg", ".jpeg", ".png", ".webp"}
best, best_n = None, 0
for d in [root, *[p for p in root.rglob("*") if p.is_dir()]]:
    n = sum(1 for c in d.iterdir() if c.is_dir() and any(f.suffix.lower() in exts for f in c.iterdir() if f.is_file()))
    if n > best_n:
        best, best_n = d, n
if best is None or best_n < 5:
    sys.exit(f"No folder with at least 5 dish sub-folders found under {root}")
print(best)
print(f"{best_n} dish folders", file=sys.stderr)
