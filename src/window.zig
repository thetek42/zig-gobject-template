const std = @import("std");
const builtin = @import("builtin");
const adw = @import("adw");
const gobject = @import("gobject");
const gtk = @import("gtk");
const config = @import("config");
const util = @import("util.zig");

const Application = @import("app.zig").Application;

pub const Window = extern struct {
    const Self = @This();

    pub const Parent = adw.ApplicationWindow;
    pub usingnamespace util.Common(Self);

    parent: Parent,
    private: Private,

    const Private = extern struct {
        children: extern struct {
            button: *gtk.Button,
            label: *gtk.Label,
        },
        counter: usize = 0,
    };

    pub const getGObjectType = gobject.ext.defineClass(Self, .{
        .flags = .{ .final = true },
        .instanceInit = &init,
        .classInit = &Class.init,
        .parent_class = &Class.meta.parent_class,
    });

    pub fn init(self: *Self, _: *Class) callconv(.C) void {
        var self_widget = self.as(gtk.Widget);
        self_widget.initTemplate();

        const button = self.private.children.button;
        _ = gtk.Button.signals.clicked.connect(button, *Self, &handleButtonClick, self, .{});

        if (builtin.mode == .Debug) {
            self_widget.addCssClass("devel");
        }
    }

    pub fn new(app: *Application) *Self {
        return gobject.ext.newInstance(Self, .{
            .application = app,
        });
    }

    pub fn dispose(self: *Self) callconv(.C) void {
        self.as(gtk.Widget).disposeTemplate(getGObjectType());
        self.virtualCall(gobject.Object, "dispose", .{});
    }

    fn handleButtonClick(_: *gtk.Button, self: *Self) callconv(.C) void {
        var buf: [64]u8 = undefined;
        self.private.counter += 1;
        const label = std.fmt.bufPrintZ(&buf, "Counter: {}", .{self.private.counter}) catch unreachable;
        self.private.children.label.setLabel(label);
    }

    pub const Class = extern struct {
        parent_class: Parent.Class,

        pub usingnamespace util.CommonClass(Class, Self);

        fn init(class: *Class) callconv(.C) void {
            class.initMeta();
            class.override(gobject.Object, "dispose");
            class.bindTemplate("window.ui");
        }
    };
};
