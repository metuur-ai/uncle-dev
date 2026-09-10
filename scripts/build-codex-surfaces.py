#!/usr/bin/env python3
"""Generate Codex entry points from an assembled bundle; never rewrite sources.

Commands stay complete in command-templates/. The small skill entry points avoid
Codex's 4,000-byte automatic command migration limit. Agents are independent
native TOML files, not skill UI labels. Uses only the Python standard library.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re


RUNTIME = """# Uncle Dev on Codex

Commands, skills, and agent personas are separate components. A command entry
must read and follow the entire referenced command, including all routed skills
and companions. Never replace a command with a single similarly named skill.

Resolve the active plugin root from the loaded skill file: it is the ancestor
containing .codex-plugin/plugin.json. Keep the working directory at the user's
project so config helpers read that project's settings. When executing bundled
shell snippets, set CLAUDE_PLUGIN_ROOT to that resolved absolute plugin root in
the same shell invocation. This is a compatibility variable used by the shared
templates; do not search another product's cache or assume Codex sets it.
Use that root's scripts/uncle-dev-config.sh and scripts/uncle-dev-load-skill.sh.
For SKILL: uncle-dev:<name>, read skills/<name>/SKILL.md in this plugin; read
COMPANION files afterward. Resolve nested /uncle-dev-* and /opsx:* references
through COMMANDS.md and execute the referenced full command.

Interpret command argument placeholders from the user's invocation as data,
never as shell code. Translate source-host tool names to available Codex tools.
If a required capability is unavailable, report the specific missing capability.
Agents are registered under the source filenames (for example
uncle-dev-ag-code-reviewer); shorter frontmatter names in the Markdown sources
refer to those same personas. Use the available Codex delegation tools.

Bundled root rules are reference files, not automatically activated project
instructions. Configure the target project with the setup command when needed.
Claude-specific hooks are not activated by this installer.
"""


def description(path):
    """Read the scalar/block descriptions used by this repo, fail if absent."""
    text = path.read_text()
    parts = text.split('---', 2)
    if len(parts) != 3 or parts[0].strip():
        raise ValueError(f'Missing frontmatter: {path}')
    lines = parts[1].splitlines()
    for i, line in enumerate(lines):
        if line.startswith('description:'):
            value = line.partition(':')[2].strip()
            if value in ('>', '|', '>-', '|-'):
                continuation = []
                for following in lines[i + 1:]:
                    if following and not following[0].isspace():
                        break
                    continuation.append(following.strip())
                value = ' '.join(continuation).strip()
            elif value.startswith('"'):
                value = json.loads(value)
            elif value.startswith("'") and value.endswith("'"):
                value = value[1:-1].replace("''", "'")
            if value:
                return value, parts[2].strip()
    raise ValueError(f'Missing description: {path}')


def write(path, content, force):
    if path.is_symlink():
        raise ValueError(f'Refusing symlink: {path}')
    if path.exists() and path.read_text() != content and not force:
        raise ValueError(f'Refusing to overwrite: {path} (use --force)')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def build(plugin, agent_dir, force):
    write(plugin / 'CODEX.md', RUNTIME, force)
    # Each ordinary skill also needs the host adapter when invoked directly.
    for skill in sorted((plugin / 'skills').glob('*/SKILL.md')):
        content = skill.read_text()
        parts = content.split('---', 2)
        if len(parts) != 3:
            raise ValueError(f'Missing skill frontmatter: {skill}')
        prelude = '\n\nRead ../../CODEX.md before executing this skill in Codex.\n'
        skill.write_text('---'.join(parts[:2]) + '---' + prelude + parts[2])
    rows = ['# Complete command entry points', '',
            'Select the command entry in Codex or invoke its `$command-…` name.',
            'These entries execute full command templates, not one backing skill.', '',
            '| Source command | Codex entry |', '|---|---|']
    for source in sorted((plugin / 'command-templates').rglob('*.md')):
        if source.name in ('README.md', 'AGENTS.md'):
            continue
        relative = source.relative_to(plugin / 'command-templates')
        stem = '-'.join(relative.with_suffix('').parts)
        name = 'command-' + stem
        if len(name) > 64 or not re.fullmatch(r'[a-z0-9-]+', name):
            raise ValueError(f'Unsupported command name: {relative}')
        desc, _ = description(source)
        invocation = '/' + ':'.join(relative.with_suffix('').parts)
        entry = plugin / 'skills' / name
        text = (f'---\nname: {json.dumps(name)}\n'
                f'description: {json.dumps("Execute the complete " + invocation + " command. " + desc)}\n'
                '---\n\n'
                f'# {invocation} — complete command\n\n'
                'Read ../../CODEX.md first for Codex execution and path rules.\n'
                f'Then read ../../command-templates/{relative.as_posix()} in full and execute\n'
                'its entire workflow with the user\'s arguments. Load every skill and\n'
                'companion it calls for. Do not substitute a single skill or agent.\n')
        write(entry / 'SKILL.md', text, force)
        ui = ('interface:\n'
              f'  display_name: {json.dumps(invocation + " (command)")}\n'
              f'  short_description: {json.dumps("Run the complete " + invocation + " workflow")}\n'
              f'  default_prompt: {json.dumps("Use $" + name + " to execute the full command workflow.")}\n'
              'policy:\n  allow_implicit_invocation: false\n')
        write(entry / 'agents/openai.yaml', ui, force)
        rows.append(f'| `{invocation}` | `${name}` |')
    write(plugin / 'COMMANDS.md', '\n'.join(rows) + '\n', force)

    for source in sorted((plugin / 'agents').glob('*.md')):
        if source.name in ('README.md', 'AGENTS.md'):
            continue
        desc, body = description(source)
        fields = {'name': source.stem, 'description': desc,
                  'developer_instructions': RUNTIME + '\n' + body}
        # JSON strings with ensure_ascii=False are also TOML basic strings.
        content = ''.join(f'{key} = {json.dumps(value, ensure_ascii=False)}\n'
                          for key, value in fields.items())
        write(agent_dir / (source.stem + '.toml'), content, force)

    # Reproducible cachebuster: a changed bundle must not reuse an old active
    # cache, while an identical reinstall should remain byte-identical.
    manifest_path = plugin / '.codex-plugin/plugin.json'
    manifest = json.loads(manifest_path.read_text())
    manifest['version'] = manifest['version'].split('+', 1)[0]
    digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode())
    for path in sorted(plugin.rglob('*')):
        if path.is_file() and path != manifest_path:
            digest.update(path.relative_to(plugin).as_posix().encode() + b'\0')
            digest.update(path.read_bytes())
    manifest['version'] += '+codex.' + digest.hexdigest()[:12]
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plugin', type=Path)
    parser.add_argument('agent_dir', type=Path)
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    build(args.plugin, args.agent_dir, args.force)
