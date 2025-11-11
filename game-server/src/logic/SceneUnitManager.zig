const std = @import("std");
const protocol = @import("protocol");

const InteractScaleCfg = @import("../data/graph/action.zig").InteractScaleCfg;

const Allocator = std.mem.Allocator;
const HashMap = std.AutoArrayHashMapUnmanaged;

const ByName = protocol.ByName;
const makeProto = protocol.makeProto;

const Self = @This();

const SceneUnitMap = HashMap(u64, SceneUnitInfo);

allocator: Allocator,
unit_infos: SceneUnitMap,
unit_sections: HashMap(u32, u32),

pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
        .unit_infos = .empty,
        .unit_sections = .empty,
    };
}

pub fn deinit(self: *Self) void {
    self.unit_infos.deinit(self.allocator);
    self.unit_sections.deinit(self.allocator);
}

pub fn getUnitSection(self: *const Self, tag_id: u32) ?u32 {
    return self.unit_sections.get(tag_id);
}

pub fn getSceneUnit(self: *Self, section_id: u32, tag_id: u32) ?*SceneUnitInfo {
    const uid = (@as(u64, @intCast(section_id)) << 32 | @as(u64, @intCast(tag_id)));
    return self.unit_infos.getPtr(uid);
}

pub fn sectionUnits(self: *const Self, section_id: u32) SectionUnitIterator {
    return .{
        .inner = self.unit_infos.iterator(),
        .filter_section_id = section_id,
    };
}

pub fn addUnit(self: *Self, section_id: u32, info: SceneUnitInfo) !void {
    const uid = (@as(u64, @intCast(section_id)) << 32 | @as(u64, @intCast(info.tag_id)));

    try self.unit_sections.put(self.allocator, info.tag_id, section_id);
    try self.unit_infos.put(self.allocator, uid, info);
}

const SectionUnitIterator = struct {
    inner: SceneUnitMap.Iterator,
    filter_section_id: u32,

    pub fn next(self: *@This()) ?SceneUnitMap.Entry {
        while (self.inner.next()) |entry| {
            const section_id: u32 = @intCast(entry.key_ptr.* >> 32);
            if (section_id == self.filter_section_id) return entry;
        }

        return null;
    }
};

pub const InteractTarget = enum(usize) {
    const count: usize = @typeInfo(@This()).@"enum".fields.len;

    trigger_box,
    npc,
};

pub const SceneUnitInfo = struct {
    tag_id: u32,
    interacts_info: [InteractTarget.count]?InteractInfo,

    pub fn init(tag_id: u32) @This() {
        return .{
            .tag_id = tag_id,
            .interacts_info = [_]?InteractInfo{null} ** InteractTarget.count,
        };
    }

    pub fn setInteract(self: *@This(), target: InteractTarget, info: InteractInfo) void {
        self.interacts_info[@intFromEnum(target)] = info;
    }

    pub fn toProto(self: *const @This(), allocator: Allocator) !ByName(.SceneUnitProtocolInfo) {
        var unit_proto = makeProto(.SceneUnitProtocolInfo, .{
            .npc_id = self.tag_id,
            .is_active = true,
        });

        for (self.interacts_info, 0..self.interacts_info.len) |interact, i| {
            const tag_id: i32 = @intCast(self.tag_id);

            const info = interact orelse continue;
            const interact_target = @as(i32, @intCast(i)) + 1;

            var interact_proto = makeProto(.InteractInfo, .{
                .name = try protocol.protobuf.ManagedString.copy(info.name, allocator),
                .tag_id = tag_id,
                .scale_x = info.scale_x,
                .scale_y = info.scale_y,
                .scale_z = info.scale_z,
                .scale_w = info.scale_w,
                .scale_r = info.scale_r,
            });

            try protocol.addToList(allocator, &interact_proto, .interact_target_list, interact_target);
            try protocol.addToMap(allocator, &interact_proto, .participators, self.tag_id, try protocol.protobuf.ManagedString.copy(info.name, allocator));
            try protocol.addToMap(allocator, &unit_proto, .interacts_info, info.id, interact_proto);
        }

        return unit_proto;
    }
};

pub const InteractInfo = struct {
    id: u32,
    name: []const u8,
    scale_x: f64 = 0,
    scale_y: f64 = 0,
    scale_z: f64 = 0,
    scale_w: f64 = 0,
    scale_r: f64 = 0,

    pub fn init(id: u32, name: []const u8) @This() {
        return .{ .id = id, .name = name };
    }

    pub fn setScale(self: *@This(), scale: []const f32) void {
        if (scale.len == 5) {
            self.scale_x = @floatCast(scale[0]);
            self.scale_y = @floatCast(scale[1]);
            self.scale_z = @floatCast(scale[2]);
            self.scale_w = @floatCast(scale[3]);
            self.scale_r = @floatCast(scale[4]);
        } else if (scale.len == 1) {
            self.scale_x = @floatCast(scale[0]);
            self.scale_y = @floatCast(scale[0]);
            self.scale_z = @floatCast(scale[0]);
            self.scale_w = @floatCast(scale[0]);
            self.scale_r = @floatCast(scale[0]);
        }
    }

    pub fn setScaleFromConfig(self: *@This(), scale: InteractScaleCfg) void {
        self.scale_x = scale.x;
        self.scale_y = scale.y;
        self.scale_z = scale.z;
        self.scale_w = scale.w;
        self.scale_r = scale.r;
    }
};
