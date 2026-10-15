#!/usr/bin/env python3
"""
Umbriel Community Effects Manager
Backend script for Noctalia 'UmbrielFXctl' plugin.
Manages 6 independent Umbriel effect include files:
- umbriel-effect-workspace.toml  (Workspace transitions)
- umbriel-effect-in-out.toml      (Window In/Out lifecycle animations)
- umbriel-effect-move.toml        (Window dragging/resizing deformation)
- umbriel-effect-misc.toml        (Misc window shaders, overlays & screen effects)
- umbriel-effect-border.toml      (Focused window border shaders)
- umbriel-effect-cursor.toml      (Pointer trail and glow shaders)
"""

import sys
import os
import json
import re
import argparse
from pathlib import Path

DEFAULT_CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "umbriel"
DEFAULT_UMBRIEL_CONFIG = DEFAULT_CONFIG_DIR / "config.toml"
DEFAULT_SHADERS_DIR = DEFAULT_CONFIG_DIR / "shaders" / "community"

SLOT_FILES = {
    "workspace": "umbriel-effect-workspace.toml",
    "in-out": "umbriel-effect-in-out.toml",
    "move": "umbriel-effect-move.toml",
    "misc": "umbriel-effect-misc.toml",
    "border": "umbriel-effect-border.toml",
    "cursor": "umbriel-effect-cursor.toml",
}

def get_slot_paths(config_dir: Path):
    return {slot: config_dir / fname for slot, fname in SLOT_FILES.items()}

def slot_display_name(slot: str) -> str:
    """Returns user-facing display name for a slot."""
    if slot == "in-out":
        return "In/Out"
    elif slot == "misc":
        return "Misc FX"
    return slot.replace('-', ' ').title()

def determine_slot(category: str, name: str, raw_config: str = "") -> str:
    """Classifies an effect into one of the 6 architectural slots."""
    if category == "animation":
        if name.startswith("workspace") or "[animation.workspaces]" in raw_config:
            return "workspace"
        elif "[animation.windows_move]" in raw_config or name in ["squash", "wobbly-move"]:
            return "move"
        else:
            return "in-out"
    elif category == "window":
        return "misc"
    elif category == "screen":
        return "misc"
    elif category == "border":
        return "border"
    elif category == "cursor":
        return "cursor"
    return "misc"

def ensure_setup(config_file: Path, config_dir: Path):
    """
    Ensures that all 6 separate umbriel-effect-*.toml files exist
    and are included in ~/.config/umbriel/config.toml under [include.optional].
    Migrates legacy files (umbriel-effect-window.toml, umbriel-effects.toml) if present.
    """
    results = {
        "ok": True,
        "files_created": [],
        "config_updated": False,
        "config_file": str(config_file)
    }

    config_dir.mkdir(parents=True, exist_ok=True)
    slot_paths = get_slot_paths(config_dir)

    # Migrate legacy umbriel-effect-window.toml to umbriel-effect-in-out.toml if present
    legacy_window = config_dir / "umbriel-effect-window.toml"
    in_out_file = slot_paths["in-out"]
    if legacy_window.exists():
        if not in_out_file.exists() or in_out_file.stat().st_size <= 100:
            content = legacy_window.read_text()
            in_out_file.write_text(content)
        try:
            legacy_window.unlink()
        except Exception:
            pass

    # Remove obsolete single umbriel-effects.toml if it exists
    legacy_effects = config_dir / "umbriel-effects.toml"
    if legacy_effects.exists():
        try:
            legacy_effects.unlink()
        except Exception:
            pass

    # 1. Ensure each of the 6 files exists with initial header
    for slot, path in slot_paths.items():
        if not path.exists():
            header = (
                f"# Umbriel Community Effects - {slot_display_name(slot)} slot\n"
                f"# Managed by Noctalia: UmbrielFXctl\n"
                f"# No {slot} effect currently active.\n"
            )
            path.write_text(header)
            results["files_created"].append(path.name)

    # 2. Update config.toml
    if config_file.exists():
        content = config_file.read_text()

        # Remove obsolete references if present
        for old_ref in ["umbriel-effects.toml", "umbriel-effect-window.toml"]:
            if f'"{old_ref}"' in content:
                content = re.sub(rf'[ \t]*"{re.escape(old_ref)}",?\s*\n', '', content)
                results["config_updated"] = True

        pattern = r'(\[include\.optional\]\s*(?:#[^\n]*\n)*\s*files\s*=\s*\[)([^\]]*?)(\])'
        match = re.search(pattern, content, re.DOTALL)

        if match:
            files_block = match.group(2)
            missing_files = [fname for fname in SLOT_FILES.values() if f'"{fname}"' not in files_block]

            if missing_files:
                stripped = files_block.rstrip()
                additions = [f'    "{fname}"' for fname in missing_files]

                if stripped and not stripped.endswith(','):
                    new_block = stripped + ',\n' + ',\n'.join(additions) + '\n'
                else:
                    new_block = stripped + '\n' + ',\n'.join(additions) + '\n'

                new_content = content[:match.start(2)] + new_block + content[match.end(2):]
                config_file.write_text(new_content)
                results["config_updated"] = True
            elif results["config_updated"]:
                config_file.write_text(content)
        else:
            # Create [include.optional] section with all 6 files
            additions = ',\n'.join(f'    "{fname}"' for fname in SLOT_FILES.values())
            append_section = f'\n[include.optional]\nfiles = [\n{additions}\n]\n'
            config_file.write_text(content + append_section)
            results["config_updated"] = True

    return results

def remove_setup(config_file: Path, config_dir: Path):
    """
    Removes all 6 umbriel-effect-*.toml files (and legacy ones)
    and removes their references from ~/.config/umbriel/config.toml under [include.optional].
    """
    results = {
        "ok": True,
        "files_removed": [],
        "lines_cleared": [],
        "config_updated": False,
        "config_file": str(config_file)
    }

    managed_files = list(SLOT_FILES.values()) + [
        "umbriel-effect-window.toml",
        "umbriel-effects.toml"
    ]

    # 1. Remove the managed slot files from config_dir
    for fname in managed_files:
        path = config_dir / fname
        if path.exists():
            try:
                path.unlink()
                results["files_removed"].append(fname)
            except Exception as e:
                results["ok"] = False
                results["error"] = str(e)

    # 2. Clear lines from config_file under [include.optional]
    if config_file.exists():
        content = config_file.read_text()
        orig_content = content

        pattern = r'(\[include\.optional\]\s*(?:#[^\n]*\n)*\s*files\s*=\s*\[)([^\]]*?)(\])'
        match = re.search(pattern, content, re.DOTALL)

        if match:
            files_block = match.group(2)
            lines = files_block.splitlines(keepends=True)
            new_lines = []

            for line in lines:
                is_managed_line = False
                for fname in managed_files:
                    if f'"{fname}"' in line or f"'{fname}'" in line:
                        clean_line = line.strip()
                        # If the line is essentially just "filename.toml" or "filename.toml",
                        if clean_line in (f'"{fname}"', f'"{fname}",', f"'{fname}'", f"'{fname}',"):
                            is_managed_line = True
                            results["lines_cleared"].append(fname)
                            break
                        else:
                            # It has other items on this line, replace just the file reference
                            line = re.sub(rf'[ \t]*["\']{re.escape(fname)}["\'],?[ \t]*', '', line)
                            results["lines_cleared"].append(fname)
                if not is_managed_line:
                    new_lines.append(line)

            # If all items were removed and only whitespace remains, collapse to clean empty block
            if "".join(new_lines).strip() == "":
                new_block = "\n"
            else:
                new_block = "".join(new_lines)

            new_content = content[:match.start(2)] + new_block + content[match.end(2):]
            if new_content != orig_content:
                config_file.write_text(new_content)
                results["config_updated"] = True
        else:
            # Fallback for any other references in the file
            for fname in managed_files:
                if f'"{fname}"' in content:
                    content = re.sub(rf'[ \t]*"{re.escape(fname)}",?\s*\n', '', content)
                    results["lines_cleared"].append(fname)
                    results["config_updated"] = True
            if results["config_updated"]:
                config_file.write_text(content)

    return results

def extract_meta(readme_path: Path, dir_name: str):
    """Extract a friendly title and short description from README.md"""
    title = dir_name.replace("-", " ").title()
    desc = ""
    if readme_path.exists():
        try:
            lines = readme_path.read_text().splitlines()
            for line in lines:
                line_s = line.strip()
                if not line_s:
                    continue
                if line_s.startswith("# ") and not desc:
                    title = line_s[2:].strip()
                elif not line_s.startswith("#") and not line_s.startswith("|") and not line_s.startswith("![") and not line_s.startswith("<") and not desc:
                    desc = line_s
                    if len(desc) > 160:
                        desc = desc[:157] + "..."
                    break
        except Exception:
            pass
    if not desc:
        desc = f"{title} effect for Umbriel"
    return title, desc

def list_effects(shaders_dir: Path, config_dir: Path):
    """
    Scans shaders/community/ for effects and groups them into the 6 slots.
    Includes rel_path (relative to ~/.config/umbriel/).
    """
    categories = ["animation", "border", "cursor", "screen", "window"]
    items = []

    if not shaders_dir.exists():
        return items

    for cat in categories:
        cat_dir = shaders_dir / cat
        if not cat_dir.is_dir():
            continue

        for entry in sorted(cat_dir.iterdir()):
            if not entry.is_dir() or entry.name.startswith("."):
                continue

            config_file = entry / "config.toml"
            effect_file = entry / "effect.toml"
            if not config_file.exists() and not effect_file.exists():
                continue

            raw_cfg = config_file.read_text() if config_file.exists() else ""
            slot = determine_slot(cat, entry.name, raw_cfg)

            preview_file = entry / "preview.png"
            title, desc = extract_meta(entry / "README.md", entry.name)

            # Compute relative path from umbriel config root (e.g. shaders/community/animation/beach-surf-animation)
            try:
                rel_path = str(entry.relative_to(config_dir))
            except Exception:
                rel_path = f"shaders/community/{cat}/{entry.name}"

            items.append({
                "id": f"{cat}/{entry.name}",
                "name": entry.name,
                "category": cat,
                "slot": slot,
                "title": title,
                "description": desc,
                "path": str(entry),
                "rel_path": rel_path,
                "has_config": config_file.exists(),
                "has_preview": preview_file.exists(),
                "preview_path": str(preview_file) if preview_file.exists() else ""
            })

    return items

def get_slot_status(config_dir: Path):
    """Inspects all 6 effect files to determine active effects per slot."""
    slot_paths = get_slot_paths(config_dir)
    slots_info = {}
    active_effects = []
    active_names = []

    for slot, path in slot_paths.items():
        slots_info[slot] = {
            "file": path.name,
            "exists": path.exists(),
            "active_id": None,
            "active_name": None,
            "is_active": False
        }

        if path.exists():
            content = path.read_text()
            match_marker = re.search(r'# Active Effect:\s*([^\n]+)', content)
            if match_marker:
                eff_id = match_marker.group(1).strip()
                eff_name = eff_id.split("/")[-1]
                slots_info[slot]["active_id"] = eff_id
                slots_info[slot]["active_name"] = eff_name
                slots_info[slot]["is_active"] = True
                active_effects.append(eff_id)
                active_names.append(eff_name)
            else:
                incs = re.findall(r'"shaders/community/([^/]+)/([^/]+)/[^"]*"', content)
                if incs:
                    cat, name = incs[0]
                    eff_id = f"{cat}/{name}"
                    slots_info[slot]["active_id"] = eff_id
                    slots_info[slot]["active_name"] = name
                    slots_info[slot]["is_active"] = True
                    active_effects.append(eff_id)
                    active_names.append(name)

    return {
        "slots": slots_info,
        "active_effects": active_effects,
        "effect_names": active_names,
        "active_count": len(active_effects)
    }

def apply_effect(target_id: str, config_dir: Path, shaders_dir: Path):
    """
    Applies the effect to its respective slot file:
    umbriel-effect-<slot>.toml.
    Copies config.toml directly without using [include] for config.toml.
    """
    parts = target_id.strip("/").split("/")
    if len(parts) != 2:
        return {"ok": False, "error": f"Invalid effect ID: {target_id}. Expected format: category/name"}

    cat, name = parts
    effect_dir = shaders_dir / cat / name
    config_file = effect_dir / "config.toml"

    if not config_file.exists():
        return {"ok": False, "error": f"config.toml not found for effect: {target_id}"}

    content = config_file.read_text()
    slot = determine_slot(cat, name, content)
    slot_paths = get_slot_paths(config_dir)
    target_file = slot_paths.get(slot)

    if not target_file:
        return {"ok": False, "error": f"Unknown slot '{slot}' for effect: {target_id}"}

    header = (
        f"# Umbriel Community Effects - {slot_display_name(slot)} slot\n"
        f"# Active Effect: {target_id}\n"
        f"# Applied automatically by Noctalia UmbrielFXctl\n\n"
    )

    target_file.parent.mkdir(parents=True, exist_ok=True)
    target_file.write_text(header + content)

    return {
        "ok": True,
        "applied": target_id,
        "slot": slot,
        "file": str(target_file)
    }

def clear_slot(slot: str, config_dir: Path):
    """Clears a specific slot's file or all 6 files."""
    slot_paths = get_slot_paths(config_dir)

    if slot == "all" or slot == "":
        for s, path in slot_paths.items():
            header = (
                f"# Umbriel Community Effects - {slot_display_name(s)} slot\n"
                f"# Managed by Noctalia: UmbrielFXctl\n"
                f"# No {s} effect currently active.\n"
            )
            path.write_text(header)
        return {"ok": True, "cleared": "all"}
    else:
        path = slot_paths.get(slot)
        if path:
            header = (
                f"# Umbriel Community Effects - {slot_display_name(slot)} slot\n"
                f"# Managed by Noctalia: UmbrielFXctl\n"
                f"# No {slot} effect currently active.\n"
            )
            path.write_text(header)
            return {"ok": True, "cleared": slot}
        return {"ok": False, "error": f"Invalid slot: {slot}"}

def main():
    parser = argparse.ArgumentParser(description="Umbriel Multi-Slot Effects Manager for Noctalia")
    parser.add_argument("--config", help="Path to umbriel/config.toml")
    parser.add_argument("--dir", help="Path to umbriel config directory")
    parser.add_argument("--shaders", help="Path to shaders/community directory")
    subparsers = parser.add_subparsers(dest="command")

    for s in ["setup", "resetup"]:
        subparsers.add_parser(s, help="Ensure all 6 effect files exist and are included")
    subparsers.add_parser("list", help="List all available community shaders with slots and rel_paths")
    subparsers.add_parser("status", help="Get current active effects across all 6 slots")

    apply_parser = subparsers.add_parser("apply", help="Apply a chosen effect to its respective slot")
    apply_parser.add_argument("effect_id", help="Effect ID, e.g. animation/workspace-burn")

    clear_parser = subparsers.add_parser("clear", help="Clear a slot or all slots")
    clear_parser.add_argument("slot", nargs="?", default="all", help="Slot to clear: workspace, in-out, move, misc, border, cursor, or all")

    for c in ["clean", "remove-configs", "uninstall", "purge"]:
        subparsers.add_parser(c, help="Remove created config files and clear include.optional entries")

    args = parser.parse_args()
    config_file = Path(args.config) if args.config else DEFAULT_UMBRIEL_CONFIG
    config_dir = Path(args.dir) if args.dir else DEFAULT_CONFIG_DIR
    shaders_dir = Path(args.shaders) if args.shaders else DEFAULT_SHADERS_DIR

    if args.command in ("setup", "resetup"):
        res = ensure_setup(config_file, config_dir)
        print(json.dumps(res, indent=2))
    elif args.command == "list":
        effects = list_effects(shaders_dir, config_dir)
        print(json.dumps(effects, indent=2))
    elif args.command == "status":
        status = get_slot_status(config_dir)
        print(json.dumps(status, indent=2))
    elif args.command == "apply":
        ensure_setup(config_file, config_dir)
        res = apply_effect(args.effect_id, config_dir, shaders_dir)
        print(json.dumps(res, indent=2))
    elif args.command == "clear":
        res = clear_slot(args.slot, config_dir)
        print(json.dumps(res, indent=2))
    elif args.command in ("clean", "remove-configs", "uninstall", "purge"):
        res = remove_setup(config_file, config_dir)
        print(json.dumps(res, indent=2))
    else:
        status = get_slot_status(config_dir)
        effects = list_effects(shaders_dir, config_dir)
        print(json.dumps({"status": status, "count": len(effects)}, indent=2))

if __name__ == "__main__":
    main()
