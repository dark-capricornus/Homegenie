"""
Auto-fix script for sensor_agent.py device_id scope bug.

This script fixes the issue where device_id is defined inside the DB block
but needed outside for ContextStore updates, causing 0 devices to appear.
"""

import re

# Read the file
file_path = r"d:\Homegenie\src\agents\sensor_agent.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find the section to fix (around line 360-362)
# We need to add device_id parsing BEFORE the "# Persist to DB" comment

# Pattern to find: the line "# Persist to DB if possible (upsert semantics)"
pattern = r'(\s+except Exception:\s+logger\.exception\("DB topic lookup failed; proceeding to accept message"\)\s+)(# Persist to DB if possible)'

# Replacement: add device_id parsing before the DB block
replacement = r'''\1# Parse device_id reliably (needed for both DB and ContextStore)
    device_id = data.get("device_id")
    if not device_id and "home/" in topic:
        # try to parse topic: home/type/location/state
        parts = topic.split('/')
        if len(parts) >= 3:
            # light.living_room
            device_id = f"{parts[1]}.{parts[2]}"

    \2'''

# Apply the fix
new_content = re.sub(pattern, replacement, content, count=1)

if new_content == content:
    print("❌ Pattern not found - file may have already been fixed or structure changed")
    print("\nSearching for the pattern...")
    if "# Persist to DB if possible" in content:
        print("✅ Found '# Persist to DB if possible' comment")
        # Show context
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if "# Persist to DB if possible" in line:
                print(f"\nContext around line {i+1}:")
                for j in range(max(0, i-3), min(len(lines), i+4)):
                    print(f"{j+1}: {lines[j]}")
    else:
        print("❌ Could not find '# Persist to DB if possible' comment")
else:
    # Write the fixed content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("✅ Fix applied successfully!")
    print("\nChanges made:")
    print("- Added device_id parsing before DB block (line ~362)")
    print("- This ensures device_id is always available for ContextStore writes")
    print("\nNext steps:")
    print("1. Wait for uvicorn to auto-reload (~2 seconds)")
    print("2. Test: curl http://127.0.0.1:8000/state")
    print("3. Expected: Should show 3 devices (temperature, motion, light_sensor)")
