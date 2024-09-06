const std = @import("std");
const builtin = @import("builtin");
const config = @import("config");
const gobject = @import("gobject");
const gtk = @import("gtk");

const libc = @cImport({
    @cInclude("locale.h");
    @cInclude("libintl.h");
});

pub fn setupLocale() !void {
    // In order to load the locale files, the directory needs to be determined.
    // Usually, people use /usr/share/locale (which is the regular location) or
    // a local build directory specified at compile time, but that does not
    // allow for portable installations. Instead, we determine the location
    // relative to the application's binary location. When the application is in
    // /prefix/bin, the translation files are located in /prefix/share/locale.
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const locale_dir = getRelativeExeDir("share/locale", &buf);

    _ = libc.setlocale(libc.LC_ALL, null);
    _ = libc.bindtextdomain(config.app_name, locale_dir.ptr);
    _ = libc.textdomain(config.app_name);
}

pub fn getRelativeExeDir(path: [:0]const u8, buf: []u8) [:0]const u8 {
    return tryGetRelativeExeDir(path, buf) catch {
        return std.fmt.bufPrintZ(buf, "/usr/{s}", .{path}) catch {
            return path;
        };
    };
}

pub fn tryGetRelativeExeDir(path: []const u8, buf: []u8) ![:0]u8 {
    const self_exe = try std.fs.selfExeDirPath(buf);
    const bin_pos = std.mem.indexOf(u8, self_exe, "/bin") orelse return error.FileNotFound;
    const len = try std.fmt.bufPrintZ(buf[(bin_pos + 1)..], "{s}", .{path});
    return @ptrCast(buf[0..(bin_pos + len.len)]);
}

pub fn gettext(msgid: [*:0]const u8) [*:0]u8 {
    return libc.gettext(msgid);
}

pub fn ref(x: anytype) @TypeOf(x) {
    x.ref();
    return x;
}

pub fn Common(comptime Self: type) type {
    return struct {
        pub fn as(self: *Self, comptime T: type) *T {
            return gobject.ext.as(T, self);
        }

        pub fn virtualCall(self: *Self, comptime T: type, comptime func: []const u8, comptime args: anytype) void {
            const virtual_func = @field(T.virtual_methods, func);
            const parent_class = Self.Class.meta.parent_class.as(T.Class);
            @call(.auto, virtual_func.call, .{ parent_class, self.as(T) } ++ args);
        }
    };
}

pub fn CommonClass(comptime Class: type, comptime InstanceType: type) type {
    const RegisterProperties = switch (@hasDecl(InstanceType, "properties")) {
        false => struct {},
        true => struct {
            pub fn registerProperties(class: *Class) void {
                const properties = comptime getPropertyArray();
                gobject.ext.registerProperties(class, &properties);
            }

            fn getPropertyArray() [std.meta.declarations(InstanceType.properties).len]type {
                const properties = std.meta.declarations(InstanceType.properties);
                var array: [properties.len]type = undefined;
                for (properties, 0..properties.len) |prop, idx| {
                    array[idx] = @field(InstanceType.properties, prop.name).impl;
                }
                return array;
            }
        },
    };

    return struct {
        pub const Instance = InstanceType;

        pub const meta = struct {
            pub var parent_class: *InstanceType.Parent.Class = undefined;
        };

        pub fn as(class: *Class, comptime T: type) *T {
            return gobject.ext.as(T, class);
        }

        pub fn bindTemplate(class: *Class, comptime resource: []const u8) void {
            const widget = as(class, gtk.Widget.Class);
            widget.setTemplateFromResource(config.data_namespace ++ "/" ++ resource);
            inline for (std.meta.fields(InstanceType)) |private_field| {
                if (comptime std.mem.eql(u8, private_field.name, "private")) {
                    inline for (std.meta.fields(private_field.type)) |children_field| {
                        if (comptime std.mem.eql(u8, children_field.name, "children")) {
                            const offset = @offsetOf(InstanceType, "private") + @offsetOf(private_field.type, "children");
                            inline for (std.meta.fields(children_field.type)) |child| {
                                const widget_class: *gtk.WidgetClass = @ptrCast(@alignCast(class));
                                widget_class.bindTemplateChildFull(child.name, @intFromBool(false), offset + @offsetOf(children_field.type, child.name));
                            }
                        }
                    }
                }
            }
        }

        pub fn initMeta(class: *Class) void {
            meta.parent_class = @ptrCast(gobject.TypeClass.peekParent(@ptrCast(class)));
        }

        pub fn override(class: *Class, comptime T: type, comptime func: []const u8) void {
            const virtual_func = @field(T.virtual_methods, func);
            const override_func = @field(Instance, func);
            @call(.auto, virtual_func.implement, .{ class, &override_func });
        }

        pub usingnamespace RegisterProperties;
    };
}
