const std = @import("std");
const adw = @import("adw");
const gio = @import("gio");
const glib = @import("glib");
const gobject = @import("gobject");
const gtk = @import("gtk");
const config = @import("config");
const util = @import("util.zig");

const PreferencesDialog = @import("prefs.zig").PreferencesDialog;
const Window = @import("window.zig").Window;

pub const Application = extern struct {
    const Self = @This();

    pub const Parent = adw.Application;
    pub usingnamespace util.Common(Self);

    parent: Parent,
    private: Private,

    const Private = extern struct {
        settings: *gio.Settings,
        color_scheme: c_uint,
    };

    pub const properties = struct {
        pub const color_scheme = struct {
            pub const name = "color-scheme";
            pub const impl = gobject.ext.defineProperty(name, Self, c_uint, .{
                .accessor = .{ .setter = &setColorScheme, .getter = &getColorScheme },
                .flags = .{ .readable = true, .writable = true },
                .minimum = 0,
                .maximum = 2,
                .default = 0,
            });
        };
    };

    pub const getGObjectType = gobject.ext.defineClass(Self, .{
        .flags = .{ .final = true },
        .instanceInit = &init,
        .classInit = &Class.init,
        .parent_class = &Class.meta.parent_class,
    });

    pub fn init(self: *Self, _: *Class) callconv(.C) void {
        self.private.settings = gio.Settings.new(config.app_id);
        self.private.settings.bind("color-scheme", self.as(gobject.Object), "color-scheme", .{});
    }

    pub fn new() *Self {
        return gobject.ext.newInstance(Self, .{
            .@"application-id" = config.app_id,
            .flags = gio.ApplicationFlags{},
        });
    }

    pub fn activate(self: *Self) callconv(.C) void {
        const win = Window.new(self);
        win.as(gtk.Window).present();
    }

    pub fn startup(self: *Self) callconv(.C) void {
        const action_about = gio.SimpleAction.new("about", null);
        defer action_about.unref();
        _ = gio.SimpleAction.signals.activate.connect(action_about, *Self, &showAbout, self, .{});
        self.as(gio.ActionMap).addAction(action_about.as(gio.Action));

        const action_prefs = gio.SimpleAction.new("preferences", null);
        defer action_prefs.unref();
        _ = gio.SimpleAction.signals.activate.connect(action_prefs, *Self, &showPrefs, self, .{});
        self.as(gio.ActionMap).addAction(action_prefs.as(gio.Action));

        self.virtualCall(gio.Application, "startup", .{});
    }

    pub fn dispose(self: *Self) callconv(.C) void {
        self.private.settings.unref();
        self.virtualCall(gobject.Object, "dispose", .{});
    }

    fn showAbout(_: *gio.SimpleAction, _: ?*glib.Variant, self: *Self) callconv(.C) void {
        var dialog = adw.AboutDialog.new();
        dialog.setApplicationName(config.app_name);
        dialog.setVersion(config.app_version);

        const window = self.as(gtk.Application).getActiveWindow().?;
        dialog.as(adw.Dialog).present(window.as(gtk.Widget));
    }

    fn showPrefs(_: *gio.SimpleAction, _: ?*glib.Variant, self: *Self) callconv(.C) void {
        const prefs = PreferencesDialog.new(self.private.settings);
        const window = self.as(gtk.Application).getActiveWindow().?;
        prefs.as(adw.Dialog).present(window.as(gtk.Widget));
    }

    fn getColorScheme(self: *Self) c_uint {
        return self.private.color_scheme;
    }

    fn setColorScheme(self: *Self, color_scheme: c_uint) void {
        const style_mgr = self.as(adw.Application).getStyleManager();
        style_mgr.setColorScheme(switch (color_scheme) {
            1 => .force_dark,
            2 => .force_light,
            else => .default,
        });
    }

    pub const Class = extern struct {
        parent_class: Parent.Class,

        pub usingnamespace util.CommonClass(Class, Self);

        fn init(class: *Class) callconv(.C) void {
            class.initMeta();
            class.registerProperties();
            class.override(gio.Application, "activate");
            class.override(gio.Application, "startup");
            class.override(gobject.Object, "dispose");
        }
    };
};
