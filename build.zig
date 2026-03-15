const std = @import("std");

pub fn build(builder: *std.Build) void {
    std.debug.assert(@sizeOf(std.Build) > 0);
    std.debug.assert(!@inComptime());

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});
    const root_module = create_root_module(builder, target, optimize);
    _ = add_public_root_module(builder, target, optimize);

    const static_library = builder.addLibrary(.{
        .linkage = .static,
        .name = "noztr_sdk",
        .root_module = root_module,
    });
    builder.installArtifact(static_library);

    const unit_tests = builder.addTest(.{
        .root_module = root_module,
    });
    const run_unit_tests = builder.addRunArtifact(unit_tests);

    const test_step = builder.step("test", "Run noztr-sdk unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn create_root_module(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(@sizeOf(std.builtin.OptimizeMode) > 0);

    const noztr_dependency = builder.dependency("noztr", .{});
    const noztr_module = noztr_dependency.module("noztr");
    const root_module = builder.createModule(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("noztr", noztr_module);
    return root_module;
}

fn add_public_root_module(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(@sizeOf(std.builtin.OptimizeMode) > 0);

    const noztr_dependency = builder.dependency("noztr", .{});
    const noztr_module = noztr_dependency.module("noztr");
    const root_module = builder.addModule("noztr_sdk", .{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("noztr", noztr_module);
    return root_module;
}
