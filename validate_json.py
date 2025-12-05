import json
import sys

files = [
    '/Users/selimyay/cebinden/assets/translations/en.json',
    '/Users/selimyay/cebinden/assets/translations/tr.json'
]

for file_path in files:
    try:
        with open(file_path, 'r') as f:
            json.load(f)
        print(f"✅ {file_path} is valid JSON")
    except json.JSONDecodeError as e:
        print(f"❌ {file_path} has JSON error: {e}")
    except Exception as e:
        print(f"❌ {file_path} error: {e}")
