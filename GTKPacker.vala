#!/usr/bin/env -S vala --pkg=gee-0.8 --pkg=gio-2.0 -X -O2 -X -march=native -X -pipe

// 在Windows下打包MSYS2中的GTK3程序
// LGPL v2.1

public class GtkPacker : Object {
    string file_path;
    string outdir;
    string mingw_path = null;
    Regex quote_regex = /(".*")|('.*')/;
    Regex msys2_dep_regex;
    Gee.HashSet<string> dependencies = new Gee.HashSet<string>();

    public GtkPacker(string file_path, string outdir) {
        this.file_path = this.clean_path(file_path);
        this.outdir = outdir;
        this.msys2_dep_regex = new Regex(@".*(/|\\\\)(usr|ucrt64|clang64|mingw64|mingw32|clang32|clangarm64)(/|\\\\)");
    }

    string clean_path(string path) {
        if (this.quote_regex.match(path)) {
            return path[1:path.length-1];
        } else {
            return path;
        }
    }

    void copy_bin_files() {
        string deps_info;

        Process.spawn_command_line_sync(@"ntldd -R '$(this.file_path)'", out deps_info);
        var bin_path = Path.build_path(Path.DIR_SEPARATOR_S, this.outdir, "bin");
        DirUtils.create_with_parents(bin_path, 644);
        
        var file = File.new_for_path(this.file_path);
        var target = File.new_for_path(Path.build_path(Path.DIR_SEPARATOR_S, bin_path, file.get_basename()));
        file.copy(target, FileCopyFlags.OVERWRITE);
        
        var deps_info_array = deps_info.split("\n");
        foreach (var i in deps_info_array) {
            var j = i._strip();
            var item = j.split(" ");
            if ((item.length == 4) && (!(item[0] in this.dependencies))) {
                bool condition;
                if (this.mingw_path == null) {
                    MatchInfo match_info;
                    condition = this.msys2_dep_regex.match(item[2], 0, out match_info);
                    this.mingw_path = match_info.fetch(0);
                } else {
                    condition = this.msys2_dep_regex.match(item[2]);
                }
                if (condition) {
                    this.dependencies.add(item[0]);
                    file = File.new_for_path(item[2]);
                    target = File.new_for_path(Path.build_path(Path.DIR_SEPARATOR_S, bin_path, item[0]));
                    file.copy(target, FileCopyFlags.OVERWRITE);
                }
            }
        }
    }

    bool copy_recursive (File src, File dest, FileCopyFlags flags = FileCopyFlags.NONE, Cancellable? cancellable = null) throws Error {
        FileType src_type = src.query_file_type (FileQueryInfoFlags.NONE, cancellable);
        if ( src_type == FileType.DIRECTORY ) {
            string src_path = src.get_path ();
            string dest_path = dest.get_path ();
            DirUtils.create_with_parents(dest_path, 644);
            src.copy_attributes (dest, flags, cancellable);
        
            FileEnumerator enumerator = src.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE, cancellable);
            for ( FileInfo? info = enumerator.next_file (cancellable) ; info != null ; info = enumerator.next_file (cancellable) ) {
                copy_recursive (
                File.new_for_path (Path.build_filename (src_path, info.get_name ())),
                File.new_for_path (Path.build_filename (dest_path, info.get_name ())),
                flags,
                cancellable);
            }
        } else if ( src_type == FileType.REGULAR ) {
            src.copy (dest, flags, cancellable);
        }
      
        return true;
    }

    void copy_resources() {
        var copy_resource_dic = new Gee.HashMap<string, string>();
        copy_resource_dic[Path.build_path(Path.DIR_SEPARATOR_S, this.mingw_path, "share", "themes", "default", "gtk-3.0")]
        = Path.build_path(Path.DIR_SEPARATOR_S, this.outdir, "share", "themes", "default", "gtk-3.0");
        copy_resource_dic[Path.build_path(Path.DIR_SEPARATOR_S, this.mingw_path, "share", "themes", "emacs", "gtk-3.0")]
        = Path.build_path(Path.DIR_SEPARATOR_S, this.outdir, "share", "themes", "emacs", "gtk-3.0");
        copy_resource_dic[Path.build_path(Path.DIR_SEPARATOR_S, this.mingw_path, "share", "glib-2.0", "schemas")]
        = Path.build_path(Path.DIR_SEPARATOR_S, this.outdir, "share", "glib-2.0", "schemas");
        copy_resource_dic[Path.build_path(Path.DIR_SEPARATOR_S, this.mingw_path, "share", "icons")]
        = Path.build_path(Path.DIR_SEPARATOR_S, this.outdir, "share", "icons");
        copy_resource_dic[Path.build_path(Path.DIR_SEPARATOR_S, this.mingw_path, "lib", "gdk-pixbuf-2.0")]
        = Path.build_path(Path.DIR_SEPARATOR_S, this.outdir, "lib", "gdk-pixbuf-2.0");

        foreach (var items in copy_resource_dic) {
            var resource = File.new_for_path(items.key);
            var target = File.new_for_path(items.value);
            this.copy_recursive(resource, target, FileCopyFlags.OVERWRITE);
        }
    }

    public void run() {
        this.copy_bin_files();
        if ("libgtk-3-0.dll" in this.dependencies) {
            this.copy_resources();
        }
    }
}

int main(string[] args) {
    string file_path;
    string outdir;

    Intl.setlocale();
    if (args.length == 1) {
        print("请输入文件地址：\n");
        file_path = stdin.read_line();
        print("请输入需要将目标文件复制到的文件夹地址:\n");
        outdir = stdin.read_line();
    } else if (args.length == 2) {
        if (args[1] == "-h" || args[1] == "--help") {
            print(  "%s\n%s\n%s\n",
                    "GTK3程序打包器使用帮助：",
                    "GtkPacker.exe [待打包文件路径] [需打包到的目标路径]",
                    "GtkPacker.exe -h(--help)    ----查看帮助");
            return 0;
        } else {
            file_path = args[1];
            print("请输入需要将目标文件复制到的文件夹地址:\n");
            outdir = stdin.read_line();
        }
    } else if (args.length == 3) {
        file_path = args[1];
        outdir = args[2];
    } else {
        print("错误！参数过多！\n");
        return 1;
    }

    var packer = new GtkPacker(file_path, outdir);
    packer.run();

    return 0;
}
