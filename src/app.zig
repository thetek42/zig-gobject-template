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
            .@"resource-base-path" = config.data_namespace,
            .flags = gio.ApplicationFlags{},
        });
    }

    pub fn activate(self: *Self) callconv(.C) void {
        const win = Window.new(self);
        win.as(gtk.Window).present();
    }

    pub fn startup(self: *Self) callconv(.C) void {
        // TODO: maybe use add_action_entries instead?
        self.addSimpleAction("quit", &quitAction);
        self.addSimpleAction("about", &showAbout);
        self.addSimpleAction("shortcuts", &showShortcuts);
        self.addSimpleAction("preferences", &showPrefs);

        self.setAccel("app.quit", "<primary>Q");

        self.virtualCall(gio.Application, "startup", .{});
    }

    pub fn dispose(self: *Self) callconv(.C) void {
        self.private.settings.unref();
        self.virtualCall(gobject.Object, "dispose", .{});
    }

    pub fn addSimpleAction(self: *Self, comptime name: [*:0]const u8, callback: *const fn (*gio.SimpleAction, ?*glib.Variant, *Self) callconv(.C) void) void {
        const action = gio.SimpleAction.new(name, null);
        defer action.unref();
        _ = gio.SimpleAction.signals.activate.connect(action, *Self, callback, self, .{});
        const action_map = gobject.ext.as(gio.ActionMap, self);
        action_map.addAction(action.as(gio.Action));
    }

    fn showAbout(_: *gio.SimpleAction, _: ?*glib.Variant, self: *Self) callconv(.C) void {
        var dialog = adw.AboutDialog.new();
        dialog.setApplicationName(config.app_name);
        dialog.setVersion(config.app_version);

        const window: *gtk.Window = self.as(gtk.Application).getActiveWindow().?;
        dialog.as(adw.Dialog).present(window.as(gtk.Widget));
    }

    fn showPrefs(_: *gio.SimpleAction, _: ?*glib.Variant, self: *Self) callconv(.C) void {
        const window: *gtk.Window = self.as(gtk.Application).getActiveWindow().?;
        const prefs = PreferencesDialog.new(self.private.settings);
        prefs.as(adw.Dialog).present(window.as(gtk.Widget));
    }

    fn showShortcuts(_: *gio.SimpleAction, _: ?*glib.Variant, self: *Self) callconv(.C) void {
        const window: *gtk.Window = self.as(gtk.Application).getActiveWindow().?;
        const overlay = util.getObjectFromBuilder(gtk.Window, "shortcuts.ui", "shortcuts_window");
        window.setTransientFor(overlay);
        overlay.present();
    }

    fn quitAction(_: *gio.SimpleAction, _: ?*glib.Variant, self: *Self) callconv(.C) void {
        const app = self.as(gio.Application);
        app.quit();
    }

    fn getColorScheme(self: *Self) c_uint {
        return self.private.color_scheme;
    }

    fn setAccel(self: *Self, comptime action: [*:0]const u8, comptime accel: [*:0]const u8) void {
        // due to a compilation bug in zig-gobject, setAccelsForAction does not
        // account for the null-termination of the accels array, so this serves
        // as a temporary workaround.
        const app = self.as(gtk.Application);
        const accels = [_]?[*:0]const u8{ accel, null };
        app.setAccelsForAction(action, @ptrCast(&accels));
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
