#!/usr/bin/env -S vala --pkg=gee-0.8 --pkg=gio-2.0 -X -O2 -X -march=native -X -pipe

// 在Windows下打包MSYS2中的GTK程序
// LGPL v2.1

public class GtkPacker : Object {
    public string file_path;
    public string outdir;
    string mingw_path = null;
    static Regex quote_regex {get; default = /(".*")|('.*')/;}
    static Regex msys2_dep_regex {get; default = /.*(\/|\\)(usr|ucrt64|clang64|mingw64|mingw32|clang32|clangarm64)(\/|\\)/;}
    Gee.HashSet<string> dependencies = new Gee.HashSet<string> ();

    public GtkPacker (string file_path, string outdir) {
        this.file_path = clean_path (file_path);
        this.outdir = clean_path (outdir);
    }

    static inline string clean_path (string path) {
        return (quote_regex.match (path)) ? path[1:path.length-1] : path;
    }

    void copy_bin_files () {
        string deps_info;

        Process.spawn_command_line_sync (@"ntldd -R '$(this.file_path)'", out deps_info);
        var bin_path = Path.build_path (Path.DIR_SEPARATOR_S, this.outdir, "bin");
        DirUtils.create_with_parents (bin_path, 644);
        
        var file = File.new_for_path (this.file_path);
        var target = File.new_for_path (Path.build_path (Path.DIR_SEPARATOR_S, bin_path, file.get_basename ()));
        file.copy (target, FileCopyFlags.OVERWRITE);
        
        var deps_info_array = deps_info.split ("\n");
        foreach (var i in deps_info_array) {
            var j = i.strip ();
            var item = j.split (" ");
            if ((item.length == 4) && (!(item[0] in this.dependencies))) {
                bool condition;
                if (this.mingw_path == null) {
                    MatchInfo match_info;
                    condition = msys2_dep_regex.match (item[2], 0, out match_info);
                    this.mingw_path = match_info.fetch (0);
                } else {
                    condition = msys2_dep_regex.match (item[2]);
                }
                if (condition) {
                    this.dependencies.add (item[0]);
                    file = File.new_for_path (item[2]);
                    target = File.new_for_path (Path.build_path(Path.DIR_SEPARATOR_S, bin_path, item[0]));
                    file.copy (target, FileCopyFlags.OVERWRITE);
                }
            }
        }
    }

    static bool copy_recursive (File src, File dest, FileCopyFlags flags = FileCopyFlags.NONE, Cancellable? cancellable = null) throws Error {
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
        string[] resources = {
            Path.build_path (Path.DIR_SEPARATOR_S, "share", "themes", "default", "gtk-3.0"),
            Path.build_path (Path.DIR_SEPARATOR_S, "share", "themes", "emacs", "gtk-3.0"),
            Path.build_path (Path.DIR_SEPARATOR_S, "share", "glib-2.0", "schemas"),
            Path.build_path (Path.DIR_SEPARATOR_S, "share", "icons"),
            Path.build_path (Path.DIR_SEPARATOR_S, "lib", "gdk-pixbuf-2.0")
        };

        if ("libgtk-3-0.dll" in this.dependencies || "libgtk-4-1.dll" in this.dependencies) {
            foreach (var item in resources) {
                var resource = File.new_for_path (Path.build_path(Path.DIR_SEPARATOR_S, this.mingw_path, item));
                var target = File.new_for_path (Path.build_path(Path.DIR_SEPARATOR_S, this.outdir, item));
                copy_recursive (resource, target, FileCopyFlags.OVERWRITE);
            }
        }
    }

    public void run () {
        this.copy_bin_files ();
        this.copy_resources ();
    }
}

static int main (string[] args) {
    string file_path;
    string outdir;

    Intl.setlocale ();
    if (args.length == 1) {
        print ("请输入文件地址：\n");
        file_path = stdin.read_line ();
        while ((!FileUtils.test (file_path, FileTest.IS_REGULAR)) || (!file_path.has_suffix (".exe"))) {
            print ("文件路径错误或后缀名不受支持！请重新输入文件地址：\n");
            file_path = stdin.read_line ();
        }
        print("请输入需要将目标文件复制到的文件夹地址:\n");
        outdir = stdin.read_line ();
        while (outdir == "") {
            print ("输入为空！请重新输入需要将目标文件复制到的文件夹地址:\n");
            outdir = stdin.read_line ();
        }
    } else if (args.length == 2) {
        if (args[1] == "-h" || args[1] == "--help") {
            print ( "GTK程序打包器使用帮助：\n" +
                    "GtkPacker.exe [待打包文件路径] [需打包到的目标路径]\n" +
                    "GtkPacker.exe -h(--help)    ----查看帮助\n");
            return 0;
        } else {
            file_path = args[1];
            print("请输入需要将目标文件复制到的文件夹地址:\n");
            outdir = stdin.read_line ();
            while (outdir == "") {
                print ("输入为空！请重新输入需要将目标文件复制到的文件夹地址:\n");
                outdir = stdin.read_line ();
            }
        }
    } else if (args.length == 3) {
        file_path = args[1];
        outdir = args[2];
        assert ((FileUtils.test (file_path, FileTest.IS_REGULAR)) && (file_path.has_suffix (".exe")));
        assert (outdir != "");
    } else {
        print ("错误！参数过多！\n");
        return 1;
    }

    var packer = new GtkPacker (file_path, outdir);
    packer.run ();
    return 0;
}
