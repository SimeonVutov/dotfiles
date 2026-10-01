import ast
import json
import os
import re
import subprocess
import sys
import tomllib
from pathlib import Path

from common import eligible, git


def jsonc(text):
    tokens = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/'
    text = re.sub(tokens, lambda m: m[0] if m[0].startswith('"') else '', text)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: '' if m[0].startswith(',') else m[0], text)
    return json.loads(text)


def qml_javascript_for_node(text):
    return re.sub(r'^\.(?:pragma library|import "[^"\n]+" as [A-Za-z_]\w*)[ \t]*$',
                  '', text, flags=re.MULTILINE)


def check(path):
    if not eligible(str(path)) or path.is_symlink() or not path.is_file():
        return
    if '.config/matugen/templates/' in str(path):
        print(f'Skip generated template syntax: {path}')
        return
    suffix = path.suffix
    if suffix in {'.png', '.jpg', '.gif', '.webp'}:
        return
    if suffix in {'.sh', '.zsh'} or path.name == '.zshrc':
        first = path.open().readline()
        shell = 'zsh' if path.name == '.zshrc' or 'zsh' in first else 'bash' if 'bash' in first else 'sh'
        subprocess.run([shell, '-n', str(path)], check=True)
        if shell != 'zsh':
            subprocess.run(['shellcheck', '--severity=error', '--shell', shell, str(path)], check=True)
    elif suffix == '.py':
        ast.parse(path.read_text(), filename=str(path))
    elif suffix in {'.js', '.cjs', '.mjs'}:
        if suffix == '.js' and '.config/quickshell/' in str(path):
            subprocess.run(['node', '--check'], input=qml_javascript_for_node(path.read_text()),
                           text=True, check=True)
        else:
            subprocess.run(['node', '--check', str(path)], check=True)
    elif suffix == '.toml':
        tomllib.loads(path.read_text())
    elif suffix in {'.json', '.jsonc'}:
        (jsonc if suffix == '.jsonc' else json.loads)(path.read_text())
    elif suffix in {'.yaml', '.yml'}:
        import yaml
        yaml.safe_load(path.read_text())
    elif suffix == '.qml':
        print(f'QML runtime validation requires installed Quickshell modules; review locally: {path}')


def main():
    base, head = os.environ.get('CHECK_BASE'), os.environ.get('CHECK_HEAD', 'HEAD')
    paths = (git('diff', '--name-only', '--diff-filter=ACMR', base, head).splitlines()
             if base and set(base) != {'0'} else git('ls-files').splitlines())
    failed = []
    for name in paths:
        try:
            check(Path(name))
        except (ValueError, SyntaxError, subprocess.CalledProcessError) as error:
            print(f'Configuration check failed: {name}: {type(error).__name__}', file=sys.stderr)
            failed.append(name)
    if failed:
        raise SystemExit(1)
    print(f'Checked {len(paths)} changed paths; unsupported formats are not runtime-validated')


if __name__ == '__main__':
    main()
