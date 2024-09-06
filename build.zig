const std = @import("std");
const config = @import("config.zig");

pub fn build(b: *std.Build) !void {
    // --- compile blueprint files ---

    const blueprint_dir = "src/ui";
    const compile_blueprints = b.addSystemCommand(&.{ "blueprint-compiler", "batch-compile" });
    const data_output = compile_blueprints.addOutputDirectoryArg("data");
    compile_blueprints.addDirectoryArg(b.path(blueprint_dir));

    // --- generate gresource.xml ---

    var gresource_xml = std.ArrayList(u8).init(b.allocator);
    defer gresource_xml.deinit();
    try gresource_xml.appendSlice("<?xml version=\"1.0\" encoding=\"UTF-8\"?><gresources><gresource prefix=\"" ++ config.data_namespace ++ "\">");

    var dir = try std.fs.cwd().openDir(blueprint_dir, .{ .iterate = true });
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();
    while (try walker.next()) |ui| {
        if (!std.mem.eql(u8, ".blp", std.fs.path.extension(ui.path))) continue;
        compile_blueprints.addFileArg(b.path(b.pathJoin(&.{ blueprint_dir, ui.path })));
        try gresource_xml.appendSlice("<file preprocess=\"xml-stripblanks\">");
        try gresource_xml.appendSlice(ui.path[0..(ui.path.len - 4)]);
        try gresource_xml.appendSlice(".ui</file>");
    }

    try gresource_xml.appendSlice("</gresource></gresources>");

    const wf = b.addWriteFiles();
    const gresource_xml_file = wf.add(config.app_name ++ ".gresource.xml", gresource_xml.items);

    // --- compile resources ---

    const compile_resources = b.addSystemCommand(&.{"glib-compile-resources"});
    compile_resources.addFileArg(gresource_xml_file);
    compile_resources.addArg("--generate-source");
    compile_resources.addPrefixedDirectoryArg("--sourcedir=", data_output);
    const resource_file = compile_resources.addPrefixedOutputFileArg("--target=", "resources.c");
    compile_resources.step.dependOn(&compile_blueprints.step);

    // --- install translation files ---

    var po_dir = try std.fs.cwd().openDir("po", .{ .iterate = true });
    var po_walker = try po_dir.walk(b.allocator);
    defer po_walker.deinit();
    while (try po_walker.next()) |ui| {
        const lang = std.fs.path.stem(ui.path);
        if (!std.mem.eql(u8, ".po", std.fs.path.extension(ui.path)) or std.mem.eql(u8, lang, config.app_name)) continue;
        const cmd = b.addSystemCommand(&.{"msgfmt"});
        cmd.addFileArg(b.path(b.pathJoin(&.{ "po", ui.path })));
        cmd.addArg("-o");
        const out = cmd.addOutputFileArg(b.fmt("po/{s}.mo", .{lang}));
        const mo_file = b.fmt("{s}/LC_MESSAGES/" ++ config.app_name ++ ".mo", .{lang});
        const po_install = b.addInstallFileWithDir(out, .{ .custom = "share/locale" }, mo_file);
        b.getInstallStep().dependOn(&po_install.step);
    }

    // --- install schemas ---

    const schema_name = config.app_id ++ ".gschema.xml";
    const schema_src = b.path("src/data/" ++ schema_name);
    const schema_out = "share/glib-2.0/schemas";
    const install_schemas = b.addInstallFileWithDir(schema_src, .{ .custom = schema_out }, schema_name);

    // --- compile schemas ---

    const compile_schemas = b.addSystemCommand(&.{"glib-compile-schemas"});
    compile_schemas.addArg(b.fmt("{s}/" ++ schema_out, .{b.install_prefix}));
    compile_schemas.step.dependOn(&install_schemas.step);
    b.getInstallStep().dependOn(&compile_schemas.step);

    // --- application ---

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = config.app_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.step.dependOn(&compile_resources.step);
    exe.addCSourceFile(.{ .file = resource_file });
    exe.linkLibC();

    const gobject_codegen = b.dependency("gobject", .{});
    exe.root_module.addImport("adw", gobject_codegen.module("adw1"));
    exe.root_module.addImport("gio", gobject_codegen.module("gio2"));
    exe.root_module.addImport("glib", gobject_codegen.module("glib2"));
    exe.root_module.addImport("gobject", gobject_codegen.module("gobject2"));
    exe.root_module.addImport("gtk", gobject_codegen.module("gtk4"));
    exe.linkSystemLibrary("libadwaita-1");

    const config_module = b.addModule("config", .{ .root_source_file = b.path("config.zig") });
    exe.root_module.addImport("config", config_module);

    b.installArtifact(exe);

    // --- step for running the application ---

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
