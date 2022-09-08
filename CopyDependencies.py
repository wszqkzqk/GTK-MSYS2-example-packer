#!/usr/bin/env python

# MSYS2下的GTK3程序打包器

from sys import argv
from fnmatch import fnmatch
import os

MINGW_ARCH = "ucrt64"
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
if not os.path.exists(os.path.join(outdir, "bin")):
    os.makedirs(os.path.join(outdir, "bin"))
for item in info:
    if (fnmatch(item[2], '/usr/*') or fnmatch(item[2], f'/{MINGW_ARCH}/*')
    or fnmatch(item[2], '*\\usr\\*')) or fnmatch(item[2], f'*\\{MINGW_ARCH}\\*'):
        if item[0] not in dependencies:
            os.system(f'cp "{item[2]}" "{os.path.join(outdir, "bin", item[0])}"')
            dependencies.add(item[0])
os.system(f'cp "{pathed(path)}" "{os.path.join(outdir, "bin", os.path.basename(path))}"')

if ("libgtk-3-0.dll" in dependencies):
    copy_share_file_dic = {
        os.path.join(MSYS2_PATH, MINGW_ARCH, "share", "themes", "default", "gtk-3.0"): os.path.join(outdir, "share", "themes", "default"),
        os.path.join(MSYS2_PATH, MINGW_ARCH, "share", "themes", "emacs", "gtk-3.0"): os.path.join(outdir, "share", "themes", "emacs"),
        os.path.join(MSYS2_PATH, MINGW_ARCH, "share", "glib-2.0", "schemas"): os.path.join(outdir, "share", "glib-2.0"),
        os.path.join(MSYS2_PATH, MINGW_ARCH, "share", "icons"): os.path.join(outdir, "share"),
        os.path.join(MSYS2_PATH, MINGW_ARCH, "lib", "gdk-pixbuf-2.0"): os.path.join(outdir, "lib"),
    }
    for source, target in copy_share_file_dic.items():
        if not os.path.exists(os.path.join(outdir, target)):
            os.makedirs(os.path.join(outdir, target))
        os.system(f'cp -r "{source}" "{target}"')
