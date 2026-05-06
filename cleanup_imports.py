import os
import time

d = r"e:\GalChat\GalChat\assets\images\activities"
print(f"Cleaning up .import files in {d}...")

for f in os.listdir(d):
    p = os.path.join(d, f)
    if f.endswith('.import'):
        try:
            os.remove(p)
            print(f"Deleted {f}")
        except Exception as e:
            print(f"Failed to delete {f}: {e}")
    elif f.endswith('.png'):
        try:
            os.utime(p, None)
            print(f"Touched {f}")
        except Exception as e:
            print(f"Failed to touch {f}: {e}")

print("Done!")
