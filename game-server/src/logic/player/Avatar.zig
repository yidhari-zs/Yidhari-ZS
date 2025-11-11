const std = @import("std");
const property = @import("../property.zig");
const protocol = @import("protocol");

const AvatarTemplateConfiguration = @import("../../data/templates.zig").AvatarTemplateConfiguration;
const Allocator = std.mem.Allocator;
const ByName = protocol.ByName;

const Self = @This();

pub const AvatarSkillType = enum(u32) {
    const count: usize = @typeInfo(@This()).@"enum".fields.len;

    common_attack = 0,
    special_attack = 1,
    evade = 2,
    cooperate_skill = 3,
    unique_skill = 4,
    core_skill = 5,
    assist_skill = 6,

    pub fn getMaxLevel(self: @This()) u32 {
        return switch (self) {
            .core_skill => 7,
            inline else => |_| 12,
        };
    }
};

pub const ShowWeaponType = enum(i32) {
    lock = 0,
    active = 1,
    inactive = 2,
};

pub const equipment_num: usize = 6;
pub const max_talent_num: u32 = 6;
pub const max_passive_skill_level: u32 = 6;

pub const container_field = .avatar_list;

id: u32,
level: u32,
exp: u32,
rank: u32,
unlocked_talent_num: u32,
talent_switch_list: [6]bool,
passive_skill_level: u32,
cur_weapon_uid: u32,
is_favorite: bool,
avatar_skin_id: u32,
skill_type_level: [AvatarSkillType.count]u32,
dressed_equip: [equipment_num]?u32,
show_weapon_type: ShowWeaponType,
is_awake_available: bool,
awake_id: u32,
is_awake_enabled: bool,

pub fn init(config: AvatarTemplateConfiguration) @This() {
    var skill_type_level: [AvatarSkillType.count]u32 = undefined;
    for (0..AvatarSkillType.count) |i| {
        const skill_type: AvatarSkillType = @enumFromInt(i);
        skill_type_level[i] = skill_type.getMaxLevel();
    }

    return .{
        .id = @intCast(config.base_template.id),
        .level = 60,
        .exp = 0,
        .rank = 6,
        .unlocked_talent_num = max_talent_num,
        .passive_skill_level = max_passive_skill_level,
        .talent_switch_list = .{ false, false, false, true, true, true },
        .cur_weapon_uid = 0,
        .is_favorite = false,
        .avatar_skin_id = 0,
        .skill_type_level = skill_type_level,
        .dressed_equip = [_]?u32{null} ** equipment_num,
        .show_weapon_type = .active,
        .is_awake_available = false,
        .awake_id = 0,
        .is_awake_enabled = false,
    };
}

pub fn toProto(self: *const @This(), allocator: Allocator) !ByName(.AvatarInfo) {
    var proto = protocol.makeProto(.AvatarInfo, .{
        .id = self.id,
        .level = self.level,
        .exp = self.exp,
        .rank = self.rank,
        .unlocked_talent_num = self.unlocked_talent_num,
        .passive_skill_level = self.passive_skill_level,
        .cur_weapon_uid = self.cur_weapon_uid,
        .is_favorite = self.is_favorite,
        .avatar_skin_id = self.avatar_skin_id,
        .show_weapon_type = @intFromEnum(self.show_weapon_type),
        .is_awake_available = self.is_awake_available,
        .awake_id = self.awake_id,
        .is_awake_enabled = self.is_awake_enabled,
    });

    for (self.skill_type_level, 0..self.skill_type_level.len) |level, skill_type| {
        try protocol.addToList(allocator, &proto, .skill_type_level, protocol.makeProto(.AvatarSkillLevel, .{
            .skill_type = @as(u32, @intCast(skill_type)),
            .level = level,
        }));
    }

    for (self.dressed_equip, 0..self.dressed_equip.len) |equip_uid, index| {
        if (equip_uid) |uid| {
            try protocol.addToList(allocator, &proto, .dressed_equip_list, protocol.makeProto(.DressedEquip, .{
                .equip_uid = uid,
                .index = @as(u32, @intCast(index)) + 1,
            }));
        }
    }

    try protocol.addManyToList(allocator, &proto, .talent_switch_list, self.talent_switch_list);
    return proto;
}
