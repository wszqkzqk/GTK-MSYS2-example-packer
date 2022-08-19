#!/usr/bin/env python
from sys import argv
from fnmatch import fnmatch
import os

MSYS2_PATH = "D:\\msys64\\"

if len(argv) == 3:
    path = argv[1]
    outdir = argv[2]
elif len(argv) == 2:
    outdir = input('请输入需要将目标文件复制到的文件夹地址:\n')
elif len(argv) == 1:
    path = input('请输入文件地址:\n')
    outdir = input('请输入需要将目标文件复制到的文件夹地址:\n')

def pathed(path):
    if ((path[0] == "'") or (path[0] == '"')) and ((path[-1] == "'") or (path[-1] == '"')):
        return path[1:-1]
    else:
        return path

info = [i.split() for i in os.popen(f'ntldd -R "{pathed(path)}"')]
dependencies = set()
for i in ("bin", "etc", "lib", "share"):
    if not os.path.exists(os.path.join(outdir, i)):
        os.makedirs(os.path.join(outdir, i))
for item in info:
    if (fnmatch(item[2], '/usr/*') or fnmatch(item[2], '/ucrt64/*')
    or fnmatch(item[2], '*\\usr\\*')) or fnmatch(item[2], '*\\ucrt64\\*'):
        os.system(f'cp "{item[2]}" "{os.path.join(outdir, "bin", item[0])}"')
        dependencies.add(item[0])
os.system(f'cp "{pathed(path)}" "{os.path.join(outdir, "bin", os.path.basename(path))}"')

if ("libgtk-3-0.dll" in dependencies):
    share_file_path = (
        theme_path_default := os.path.join(outdir, "share", "themes", "default"),
        theme_path_emacs := os.path.join(outdir, "share", "themes", "emacs"),
        schemas_path := os.path.join(outdir, "share", "glib-2.0"),
        icon_path := os.path.join(outdir, "share"),
        pixbuf_path := os.path.join(outdir, "lib"),
        )
    for i in share_file_path:
        if not os.path.exists(os.path.join(outdir, i)):
            os.makedirs(os.path.join(outdir, i))
    os.system(f'cp -r "{os.path.join(MSYS2_PATH, "ucrt64", "share", "themes", "default", "gtk-3.0")}" "{theme_path_default}"')
    os.system(f'cp -r "{os.path.join(MSYS2_PATH, "ucrt64", "share", "themes", "emacs", "gtk-3.0")}" "{theme_path_emacs}"')
    os.system(f'cp -r "{os.path.join(MSYS2_PATH, "ucrt64", "share", "glib-2.0", "schemas")}" "{schemas_path}"')
    os.system(f'cp -r "{os.path.join(MSYS2_PATH, "ucrt64", "share", "icons")}" "{icon_path}"')
    os.system(f'cp -r "{os.path.join(MSYS2_PATH, "ucrt64", "lib", "gdk-pixbuf-2.0")}" "{pixbuf_path}"')