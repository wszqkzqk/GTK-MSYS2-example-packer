#!/usr/bin/env python

# MSYS2下的GTK3程序打包器（面向对象实现）
# 依赖ntldd提供动态链接关系

from fnmatch import fnmatch
import os

class GtkPacker():
    def __init__(self, mingw_arch, msys2_path, exe_file_path, outdir):
        self.dependencies = set()
        self.mingw_arch = mingw_arch
        self.mingw_path = os.path.join(msys2_path, mingw_arch)
        self.exe_file_path = self.clean_path(exe_file_path)
        self.outdir = outdir

    def clean_path(self, path):
        if ((path[0] == "'") or (path[0] == '"')) and ((path[-1] == "'") or (path[-1] == '"')):
            return path[1:-1]
        else:
            return path

    def is_msys2_dep(self, dep_path):
        if (fnmatch(dep_path, "/usr/*") or fnmatch(dep_path, f"/{self.mingw_arch}/*")
        or fnmatch(dep_path, "*\\usr\\*")) or fnmatch(dep_path, f"*\\{self.mingw_arch}\\*"):
            return True
        else:
            return False

    def copy_bin_file(self):
        info = (i.split() for i in os.popen(f'ntldd -R "{self.exe_file_path}"'))
        bin_path = os.path.join(self.outdir, "bin")
        if not os.path.exists(bin_path):
            os.makedirs(bin_path)
        for item in info:
            if self.is_msys2_dep(item[2]):
                if item[0] not in self.dependencies:
                    os.system(f'cp "{item[2]}" "{os.path.join(bin_path, item[0])}"')
                    self.dependencies.add(item[0])
        os.system(f'cp "{self.exe_file_path}" "{os.path.join(bin_path, os.path.basename(self.exe_file_path))}"')

    def copy_resource_file(self):
        copy_resource_file_dic = {
            os.path.join(self.mingw_path, "share", "themes", "default", "gtk-3.0"): os.path.join(self.outdir, "share", "themes", "default"),
            os.path.join(self.mingw_path, "share", "themes", "emacs", "gtk-3.0"): os.path.join(self.outdir, "share", "themes", "emacs"),
            os.path.join(self.mingw_path, "share", "glib-2.0", "schemas"): os.path.join(self.outdir, "share", "glib-2.0"),
            os.path.join(self.mingw_path, "share", "icons"): os.path.join(self.outdir, "share"),
            os.path.join(self.mingw_path, "lib", "gdk-pixbuf-2.0"): os.path.join(self.outdir, "lib"),
        }
        for source, target in copy_resource_file_dic.items():
            if not os.path.exists(os.path.join(self.outdir, target)):
                os.makedirs(os.path.join(self.outdir, target))
            os.system(f'cp -r "{source}" "{target}"')

    def run(self):
        self.copy_bin_file()
        if ("libgtk-3-0.dll" in self.dependencies):
            self.copy_resource_file()

if __name__ == "__main__":
    from sys import argv
    if len(argv) == 3:
        path = argv[1]
        outdir = argv[2]
    elif len(argv) == 2:
        if argv[1] in {"--help", "-h"}:
            print(  "帮助：\n"
                    "GtkPacker.py [待打包文件路径] [需打包到的目标路径]\n"
                    "GtkPacker.py -h(--help)    ----查看帮助")
            os._exit(0)
        else:
            outdir = input("请输入需要将目标文件复制到的文件夹地址:\n")
    elif len(argv) == 1:
        path = input("请输入文件地址:\n")
        outdir = input("请输入需要将目标文件复制到的文件夹地址:\n")

    packer = GtkPacker("ucrt64", "D:\\msys64", path, outdir)
    packer.run()
