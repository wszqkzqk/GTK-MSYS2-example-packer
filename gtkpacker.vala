#!/usr/bin/env -S vala --pkg=gio-2.0 -X -O2 -X -march=native -X -pipe

/* gtkpacker.vala
 *
 * Copyright (C) 2022-2023 周 乾康
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	周 乾康 <wszqkzqk@stu.pku.edu.cn>
 */
 
public class GtkPacker : Object {
    public string file_path;
    public string outdir;
    string mingw_path = null;
    static Regex msys2_dep_regex {
        get;
        default = /.*(\/|\\)(usr|ucrt64|clang64|mingw64|mingw32|clang32|clangarm64)(\/|\\)/;
    }
    GenericSet<string> dependencies = new GenericSet<string> (str_hash, str_equal);

    public GtkPacker (string file_path, string outdir) {
        this.file_path = file_path;
        this.outdir = outdir;
    }

    void copy_bin_files () throws Error {
        string deps_info;

        Process.spawn_command_line_sync (@"ntldd -R '$(this.file_path)'", out deps_info);
        var bin_path = build_path (this.outdir, "bin");
        DirUtils.create_with_parents (bin_path, 0644);
        
        var file = File.new_for_path (this.file_path);
        var target = File.new_for_path (build_path (bin_path, file.get_basename ()));
        file.copy (target, FileCopyFlags.OVERWRITE);
        
        var deps_info_array = deps_info.split ("\n");
        foreach (var i in deps_info_array) {
            var item = (i.strip ()).split (" ");
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
                    target = File.new_for_path (build_path(bin_path, item[0]));
                    file.copy (target, FileCopyFlags.OVERWRITE);
                }
            }
        }
    }

    static bool copy_recursive (File src, File dest, FileCopyFlags flags = FileCopyFlags.NONE, Cancellable? cancellable = null) throws Error {
        FileType src_type = src.query_file_type (FileQueryInfoFlags.NONE, cancellable);
        if (src_type == FileType.DIRECTORY) {
            string src_path = src.get_path ();
            string dest_path = dest.get_path ();
            DirUtils.create_with_parents(dest_path, 0644);
            src.copy_attributes (dest, flags, cancellable);
        
            FileEnumerator enumerator = src.enumerate_children (FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE, cancellable);
            for (FileInfo? info = enumerator.next_file (cancellable) ; info != null ; info = enumerator.next_file (cancellable)) {
                copy_recursive (
                File.new_for_path (Path.build_filename (src_path, info.get_name ())),
                File.new_for_path (Path.build_filename (dest_path, info.get_name ())),
                flags,
                cancellable);
            }
        } else if (src_type == FileType.REGULAR) {
            src.copy (dest, flags, cancellable);
        }
      
        return true;
    }

    inline void copy_resources () throws Error {
        string[] resources = {
            build_path ("share", "themes", "default", "gtk-3.0"),
            build_path ("share", "themes", "emacs", "gtk-3.0"),
            build_path ("share", "glib-2.0", "schemas"),
            build_path ("share", "icons"),
            build_path ("lib", "gdk-pixbuf-2.0")
        };

        if ("libgtk-3-0.dll" in this.dependencies || "libgtk-4-1.dll" in this.dependencies) {
            foreach (var item in resources) {
                var resource = File.new_for_path (build_path(this.mingw_path, item));
                var target = File.new_for_path (build_path(this.outdir, item));
                copy_recursive (resource, target, FileCopyFlags.OVERWRITE);
            }
        }
    }

    public static inline string build_path (string root, ...) {
        return Path.build_path (Path.DIR_SEPARATOR_S, root, va_list ());
    }

    public inline void run () throws Error {
        this.copy_bin_files ();
        this.copy_resources ();
    }
}

static int main (string[] args) {
    Intl.setlocale ();

    string file_path = null;
    string outdir = null;
    OptionEntry[] options = {
        { "file", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref file_path, "The executable file to pack", "FILE" },
        { "output", 'o', OptionFlags.NONE, OptionArg.FILENAME, ref outdir, "The directory to store packed files", "DIRECTORY" },
        // list terminator
        { null }
    };

    var opt_context = new OptionContext ("- A tool to package GTK programs on Windows");
    opt_context.set_help_enabled (true);
    opt_context.add_main_entries (options, null);

    try {
        opt_context.parse (ref args);
    } catch (OptionError e) {
        printerr ("error: %s\n", e.message);
        print (opt_context.get_help (true, null));
        return 1;
    }

    if (file_path == null || outdir == null) {
        if (file_path == null) {
            printerr ("error: The executable file was not setted!\n");
        }
        if (outdir == null) {
            printerr ("error: The directory to store packed files was not setted!\n");
        }
        print (opt_context.get_help (true, null));
        return 1;
    }
    if (FileUtils.test (file_path, FileTest.IS_REGULAR)) {
        if (file_path.has_suffix (".exe")) {
            var packer = new GtkPacker (file_path, outdir);
            try {
                packer.run ();
            } catch (SpawnError e) {
                printerr ("error: Please check the installation `ntldd' or your settings about Windows system paths!\n");
                return 1;
            } catch (Error e) {
                printerr ("error: %s\n", e.message);
                return 1;
            }
        } else {
            printerr ("error: The file extension is not supported!\n");
            return 1;
        }
    } else {
        printerr ("error: The file path is wrong!\n");
        return 1;
    }
    return 0;
}
