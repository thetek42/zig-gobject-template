const std = @import("std");
const builtin = @import("builtin");
const adw = @import("adw");
const gio = @import("gio");
const gobject = @import("gobject");
const gtk = @import("gtk");
const config = @import("config");
const util = @import("util.zig");

const Window = @import("window.zig").Window;

pub const PreferencesDialog = extern struct {
    const Self = @This();

    pub const Parent = adw.PreferencesDialog;
    pub usingnamespace util.Common(Self);

    parent: Parent,
    private: Private,

    const Private = extern struct {
        children: extern struct {
            color_scheme: *adw.ComboRow,
        },
        settings: *gio.Settings,
    };

    pub const getGObjectType = gobject.ext.defineClass(Self, .{
        .flags = .{ .final = true },
        .instanceInit = &init,
        .classInit = &Class.init,
        .parent_class = &Class.meta.parent_class,
    });

    pub fn init(self: *Self, _: *Class) callconv(.C) void {
        self.as(gtk.Widget).initTemplate();
    }

    pub fn new(settings: *gio.Settings) *Self {
        const self = gobject.ext.newInstance(Self, .{});
        self.private.settings = util.ref(settings);
        self.private.settings.bind("color-scheme", self.private.children.color_scheme.as(gobject.Object), "selected", .{});
        return self;
    }

    pub fn dispose(self: *Self) callconv(.C) void {
        self.as(gtk.Widget).disposeTemplate(getGObjectType());
        self.private.settings.unref();
        self.virtualCall(gobject.Object, "dispose", .{});
    }

    pub const Class = extern struct {
        parent_class: Parent.Class,

        pub usingnamespace util.CommonClass(Class, Self);

        fn init(class: *Class) callconv(.C) void {
            class.initMeta();
            class.override(gobject.Object, "dispose");
            class.bindTemplate("prefs.ui");
        }
    };
};
