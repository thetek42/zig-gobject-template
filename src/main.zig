const std = @import("std");
const adw = @import("adw");
const gio = @import("gio");
const glib = @import("glib");
const gobject = @import("gobject");
const util = @import("util.zig");

const Application = @import("app.zig").Application;

pub fn main() !u8 {
    var schema_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const schema_dir = util.getRelativeExeDir("share/glib-2.0/schemas", &schema_buf);
    _ = glib.setenv("GSETTINGS_SCHEMA_DIR", schema_dir, 1);

    try util.setupLocale();
    var app = Application.new().as(gio.Application);
    defer app.unref();
    return @intCast(app.run(@intCast(std.os.argv.len), std.os.argv.ptr));
}
