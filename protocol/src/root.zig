// We're using comptime while others are having copetime commenting out their handlers.

const pb = @import("nap.pb.zig");
pub const head = @import("head.pb.zig");
pub const action = @import("nap_action.pb.zig");
pub const CmdNames = cmdNames(pb);

pub const protobuf = @import("protobuf");

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn ByName(comptime pb_type: anytype) type {
    const type_name = @tagName(pb_type);
    if (@hasDecl(pb, type_name)) {
        return @field(pb, type_name);
    } else {
        return DummyMessage;
    }
}

pub inline fn makeProto(comptime pb_type: anytype, values: anytype) ByName(pb_type) {
    var proto: ByName(pb_type) = .{};
    setFields(&proto, values);
    return proto;
}

pub inline fn getField(proto: anytype, comptime field: anytype, comptime T: type) ?T {
    const proto_type = @TypeOf(proto);

    if (@hasField(proto_type, @tagName(field)) and @FieldType(proto_type, @tagName(field)) == T) {
        return @field(proto, @tagName(field));
    }

    return null;
}

pub inline fn addToMap(allocator: Allocator, proto: anytype, comptime field: anytype, key: anytype, value: anytype) !void {
    const key_type = @TypeOf(key);
    const value_type = @TypeOf(value);
    const proto_fields = std.meta.fields(std.meta.Child(@TypeOf(proto)));

    inline for (proto_fields) |proto_field| {
        if (comptime std.mem.eql(u8, @tagName(field), proto_field.name)) {
            if (@hasField(proto_field.type, "items")) {
                const item_type = std.meta.Elem(@FieldType(proto_field.type, "items"));
                if (@hasField(item_type, "key") and @hasField(item_type, "value")) {
                    if (@FieldType(item_type, "key") == key_type and (@FieldType(item_type, "value") == value_type or std.meta.Child(@FieldType(item_type, "value")) == value_type)) {
                        (try @field(proto, proto_field.name).addOne(allocator)).* = .{
                            .key = key,
                            .value = value,
                        };
                    }
                }
            }
        }
    }
}

pub inline fn addToList(allocator: Allocator, proto: anytype, comptime field: anytype, item: anytype) !void {
    const list_type = std.ArrayList(@TypeOf(item));
    const proto_fields = std.meta.fields(std.meta.Child(@TypeOf(proto)));

    inline for (proto_fields) |proto_field| {
        if (comptime std.mem.eql(u8, @tagName(field), proto_field.name)) {
            if (proto_field.type == list_type) {
                (try @field(proto, proto_field.name).addOne(allocator)).* = item;
            } else {
                const item_type = std.meta.Elem(@FieldType(proto_field.type, "items"));
                switch (@typeInfo(item_type)) {
                    inline .@"enum" => |_| {
                        const enum_value: item_type = std.meta.intToEnum(
                            item_type,
                            item,
                        ) catch @enumFromInt(0); // if anything, fallback to default enum value

                        (try @field(proto, proto_field.name).addOne(allocator)).* = enum_value;
                    },
                    inline else => |_| {},
                }
            }
        }
    }
}

pub inline fn addManyToList(allocator: Allocator, proto: anytype, comptime field: anytype, items: anytype) !void {
    const item_type = std.meta.Child(@TypeOf(items));
    const list_type = std.ArrayList(item_type);
    const proto_fields = std.meta.fields(std.meta.Child(@TypeOf(proto)));

    inline for (proto_fields) |proto_field| {
        if (comptime std.mem.eql(u8, @tagName(field), proto_field.name) and proto_field.type == list_type) {
            (try @field(proto, proto_field.name).addManyAsArray(allocator, @field(items, "len"))).* = items;
        }
    }
}

pub inline fn setFields(proto: anytype, to_set: anytype) void {
    @setEvalBranchQuota(1_000_000);

    const proto_fields = std.meta.fields(std.meta.Child(@TypeOf(proto)));

    const set_fields: []const std.builtin.Type.StructField = switch (@typeInfo(@TypeOf(to_set))) {
        inline .@"struct" => |container_info| container_info.fields,
        inline else => |_, tag| @compileError("protocol.setFields requires a struct of arbitrary fields, but got '" ++ @tagName(tag) ++ "' instead."),
    };

    inline for (set_fields) |set_field| {
        inline for (proto_fields) |proto_field| {
            if (comptime std.mem.eql(u8, set_field.name, proto_field.name)) {
                const proto_field_type = @typeInfo(proto_field.type);
                switch (proto_field_type) {
                    inline .@"enum" => |_| {
                        // enums are special, we set them by the discriminator itself (always i32 in protobuf enums)
                        const enum_value: proto_field.type = std.meta.intToEnum(
                            proto_field.type,
                            @field(to_set, proto_field.name),
                        ) catch @enumFromInt(0); // if anything, fallback to default enum value

                        @field(proto, proto_field.name) = enum_value;
                    },
                    inline else => |_| @field(proto, proto_field.name) = @field(to_set, proto_field.name),
                }
            }
        }
    }
}

fn cmdNames(comptime T: type) [10_000]?[]const u8 {
    @setEvalBranchQuota(10_000);

    var output: [10_000]?[]const u8 = undefined;
    @memset(&output, null);

    const decls = std.meta.declarations(T);

    inline for (decls) |decl| {
        const inner_struct = @field(T, decl.name);
        if (@hasDecl(inner_struct, "cmd_id") and @field(inner_struct, "cmd_id") != 0) {
            output[@intCast(@field(inner_struct, "cmd_id"))] = @typeName(inner_struct);
        }
    }

    return output;
}

pub const DummyMessage = struct {
    pub const cmd_id = 1959;
    pb: protobuf.ProtobufMixins(@This()) = .{},

    pub const _desc_table = .{};
};
