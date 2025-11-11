const std = @import("std");
const protocol = @import("protocol");

const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMapUnmanaged;
const ByName = protocol.ByName;
const String = protocol.protobuf.ManagedString;
const Transform = @import("../math/Transform.zig");
const scene = @import("../scene.zig");
const SceneType = scene.SceneType;
const SceneUnitManager = @import("../SceneUnitManager.zig");

const ConfigEventAction = @import("../../data/graph/ConfigEventAction.zig");

const PlayerInfo = @import("../player/PlayerInfo.zig");
const TemplateCollection = @import("../../data/TemplateCollection.zig");
const EventGraphTemplateMap = @import("../../data/graph/EventGraphTemplateMap.zig");
const LevelEventGraphManager = @import("../event/LevelEventGraphManager.zig");

const SceneUnitInfo = SceneUnitManager.SceneUnitInfo;
const InteractInfo = SceneUnitManager.InteractInfo;

const Self = @This();

allocator: Allocator,
templates: *const TemplateCollection,
event_graph_map: *const EventGraphTemplateMap,
scene_owner_player: *PlayerInfo,
section_id: u32,
pos: PosInMainCity,
unit_manager: SceneUnitManager,
graph_manager: LevelEventGraphManager,
last_time_in_minutes: u32,
day_of_week: u32,
main_city_object_state: HashMap(i32, i32),
bgm_id: u32 = 0,
is_in_transition: bool = true,
force_refresh: bool = false,

pub fn create(scene_owner: *PlayerInfo, templates: *const TemplateCollection, event_graph_map: *const EventGraphTemplateMap, allocator: Allocator) !*Self {
    const ptr = try allocator.create(Self);

    const pos: PosInMainCity = blk: {
        if (scene_owner.pos_in_main_city.position) |transform| {
            break :blk .{ .dynamic = transform };
        } else {
            break :blk .{ .static = try allocator.dupe(u8, scene_owner.pos_in_main_city.last_transform_id) };
        }
    };

    ptr.* = .{
        .templates = templates,
        .event_graph_map = event_graph_map,
        .scene_owner_player = scene_owner,
        .section_id = scene_owner.pos_in_main_city.section_id,
        .pos = pos,
        .unit_manager = .init(allocator),
        .graph_manager = .init(allocator, .{ .hall = ptr }),
        .last_time_in_minutes = scene_owner.time_info.time_in_minutes.value,
        .day_of_week = scene_owner.time_info.day_of_week.value,
        .allocator = allocator,
        .main_city_object_state = .empty,
    };

    return ptr;
}

pub fn destroy(self: *Self) void {
    self.unit_manager.deinit();
    self.graph_manager.deinit();
    self.main_city_object_state.deinit(self.allocator);

    self.pos.deinit(self.allocator);
    self.allocator.destroy(self);
}

pub fn enterSection(self: *Self, section_id: u32, transform_id: []const u8) !void {
    if (self.section_id == section_id) {
        std.log.debug("HallScene.enterSection: section {} is already active", .{section_id});
        return error.SameSectionID;
    }

    try self.onExit();

    self.is_in_transition = true;
    self.section_id = section_id;
    try self.setPosition(.{ .static = transform_id });

    try self.onEnter();
}

pub fn onCreate(self: *Self) !void {
    var sections = self.event_graph_map.section_event_graphs.iterator();
    while (sections.next()) |entry| {
        const section_id = entry.key_ptr.*;
        const config = entry.value_ptr.*;

        for (config.on_add) |event_id| {
            try self.graph_manager.startEvent(section_id, config.id, &config.events, event_id);
        }
    }
}

pub fn onEnter(self: *Self) !void {
    if (self.event_graph_map.section_event_graphs.get(self.section_id)) |config| {
        for (config.on_enter) |event_id| {
            try self.graph_manager.startEvent(self.section_id, config.id, &config.events, event_id);
        }
    }
}

pub fn onExit(self: *Self) !void {
    if (self.event_graph_map.section_event_graphs.get(self.section_id)) |config| {
        for (config.on_exit) |event_id| {
            try self.graph_manager.startEvent(self.section_id, config.id, &config.events, event_id);
        }
    }
}

pub fn onTimeOfDayChanged(self: *Self) !void {
    // TODO: execute TimeEvent graph

    const prev_time = self.last_time_in_minutes;
    self.last_time_in_minutes = self.scene_owner_player.time_info.time_in_minutes.value;
    self.day_of_week = self.scene_owner_player.time_info.day_of_week.value;
    self.force_refresh = true;

    if (self.last_time_in_minutes < prev_time) {
        try self.onDayChange();
    }
}

fn onDayChange(_: *Self) !void {
    // TODO!
}

pub fn setObjectState(self: *Self, object: i32, state: i32) !void {
    try self.main_city_object_state.put(self.allocator, object, state);
}

pub fn flushNetEvents(self: *Self, context: anytype) !void {
    if (self.force_refresh) {
        self.force_refresh = false;
        try context.notify(try self.buildHallRefreshScNotify(context.arena));
    }

    try self.graph_manager.flushNetEvents(context);
}

fn buildHallRefreshScNotify(self: *const Self, allocator: Allocator) !ByName(.HallRefreshScNotify) {
    var notify = protocol.makeProto(.HallRefreshScNotify, .{
        .force_refresh = true,
        .section_id = self.section_id,
        .player_avatar_id = self.scene_owner_player.player_avatar_id.value,
        .control_guise_avatar_id = self.scene_owner_player.control_guise_avatar_id.value,
        .bgm_id = self.bgm_id,
        .day_of_week = self.day_of_week,
        .scene_time_in_minutes = self.last_time_in_minutes,
    });

    var scene_units = self.unit_manager.sectionUnits(self.section_id);
    while (scene_units.next()) |scene_unit| {
        try protocol.addToList(allocator, &notify, .scene_unit_list, try scene_unit.value_ptr.toProto(allocator));
    }

    var object_states = self.main_city_object_state.iterator();
    while (object_states.next()) |entry| {
        try protocol.addToMap(allocator, &notify, .main_city_object_state, entry.key_ptr.*, entry.value_ptr.*);
    }

    return notify;
}

pub fn interactWithUnit(self: *Self, npc_tag_id: u32, interact_id: u32) !void {
    if (self.unit_manager.getUnitSection(npc_tag_id) != self.section_id) {
        std.log.debug("interactWithUnit: no unit with tag {} in section {}", .{ npc_tag_id, self.section_id });
        return error.InvalidInteraction;
    }

    const unit_uid = (@as(u64, @intCast(self.section_id)) << 32 | @as(u64, @intCast(npc_tag_id)));
    if (self.unit_manager.unit_infos.getPtr(unit_uid)) |unit| {
        const interact_info = for (unit.interacts_info) |info| {
            if (info != null and info.?.id == interact_id) break info.?;
        } else {
            std.log.debug("interactWithUnit: unit with tag {} has no interact with id {}", .{ npc_tag_id, interact_id });
            return error.InvalidInteraction;
        };

        if (self.event_graph_map.npc_event_graphs.get(interact_info.id)) |npc_event_graph| {
            if (npc_event_graph.*.on_interact_event_id) |event_id| {
                try self.graph_manager.startEvent(self.section_id, interact_id, &npc_event_graph.events, event_id);
            }
        }
    }
}

pub fn createNpc(self: *Self, section_id: u32, tag_id: u32) !void {
    const template = self.templates.getConfigByKey(.main_city_object_template_tb, tag_id) orelse {
        std.log.err("createNpc: missing MainCityObjectTemplate, tag_id: {}", .{tag_id});
        return;
    };

    var unit = SceneUnitInfo.init(tag_id);

    for (template.default_interact_ids) |interact_id| {
        var interact = InteractInfo.init(interact_id, template.interact_name);
        interact.setScale(template.interact_scale);
        // interact.setScale(@splat(0));
        unit.setInteract(.npc, interact);
    }

    try self.unit_manager.addUnit(section_id, unit);
}

pub fn setPosition(self: *Self, pos: PosInMainCity) !void {
    self.pos.deinit(self.allocator);
    self.pos = try pos.copy(self.allocator);
}

pub const PosInMainCityType = enum {
    static,
    dynamic,
};

pub const PosInMainCity = union(PosInMainCityType) {
    static: []const u8,
    dynamic: Transform,

    pub fn copy(self: *const @This(), allocator: Allocator) !@This() {
        return switch (self.*) {
            .static => |str| .{ .static = try allocator.dupe(u8, str) },
            .dynamic => |transform| .{ .dynamic = transform },
        };
    }

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        switch (self.*) {
            .static => |str| allocator.free(str),
            else => {},
        }
    }
};

pub fn clearTransitionState(self: *Self) bool {
    if (self.is_in_transition) {
        self.is_in_transition = false;
        self.force_refresh = false; // any pending refresh should be cancelled if full update is going to be sent anyway (via EnterSceneScNotify)
        return true;
    }

    return false;
}

pub fn toProto(self: *const Self, allocator: Allocator) !ByName(.SceneData) {
    var hall_data = protocol.makeProto(.HallSceneData, .{
        .section_id = self.section_id,
        .player_avatar_id = self.scene_owner_player.player_avatar_id.value,
        .control_guise_avatar_id = self.scene_owner_player.control_guise_avatar_id.value,
        .bgm_id = self.bgm_id,
        .day_of_week = self.day_of_week,
        .scene_time_in_minutes = self.last_time_in_minutes,
    });

    switch (self.pos) {
        .static => |transform_id| {
            protocol.setFields(&hall_data, .{
                .transform_id = try String.copy(transform_id, allocator),
            });
        },
        .dynamic => |transform| {
            protocol.setFields(&hall_data, .{
                .position = try transform.toProto(allocator),
            });
        },
    }

    var scene_units = self.unit_manager.sectionUnits(self.section_id);
    while (scene_units.next()) |scene_unit| {
        try protocol.addToList(allocator, &hall_data, .scene_unit_list, try scene_unit.value_ptr.toProto(allocator));
    }

    var object_states = self.main_city_object_state.iterator();
    while (object_states.next()) |entry| {
        try protocol.addToMap(allocator, &hall_data, .main_city_object_state, entry.key_ptr.*, entry.value_ptr.*);
    }

    var lifts = self.scene_owner_player.pos_in_main_city.lift_status_map.iterator();
    while (lifts.next()) |entry| {
        try protocol.addToList(allocator, &hall_data, .lift_list, protocol.makeProto(.LiftInfo, .{
            .lift_status = entry.value_ptr.*,
            .lift_name = try protocol.protobuf.ManagedString.copy(entry.key_ptr.*, allocator),
        }));
    }

    return protocol.makeProto(.SceneData, .{
        .scene_type = @intFromEnum(SceneType.hall),
        .hall_scene_data = hall_data,
    });
}
