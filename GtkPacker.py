#!/usr/bin/env python

# MSYS2下的GTK3程序打包器（面向对象实现）
# 依赖ntldd提供动态链接关系

import re
import os

class GtkPacker():
    def __init__(self, mingw_arch, msys2_path, exe_file_path, outdir):
        self.dependencies = set()
        self.mingw_arch = mingw_arch
        self.mingw_path = os.path.join(msys2_path, mingw_arch)
        self.quote_regex = re.compile(r"""(".*")|('.*')""")
        self.msys2_dep_regex = re.compile(rf".*(/|\\)(usr|{mingw_arch})(/|\\).*")  # Python会自动拼接仅以空白符号分隔的字符串
        self.exe_file_path = self.clean_path(exe_file_path)
        self.outdir = outdir

    def clean_path(self, path):
        if self.quote_regex.match(path):
            return path[1:-1]
        else:
            return path
    
    def copy_operation(self, resource, target):
        if not os.system(f'cp -r "{resource}" "{target}"'):
            print(f"Successfully copied '{os.path.basename(resource)}'")
        else:
            print(f"Warning: failed to copy '{os.path.basename(resource)}'")

    def copy_bin_file(self):
        info = (i.split() for i in os.popen(f'ntldd -R "{self.exe_file_path}"'))
        bin_path = os.path.join(self.outdir, "bin")
        if not os.path.exists(bin_path):
            os.makedirs(bin_path)
        for item in info:
            if self.msys2_dep_regex.match(item[2]):
                if item[0] not in self.dependencies:
                    self.copy_operation(item[2], os.path.join(bin_path, item[0]))
                    self.dependencies.add(item[0])
        self.copy_operation(self.exe_file_path, os.path.join(bin_path, os.path.basename(self.exe_file_path)))

    def copy_resource_file(self):
        copy_resource_file_dic = {
            os.path.join(self.mingw_path, "share", "themes", "default", "gtk-3.0"): os.path.join(self.outdir, "share", "themes", "default"),
            os.path.join(self.mingw_path, "share", "themes", "emacs", "gtk-3.0"): os.path.join(self.outdir, "share", "themes", "emacs"),
            os.path.join(self.mingw_path, "share", "glib-2.0", "schemas"): os.path.join(self.outdir, "share", "glib-2.0"),
            os.path.join(self.mingw_path, "share", "icons"): os.path.join(self.outdir, "share"),
            os.path.join(self.mingw_path, "lib", "gdk-pixbuf-2.0"): os.path.join(self.outdir, "lib"),
        }
        for resource, target in copy_resource_file_dic.items():
            if not os.path.exists(os.path.join(self.outdir, target)):
                os.makedirs(os.path.join(self.outdir, target))
            self.copy_operation(resource, target)

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
