const std = @import("std");
pub const templates = @import("templates.zig");

const ArenaAllocator = std.heap.ArenaAllocator;

const tb_items_field = "payload";
const map_name_suffix = "_indexes";
const max_file_size = 128 * 1024 * 1024;
const Self = @This();

arena: ArenaAllocator,
avatar_base_template_tb: TemplateTb(templates.AvatarBaseTemplate, .id),
avatar_battle_template_tb: TemplateTb(templates.AvatarBattleTemplate, .id),
avatar_level_advance_template_tb: TemplateTb(templates.AvatarLevelAdvanceTemplate, .avatar_id),
avatar_passive_skill_template_tb: TemplateTb(templates.AvatarPassiveSkillTemplate, .skill_id),
avatar_skin_base_template_tb: TemplateTb(templates.AvatarSkinBaseTemplate, .id),
weapon_template_tb: TemplateTb(templates.WeaponTemplate, .item_id),
weapon_level_template_tb: TemplateTb(templates.WeaponLevelTemplate, .level),
weapon_star_template_tb: TemplateTb(templates.WeaponStarTemplate, .star),
equipment_template_tb: TemplateTb(templates.EquipmentTemplate, .item_id),
equipment_suit_template_tb: TemplateTb(templates.EquipmentSuitTemplate, .id),
equipment_level_template_tb: TemplateTb(templates.EquipmentLevelTemplate, .level),
buddy_base_template_tb: TemplateTb(templates.BuddyBaseTemplate, .id),
unlock_config_template_tb: TemplateTb(templates.UnlockConfigTemplate, .id),
teleport_config_template_tb: TemplateTb(templates.TeleportConfigTemplate, .teleport_id),
tips_config_template_tb: TemplateTb(templates.TipsConfigTemplate, .tips_id),
tips_group_config_template_tb: TemplateTb(templates.TipsGroupConfigTemplate, .tips_group_id),
loading_page_tips_template_tb: TemplateTb(templates.LoadingPageTipsTemplate, .id),
lock_tip_config_template_tb: TemplateTb(templates.LockTipConfigTemplate, .id),
work_bench_app_dex_template_tb: TemplateTb(templates.WorkBenchAppDexTemplate, .id),
clue_config_template_tb: TemplateTb(templates.ClueConfigTemplate, .id),
post_girl_config_template_tb: TemplateTb(templates.PostGirlConfigTemplate, .id),
main_city_object_template_tb: TemplateTb(templates.MainCityObjectTemplate, .tag_id),
section_config_template_tb: TemplateTb(templates.SectionConfigTemplate, .section_id),
urban_area_map_template_tb: TemplateTb(templates.UrbanAreaMapTemplate, .area_id),
urban_area_map_group_template_tb: TemplateTb(templates.UrbanAreaMapGroupTemplate, .area_group_id),
zone_info_template_tb: TemplateTb(templates.ZoneInfoTemplate, .zone_id),
layer_info_template_tb: TemplateTb(templates.LayerInfoTemplate, .layer_id),
quest_config_template_tb: TemplateTb(templates.QuestConfigTemplate, .quest_id),
hadal_zone_quest_template_tb: TemplateTb(templates.HadalZoneQuestTemplate, .layer_id),
training_quest_template_tb: TemplateTb(templates.TrainingQuestTemplate, .id),
battle_event_config_template_tb: TemplateTb(templates.BattleEventConfigTemplate, .id),
avatar_special_awaken_template_tb: TemplateTb(templates.AvatarSpecialAwakenTemplate, .id),

pub fn load(gpa: std.mem.Allocator) !Self {
    @setEvalBranchQuota(1_000_000);

    var collection: Self = undefined;
    collection.arena = ArenaAllocator.init(gpa);

    inline for (std.meta.fields(Self)) |field| {
        if (field.type == ArenaAllocator) continue;

        const content = try std.fs.cwd().readFileAllocOptions(gpa, comptime getJsonPath(field.type), max_file_size, null, .of(u8), 0);
        defer gpa.free(content);

        @field(collection, field.name) = try parseFromSlice(field.type, content, collection.arena.allocator());
    }

    return collection;
}

fn TableItemType(comptime table_name: anytype) type {
    const tb_name = if (@typeInfo(@TypeOf(table_name)) == .enum_literal) @tagName(table_name) else table_name;
    return std.meta.Elem(@FieldType(@FieldType(@FieldType(Self, tb_name), "payload"), "data"));
}

pub fn getConfigByKey(self: *const Self, comptime table_name: anytype, key: anytype) ?*const TableItemType(table_name) {
    const tb_name = if (@typeInfo(@TypeOf(table_name)) == .enum_literal) @tagName(table_name) else table_name;

    const template_tb = @field(self, tb_name);
    const key_map = @field(template_tb, keyMapName(@TypeOf(template_tb)));
    const index = key_map.get(key) orelse return null;

    return &template_tb.payload.data[index];
}

pub fn getAvatarTemplateConfig(self: *const Self, avatar_id: u32) ?templates.AvatarTemplateConfiguration {
    return .{
        .base_template = self.getConfigByKey(.avatar_base_template_tb, avatar_id) orelse return null,
        .battle_template = self.getConfigByKey(.avatar_battle_template_tb, avatar_id) orelse return null,
        .special_awaken_templates = self.getAvatarSpecialAwakenConfigs(avatar_id),
    };
}

pub fn getAvatarSpecialAwakenConfigs(self: *const Self, avatar_id: u32) [6]?*const templates.AvatarSpecialAwakenTemplate {
    var arr: [6]?*const templates.AvatarSpecialAwakenTemplate = @splat(null);

    var idx: u32 = 0;
    for (self.avatar_special_awaken_template_tb.payload.data) |*template| {
        if (template.avatar_id == avatar_id) {
            arr[idx] = template;
            idx += 1;
        }
    }

    return arr;
}

pub fn getAvatarLevelAdvanceTemplate(self: *const Self, avatar_id: u32, advance_id: u32) ?templates.AvatarLevelAdvanceTemplate {
    for (self.avatar_level_advance_template_tb.payload.data) |template| {
        if (template.avatar_id == avatar_id and template.id == advance_id) {
            return template;
        }
    }

    return null;
}

pub fn getAvatarPassiveSkillTemplate(self: *const Self, avatar_id: u32, passive_skill_level: u32) ?*const templates.AvatarPassiveSkillTemplate {
    return self.getConfigByKey(.avatar_passive_skill_template_tb, avatar_id * 1000 + passive_skill_level);
}

pub fn getWeaponLevelTemplate(self: *const Self, rarity: u32, level: u32) ?templates.WeaponLevelTemplate {
    for (self.weapon_level_template_tb.payload.data) |template| {
        if (template.rarity == rarity and template.level == level) {
            return template;
        }
    }

    return null;
}

pub fn getWeaponStarTemplate(self: *const Self, rarity: u32, star: u32) ?templates.WeaponStarTemplate {
    for (self.weapon_star_template_tb.payload.data) |template| {
        if (template.rarity == rarity and template.star == star) {
            return template;
        }
    }

    return null;
}

pub fn getEquipmentLevelTemplate(self: *const Self, rarity: u32, level: u32) ?templates.EquipmentLevelTemplate {
    for (self.equipment_level_template_tb.payload.data) |template| {
        if (template.rarity == rarity and template.level == level) {
            return template;
        }
    }

    return null;
}

pub fn getSectionDefaultTransform(self: *const Self, section_id: u32) ?[]const u8 {
    const config = self.getConfigByKey(.section_config_template_tb, section_id) orelse return null;
    return config.default_transform;
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

fn getJsonPath(comptime Table: type) []const u8 {
    const type_name = @typeName(Table);
    const end_index = std.mem.indexOfScalar(u8, type_name, ',').?;
    const start_index = std.mem.lastIndexOfScalar(u8, type_name[0..end_index], '.').? + 1;
    const file_name = type_name[start_index..end_index];
    return "assets/Filecfg/" ++ file_name ++ "Tb.json";
}

fn TemplateTb(comptime Template: type, comptime key: anytype) type {
    const key_name = @tagName(key);
    const key_type = @FieldType(Template, key_name);

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &.{
                .{
                    .name = tb_items_field,
                    .type = struct { data: []const Template },
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf([]const Template),
                },
                .{
                    .name = @tagName(key) ++ map_name_suffix,
                    .type = std.AutoHashMapUnmanaged(key_type, usize),
                    .default_value_ptr = &std.AutoHashMapUnmanaged(key_type, usize).empty,
                    .is_comptime = false,
                    .alignment = @alignOf(std.AutoHashMapUnmanaged(key_type, usize)),
                },
            },
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

inline fn keyMapName(comptime TB: type) []const u8 {
    inline for (std.meta.fields(TB)) |field| {
        if (comptime std.mem.endsWith(u8, @as([]const u8, @ptrCast(field.name)), map_name_suffix)) {
            return field.name;
        }
    }

    @compileError(@typeName(TB) ++ " doesn't have key index map field");
}

inline fn keyName(comptime TB: type) []const u8 {
    const name = keyMapName(TB);
    return name[0 .. name.len - map_name_suffix.len];
}

fn parseFromSlice(comptime TB: type, slice: []const u8, allocator: std.mem.Allocator) !TB {
    const payload = try std.json.parseFromSliceLeaky(
        @FieldType(TB, tb_items_field),
        allocator,
        slice,
        .{ .ignore_unknown_fields = true, .allocate = .alloc_always },
    );

    const key_map_type = @FieldType(TB, keyName(TB) ++ map_name_suffix);
    var map = key_map_type.empty;

    for (payload.data, 0..payload.data.len) |item, i| {
        const key = @field(item, keyName(TB));
        try map.put(allocator, key, i);
    }

    var template_tb: TB = undefined;

    template_tb.payload = payload;
    @field(template_tb, keyName(TB) ++ map_name_suffix) = map;

    return template_tb;
}
