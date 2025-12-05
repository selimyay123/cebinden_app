import json

def get_keys(obj, prefix=""):
    keys = set()
    for k, v in obj.items():
        full_key = f"{prefix}.{k}" if prefix else k
        keys.add(full_key)
        if isinstance(v, dict):
            keys.update(get_keys(v, full_key))
    return keys

try:
    with open('/Users/selimyay/cebinden/assets/translations/en.json', 'r') as f:
        en_data = json.load(f)
    with open('/Users/selimyay/cebinden/assets/translations/tr.json', 'r') as f:
        tr_data = json.load(f)

    en_keys = get_keys(en_data)
    tr_keys = get_keys(tr_data)

    missing_in_en = tr_keys - en_keys
    missing_in_tr = en_keys - tr_keys

    print("Missing in en.json:")
    for k in sorted(missing_in_en):
        print(k)

    print("\nMissing in tr.json:")
    for k in sorted(missing_in_tr):
        print(k)

except Exception as e:
    print(f"Error: {e}")
