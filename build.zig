const std = @import("std");

pub fn build(builder: *std.Build) void {
    std.debug.assert(@sizeOf(std.Build) > 0);
    std.debug.assert(!@inComptime());

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});
    const root_module = create_root_module(builder, target, optimize);
    const public_root_module = add_public_root_module(builder, target, optimize);

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
    const examples_tests = builder.addTest(.{
        .root_module = create_examples_module(builder, target, optimize, public_root_module),
    });
    const run_examples_tests = builder.addRunArtifact(examples_tests);

    const test_step = builder.step("test", "Run noztr-sdk unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_examples_tests.step);

    const examples_step = builder.step("examples", "Run noztr-sdk examples");
    examples_step.dependOn(&run_examples_tests.step);
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

fn create_examples_module(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    public_root_module: *std.Build.Module,
) *std.Build.Module {
    const noztr_dependency = builder.dependency("noztr", .{});
    const noztr_module = noztr_dependency.module("noztr");
    const examples_module = builder.createModule(.{
        .root_source_file = builder.path("examples/examples.zig"),
        .target = target,
        .optimize = optimize,
    });
    examples_module.addImport("noztr", noztr_module);
    examples_module.addImport("noztr_sdk", public_root_module);
    return examples_module;
}
