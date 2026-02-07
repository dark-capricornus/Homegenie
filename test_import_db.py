
import sys
import os

sys.path.append(os.getcwd())

try:
    from src.core import db_async
    print("✅ Successfully imported db_async")
except Exception as e:
    print(f"❌ Import failed: {e}")
