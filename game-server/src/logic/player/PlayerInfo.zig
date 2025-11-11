const std = @import("std");
const Allocator = std.mem.Allocator;

const protocol = @import("protocol");
const ByName = protocol.ByName;
const makeProto = protocol.makeProto;

const property = @import("../property.zig");
const PropertyPrimitive = property.PropertyPrimitive;
const PropertyString = property.PropertyString;

const Globals = @import("../../Globals.zig");
const TemplateCollection = @import("../../data/TemplateCollection.zig");
const Avatar = @import("Avatar.zig");
const ItemData = @import("ItemData.zig");
const SwitchData = @import("SwitchData.zig");
const MiscData = @import("MiscData.zig");
const TipsInfo = @import("TipsInfo.zig");
const CollectMap = @import("CollectMap.zig");
const PosInMainCity = @import("PosInMainCity.zig");
const MapData = @import("MapData.zig");
const TimeInfo = @import("TimeInfo.zig");

const GameplaySettings = @import("../../Globals.zig").GameplaySettings;

const rand = std.crypto.random;

const Self = @This();

const basic_info_group = .{ .level, .exp, .name_change_times, .nick_name, .avatar_id, .player_avatar_id, .control_guise_avatar_id };

allocator: Allocator,
uid: u32,
level: PropertyPrimitive(u32),
exp: PropertyPrimitive(u32),
name_change_times: PropertyPrimitive(u32),
nick_name: PropertyString,
avatar_id: PropertyPrimitive(u32),
player_avatar_id: PropertyPrimitive(u32),
control_guise_avatar_id: PropertyPrimitive(u32),
item_data: ItemData,
switch_data: SwitchData,
misc_data: MiscData,
tips_info: TipsInfo,
collect_map: CollectMap,
pos_in_main_city: PosInMainCity,
map_data: MapData,
time_info: TimeInfo,

pub fn init(uid: u32, allocator: Allocator) !Self {
    return .{
        .allocator = allocator,
        .uid = uid,
        .level = .init(60),
        .exp = .init(0),
        .name_change_times = .init(1),
        .nick_name = .init("ReversedRooms", null),
        .avatar_id = .init(2011),
        .player_avatar_id = .init(2011),
        .control_guise_avatar_id = .init(2011),
        .item_data = .init(allocator),
        .switch_data = .init(allocator),
        .misc_data = .init(allocator),
        .tips_info = .init(allocator),
        .collect_map = .init(allocator),
        .pos_in_main_city = try .init(allocator),
        .map_data = .init(allocator),
        .time_info = .init(),
    };
}

pub fn onFirstLogin(self: *Self, globals: *const Globals) !void {
    try self.unlockAll(&globals.templates);
    try self.pos_in_main_city.setDefaultPosition(globals);
}

fn unlockAll(self: *Self, templates: *const TemplateCollection) !void {
    for (templates.avatar_base_template_tb.payload.data) |avatar_template| {
        if (templates.getAvatarTemplateConfig(@intCast(avatar_template.id))) |config| {
            self.item_data.unlockAvatar(config) catch continue;
        }
    }

    for (templates.buddy_base_template_tb.payload.data) |buddy_template| {
        self.item_data.unlockBuddy(buddy_template) catch continue;
    }

    for (templates.weapon_template_tb.payload.data) |weapon_template| {
        try self.item_data.addWeapon(weapon_template);
    }

    try self.item_data.addCurrency(10, 10_000_000);
    try self.item_data.addCurrency(100, 10_000_000);
    try self.item_data.addCurrency(501, 240);

    for (templates.avatar_skin_base_template_tb.payload.data) |skin_template| {
        try self.item_data.unlockSkin(@intCast(skin_template.id));
    }

    try self.switch_data.openAllSystems();
    try self.misc_data.unlockAll(templates);
    try self.tips_info.unlockAll(templates);
    try self.collect_map.unlockAll(templates);
    try self.map_data.unlockAll(templates);

    try self.addRandomEquipment(templates);
}

pub fn addItemsFromSettings(self: *Self, settings: *const GameplaySettings, templates: *const TemplateCollection) !void {
    for (settings.avatar_overrides) |override| {
        if (self.item_data.getItemPtrAs(Avatar, override.id)) |avatar| {
            avatar.level = override.level;
            avatar.rank = @min(@divFloor(override.level, 10) + 1, 6);
            avatar.unlocked_talent_num = override.unlocked_talent_num;

            if (override.weapon) |config| {
                const weapon_uid = self.addWeaponByConfig(config, templates) catch |err| blk: {
                    if (err == error.InvalidConfig) break :blk 0;
                    return err;
                };

                self.item_data.getItemPtrAs(Avatar, override.id).?.cur_weapon_uid = weapon_uid;
            }

            for (override.equipment) |entry| {
                const slot, const config = entry;

                if (slot >= Avatar.equipment_num) {
                    std.log.err(
                        "invalid equip slot {} specified for avatar {}",
                        .{ slot, override.id },
                    );
                    continue;
                }

                const equip_uid = self.addEquipmentByConfig(config, templates) catch |err| blk: {
                    if (err == error.InvalidConfig) break :blk null;
                    return err;
                };

                self.item_data.getItemPtrAs(Avatar, override.id).?.dressed_equip[slot] = equip_uid;
            }
        } else {
            std.log.err("invalid avatar id {} in GameplaySettings", .{override.id});
        }
    }

    for (settings.weapons) |config| {
        _ = self.addWeaponByConfig(config, templates) catch |err| {
            if (err == error.InvalidConfig) continue;
            return err;
        };
    }

    for (settings.equipment) |config| {
        _ = self.addEquipmentByConfig(config, templates) catch |err| {
            if (err == error.InvalidConfig) continue;
            return err;
        };
    }
}

fn addWeaponByConfig(self: *Self, config: Globals.WeaponConfig, templates: *const TemplateCollection) !u32 {
    const template = templates.getConfigByKey(.weapon_template_tb, config.id) orelse {
        std.log.err("invalid weapon id {} in GameplaySettings", .{config.id});
        return error.InvalidConfig;
    };

    if (config.refine_level > template.refine_limit) {
        std.log.err("specified refine_level ({}) exceeds refine_limit ({}) for weapon {}", .{
            config.refine_level,
            template.refine_limit,
            config.id,
        });
        return error.InvalidConfig;
    }

    if (config.star > template.star_limit + 1) {
        std.log.err("specified star ({}) exceeds star_limit ({}) for weapon {}", .{
            config.star,
            template.star_limit,
            config.id,
        });
        return error.InvalidConfig;
    }

    const uid = self.item_data.nextUid();

    try self.item_data.item_map.put(uid, .{ .weapon = .{
        .id = config.id,
        .uid = uid,
        .level = config.level,
        .star = config.star,
        .refine_level = config.refine_level,
        .exp = 0,
        .lock = false,
    } });
    return uid;
}

fn addEquipmentByConfig(self: *Self, config: Globals.EquipConfig, templates: *const TemplateCollection) !u32 {
    if (templates.getConfigByKey(.equipment_template_tb, config.id) == null) {
        std.log.err("invalid equip id {} in GameplaySettings", .{config.id});
        return error.InvalidConfig;
    }

    if (config.properties.len > ItemData.Equip.main_property_count) {
        std.log.err("amount of equip properties is higher than allowed! ({}/{})", .{
            config.properties.len,
            ItemData.Equip.main_property_count,
        });
        return error.InvalidConfig;
    }

    if (config.sub_properties.len > ItemData.Equip.sub_property_count) {
        std.log.err("amount of equip sub properties is higher than allowed! ({}/{})", .{
            config.sub_properties.len,
            ItemData.Equip.sub_property_count,
        });
        return error.InvalidConfig;
    }

    const uid = self.item_data.nextUid();

    var equip = ItemData.Equip{
        .id = config.id,
        .uid = uid,
        .level = config.level,
        .star = config.star,
        .exp = 0,
        .properties = [_]?ItemData.Equip.Property{null} ** ItemData.Equip.main_property_count,
        .sub_properties = [_]?ItemData.Equip.Property{null} ** ItemData.Equip.sub_property_count,
    };

    for (config.properties, 0..config.properties.len) |prop, i| {
        const key, const base_value, const add_value = prop;
        equip.properties[i] = .{
            .key = key,
            .base_value = base_value,
            .add_value = add_value,
        };
    }

    for (config.sub_properties, 0..config.sub_properties.len) |prop, i| {
        const key, const base_value, const add_value = prop;
        equip.sub_properties[i] = .{
            .key = key,
            .base_value = base_value,
            .add_value = add_value,
        };
    }

    try self.item_data.item_map.put(uid, .{ .equip = equip });
    return uid;
}

const properties_map: []const struct { u32, []const u32, u32, []const u32, u32 } = &.{
    .{ 11103, &.{1}, 550, &.{ 1, 2, 3, 4, 5, 6 }, 112 },
    .{ 11102, &.{ 4, 5, 6 }, 750, &.{ 1, 2, 3, 4, 5, 6 }, 300 },
    .{ 12103, &.{2}, 79, &.{ 1, 2, 3, 4, 5, 6 }, 19 },
    .{ 12102, &.{ 4, 5, 6 }, 750, &.{ 1, 2, 3, 4, 5, 6 }, 300 },
    .{ 13103, &.{3}, 46, &.{ 1, 2, 3, 4, 5, 6 }, 15 },
    .{ 13102, &.{ 4, 5, 6 }, 1200, &.{ 1, 2, 3, 4, 5, 6 }, 480 },
    .{ 23203, &.{}, 0, &.{ 1, 2, 3, 4, 5, 6 }, 9 },
    .{ 23103, &.{5}, 600, &.{}, 0 },
    .{ 31402, &.{6}, 750, &.{}, 0 },
    .{ 31203, &.{4}, 23, &.{ 1, 2, 3, 4, 5, 6 }, 9 },
    .{ 21103, &.{4}, 1200, &.{ 1, 2, 3, 4, 5, 6 }, 480 },
    .{ 20103, &.{4}, 600, &.{ 1, 2, 3, 4, 5, 6 }, 240 },
    .{ 30502, &.{6}, 1500, &.{}, 0 },
    .{ 12202, &.{6}, 450, &.{}, 0 },
    .{ 31803, &.{5}, 750, &.{}, 0 },
    .{ 31903, &.{5}, 750, &.{}, 0 },
    .{ 31603, &.{5}, 750, &.{}, 0 },
    .{ 31703, &.{5}, 750, &.{}, 0 },
    .{ 31503, &.{5}, 750, &.{}, 0 },
};

fn addRandomEquipment(self: *Self, templates: *const TemplateCollection) !void {
    for (0..500) |_| {
        const uid = self.item_data.nextUid();
        const rand_suit_index = rand.int(usize) % templates.equipment_suit_template_tb.payload.data.len;
        const slot = 1 + (rand.int(u32) % 6);

        const suit_id: u32 = @intCast(templates.equipment_suit_template_tb.payload.data[rand_suit_index].id);
        const id = suit_id + 40 + slot;

        var equip = ItemData.Equip{
            .id = id,
            .uid = uid,
            .level = 15,
            .star = 1,
            .exp = 0,
            .properties = .{null},
            .sub_properties = .{ null, null, null, null },
        };

        var possible_main_properties: [properties_map.len]usize = undefined;
        var possible_main_properties_count: usize = 0;

        for (properties_map, 0..properties_map.len) |prop, i| {
            if (std.mem.containsAtLeastScalar(u32, prop.@"1", 1, slot)) {
                possible_main_properties[possible_main_properties_count] = i;
                possible_main_properties_count += 1;
            }
        }

        const main_property = &properties_map[possible_main_properties[rand.int(usize) % possible_main_properties_count]];

        equip.properties[0] = .{
            .key = main_property.@"0",
            .base_value = main_property.@"2",
            .add_value = 1,
        };

        var possible_sub_properties: [properties_map.len]usize = undefined;
        var possible_sub_properties_count: usize = 0;

        for (properties_map, 0..properties_map.len) |prop, i| {
            if (prop.@"0" != main_property.@"0" and std.mem.containsAtLeastScalar(u32, prop.@"3", 1, slot)) {
                possible_sub_properties[possible_sub_properties_count] = i;
                possible_sub_properties_count += 1;
            }
        }

        var add_value_mod: u32 = 6;
        for (0..4) |i| {
            const sub_property_idx = rand.int(usize) % possible_sub_properties_count;
            const sub_property = &properties_map[possible_sub_properties[sub_property_idx]];
            const add_value = rand.int(u32) % add_value_mod;
            add_value_mod -= add_value;

            equip.sub_properties[i] = .{
                .key = sub_property.@"0",
                .base_value = sub_property.@"4",
                .add_value = 1 + add_value,
            };

            // "remove" from array
            if (sub_property_idx != (possible_sub_properties_count - 1)) {
                const tmp = possible_sub_properties[possible_sub_properties_count - 1];
                possible_sub_properties[possible_sub_properties_count - 1] = possible_sub_properties[sub_property_idx];
                possible_sub_properties[sub_property_idx] = tmp;
            }

            possible_sub_properties_count -= 1;
        }

        try self.item_data.item_map.put(uid, .{ .equip = equip });
    }
}

pub fn dressEquipment(self: *Self, avatar_id: u32, equip_uid: u32, dress_index: u32) !void {
    var prev_equip_uid: ?u32 = null;

    if (self.item_data.getItemPtrAs(Avatar, avatar_id)) |avatar| {
        if (avatar.cur_weapon_uid != 0 and avatar.cur_weapon_uid != equip_uid) prev_equip_uid = avatar.dressed_equip[dress_index];
        avatar.dressed_equip[dress_index] = equip_uid;
    } else {
        std.log.debug("dressEquipment: avatar_id {} is not unlocked", .{avatar_id});
        return error.AvatarNotUnlocked;
    }

    var items = self.item_data.item_map.iterator();

    while (items.next()) |entry| {
        if (entry.key_ptr.* != avatar_id) {
            switch (entry.value_ptr.*) {
                .avatar => |*avatar| {
                    if (std.mem.indexOfScalar(?u32, &avatar.dressed_equip, equip_uid)) |i| {
                        avatar.dressed_equip[i] = prev_equip_uid;
                        try self.item_data.item_map.markAsChanged(entry.key_ptr.*);
                    }
                    break;
                },
                else => |_| {},
            }
        }
    }
}

pub fn hasChangedFields(self: *const Self) bool {
    inline for (std.meta.fields(Self)) |field_info| {
        const field_type = @FieldType(Self, field_info.name);

        // skip primitives
        switch (@typeInfo(field_type)) {
            inline .bool, .int, .float => continue,
            inline else => {},
        }

        if (@hasDecl(field_type, "isChanged")) {
            if (@field(field_type, "isChanged")(&@field(self, field_info.name))) {
                return true;
            }
        }
    }

    return false;
}

pub fn ackPlayerSync(self: *Self, allocator: Allocator) !ByName(.PlayerSyncScNotify) {
    var notify = makeProto(.PlayerSyncScNotify, .{});

    if (self.isBasicInfoChanged()) {
        const self_basic_info = try self.ackSelfBasicInfo(allocator);
        protocol.setFields(&notify, .{ .self_basic_info = self_basic_info });
    }

    inline for (std.meta.fields(Self)) |field_info| {
        const field_type = @FieldType(Self, field_info.name);

        // skip primitives
        switch (@typeInfo(field_type)) {
            inline .bool, .int, .float => continue,
            inline else => {},
        }

        if (@hasDecl(field_type, "ackPlayerSync") and @hasDecl(field_type, "isChanged")) {
            if (@field(field_type, "isChanged")(&@field(self, field_info.name))) {
                try @field(field_type, "ackPlayerSync")(&@field(self, field_info.name), &notify, allocator);
            }
        }
    }

    return notify;
}

pub fn reset(self: *Self) void {
    inline for (std.meta.fields(Self)) |field_info| {
        const field_type = @FieldType(Self, field_info.name);

        // skip primitives
        switch (@typeInfo(field_type)) {
            inline .bool, .int, .float => continue,
            inline else => {},
        }

        if (@hasDecl(field_type, "reset")) {
            @field(self, field_info.name).reset();
        }
    }
}

pub fn isBasicInfoChanged(self: *const Self) bool {
    inline for (basic_info_group) |field| {
        if (@field(self, @tagName(field)).isChanged()) {
            return true;
        }
    }

    return false;
}

pub fn ackSelfBasicInfo(self: *Self, allocator: Allocator) !ByName(.SelfBasicInfo) {
    var info = makeProto(.SelfBasicInfo, .{});

    inline for (basic_info_group) |field| {
        if (@FieldType(Self, @tagName(field)) == PropertyString) {
            const chars = @field(self, @tagName(field)).chars;
            const copied = try protocol.protobuf.ManagedString.copy(chars, allocator);
            protocol.setFields(&info, makeTuple(field, copied));
        } else {
            const value = @field(self, @tagName(field)).value;
            protocol.setFields(&info, makeTuple(field, value));
        }

        @field(self, @tagName(field)).reset();
    }

    return info;
}

pub fn deinit(self: *Self) void {
    inline for (std.meta.fields(Self)) |field| {
        const field_type = @FieldType(Self, field.name);

        // skip primitives
        switch (@typeInfo(field_type)) {
            inline .bool, .int, .float => continue,
            inline else => {},
        }

        if (@hasDecl(field_type, "deinit")) {
            @field(self, field.name).deinit();
        }
    }
}

fn NamedTuple(tag: anytype, comptime T: type) type {
    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &.{.{
            .name = @tagName(tag),
            .type = T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        }},
        .decls = &.{},
        .is_tuple = false,
    } });
}

fn makeTuple(tag: anytype, value: anytype) NamedTuple(tag, @TypeOf(value)) {
    var result: NamedTuple(tag, @TypeOf(value)) = undefined;
    @field(result, @tagName(tag)) = value;
    return result;
}
