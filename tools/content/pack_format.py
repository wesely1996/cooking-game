"""Writes cuisine pack JSON in the repository's readable layout: one item,
process or assembly per line, role presets indented. Used by content scripts."""
import json


def dumps(pack):
    out = ["{"]
    keys = list(pack.keys())
    for ki, key in enumerate(keys):
        value = pack[key]
        comma = "," if ki < len(keys) - 1 else ""
        if key in ("items", "equipment") and isinstance(value, dict):
            out.append(f'  "{key}": {{')
            names = list(value.keys())
            for i, name in enumerate(names):
                c = "," if i < len(names) - 1 else ""
                out.append(f'    {json.dumps(name)}: {json.dumps(value[name], ensure_ascii=False)}{c}')
            out.append("  }" + comma)
        elif key in ("processes", "assemblies") and isinstance(value, list):
            out.append(f'  "{key}": [')
            for i, entry in enumerate(value):
                c = "," if i < len(value) - 1 else ""
                out.append(f"    {json.dumps(entry, ensure_ascii=False)}{c}")
            out.append("  ]" + comma)
        elif key == "role_presets":
            out.append('  "role_presets": {')
            presets = list(value.keys())
            for pi, preset in enumerate(presets):
                out.append(f'    {json.dumps(preset)}: {{')
                counts = list(value[preset].keys())
                for ci, count in enumerate(counts):
                    out.append(f'      "{count}": [')
                    roles = value[preset][count]
                    for ri, role in enumerate(roles):
                        rc = "," if ri < len(roles) - 1 else ""
                        out.append(f"        {json.dumps(role, ensure_ascii=False)}{rc}")
                    out.append("      ]" + ("," if ci < len(counts) - 1 else ""))
                out.append("    }" + ("," if pi < len(presets) - 1 else ""))
            out.append("  }" + comma)
        else:
            out.append(f'  {json.dumps(key)}: {json.dumps(value, ensure_ascii=False)}{comma}')
    out.append("}")
    return "\n".join(out) + "\n"


def write(path, pack):
    with open(path, "w") as f:
        f.write(dumps(pack))
