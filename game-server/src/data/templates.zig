const std = @import("std");
const TemplateCollection = @import("TemplateCollection.zig");

pub const AvatarBaseTemplate = struct {
    id: u32,
    camp: u8,
    gender: u8,
    name: []const u8,
    code_name: []const u8,
    full_name: []const u8,
    audio_event_replace_param: []const u8,
};

pub const AvatarBattleTemplate = struct {
    id: u32,
    avatar_piece_id: u32,
    hp_max: i32,
    health_growth: i32,
    attack: i32,
    attack_growth: i32,
    defence: i32,
    defence_growth: i32,
    crit: i32,
    crit_damage: i32,
    crit_res: i32,
    crit_damage_res: i32,
    pen_rate: i32,
    pen_delta: i32,
    luck: i32,
    stun: i32,
    break_stun: i32,
    element_abnormal_power: i32,
    sp_bar_point: i32,
    sp_recover: i32,
    element_mystery: i32,
    rbl: i32,
    rbl_correction_factor: i32,
    rbl_probability: i32,
    tags: [][]const u8 = &.{},
    weapon_type: i32,
    element: []const i32 = &.{},
    hit_type: []const i32 = &.{},
    base_avatar_id: u32,
    rp_max: i32,
    rp_recover: i32,
    awake_ids: []const u32 = &.{},
};

pub const ItemCount = struct {
    item_id: u32,
    number: u32,
};

pub const AvatarLevelAdvanceTemplate = struct {
    avatar_id: u32,
    id: u32,
    min_level: u32,
    max_level: u32,
    hp_max: i32,
    attack: i32,
    defence: i32,
    promotion_costs: []const ItemCount = &.{},
};

pub const PropertyValue = struct {
    property: u32,
    value: i32,
};

pub const AvatarPassiveSkillTemplate = struct {
    skill_id: u32,
    avatar_id: u32,
    min_avatar_level: u32,
    min_passive_skill_level: u32,
    unlock_passive_skill_level: u32,
    propertys: []const PropertyValue = &.{},
    material_costs: []const ItemCount = &.{},
};

pub const AvatarSkinBaseTemplate = struct {
    id: u32,
    avatar_id: u32,
};

pub const WeaponTemplate = struct {
    item_id: u32,
    weapon_name: []const u8,
    base_property: PropertyValue,
    rand_property: PropertyValue,
    star_limit: u32,
    refine_initial: u32,
    refine_limit: u32,
    exp_recycle: u32,
    weapon_script_config: []const u8,
    weapon_ui_model: []const u8,
    weapon_release_tag: []const u8,
    avatar_id: u32,
    refine_costs: []const ItemCount = &.{},
};

pub const WeaponLevelTemplate = struct {
    rarity: u32,
    level: u32,
    rate: i32,
    exp: u32,
};

pub const WeaponStarTemplate = struct {
    rarity: u32,
    star: u32,
    min_level: u32,
    max_level: u32,
    star_rate: i32,
    rand_rate: i32,
};

pub const EquipmentTemplate = struct {
    item_id: u32,
    equipment_type: u32,
    suit_type: u32,
};

pub const EquipmentSuitTemplate = struct {
    id: u32,
    name: []const u8,
    primary_condition: u32,
    primary_suit_ability: u32,
    secondary_condition: u32,
    secondary_suit_ability: u32,
    order: u32,
    primary_suit_propertys: []const PropertyValue = &.{},
};

pub const EquipmentLevelTemplate = struct {
    rarity: u32,
    level: u32,
    property_rate: i32,
};

pub const BuddyBaseTemplate = struct {
    id: u32,
};

pub const UnlockConfigTemplate = struct {
    id: u32,
    icon_res: []const u8,
    name: []const u8,
};

pub const TeleportConfigTemplate = struct {
    teleport_id: u32,
    client_visible: u1,
    unlock_condition: []const u8,
    section_id: u32,
    transform_id: u32,
};

pub const TipsConfigTemplate = struct {
    tips_id: i32,
    tips_text: []const u8,
    tips_group: u32,
};

pub const TipsGroupConfigTemplate = struct {
    tips_group_id: i32,
    group_icon: []const u8,
    priority: u32,
};

pub const LoadingPageTipsTemplate = struct {
    id: i32,
    trigger_condition: []const u8,
};

pub const LockTipConfigTemplate = struct {
    id: u32,
};

pub const WorkBenchAppDexTemplate = struct {
    id: u32,
};

pub const ClueConfigTemplate = struct {
    id: i32,
    name: []const u8,
    item_prefab_path: []const u8,
    unlock_condition: []const u8,
    clue_des: []const u8,
};

pub const PostGirlConfigTemplate = struct {
    id: u32,
    name: []const u8,
    unlock_condition: []const u8,
};

pub const MainCityObjectTemplate = struct {
    tag_id: u32,
    npc_id: u32,
    create_position: []const u8,
    create_type: u32,
    npc_name: []const u8,
    interact_name: []const u8,
    interact_shape: u32,
    interact_scale: []const f32 = &.{},
    fan_interact_param: []const u8,
    focus_interact_scale: f32,
    default_interact_ids: []const u32 = &.{},
};

pub const SectionConfigTemplate = struct {
    section_id: u32,
    name: []const u8,
    default_transform: []const u8,
    section_name: []const u8,
};

pub const UrbanAreaMapTemplate = struct {
    area_id: u32,
    icon: []const u8,
    group_name: []const u8,
};

pub const UrbanAreaMapGroupTemplate = struct {
    area_group_id: u32,
    group_name: []const u8,
    is_map_visible: bool,
};

pub const ZoneInfoTemplate = struct {
    zone_id: u32,
    name: []const u8,
    layer_id: u32,
    layer_index: u32,
    group_id: u32,
    zone_group_id: u32,
    entrance_id: u32,
    time_period_list: [][]const u8 = &.{},
};

pub const LayerInfoTemplate = struct {
    layer_id: u32,
    monster_level: u32,
    layer_room_ids: []const u32 = &.{},
    layer_items: []const u32 = &.{},
    weather_list: [][]const u8 = &.{},
};

pub const QuestType = enum(u32) {
    training = 17,
};

pub const QuestConfigTemplate = struct {
    quest_id: u32,
    quest_name: []const u8,
    quest_type: u32,
    desc: []const u8,
    target_desc: []const u8,
    quest_desc: []const u8,
    icon: []const u8,
    auto_finish: bool,
    unlock_condition: []const u8,
    finish_condition: []const u8,

    pub const QuestConfigExt = union(QuestType) {
        training: *const TrainingQuestTemplate,

        pub fn getSceneId(self: @This()) ?u32 {
            return switch (self) {
                .training => |training| training.battle_event_id,
                // TODO: uncomment this when there will be other quest types that don't have scene bound to them.
                // else => null,
            };
        }
    };

    pub fn getExtendedTemplate(self: *const @This(), collection: *const TemplateCollection) !QuestConfigExt {
        const quest_type: QuestType = std.meta.intToEnum(QuestType, self.quest_type) catch return error.UnknownQuestType; // Quest type is not implemented yet

        switch (quest_type) {
            inline else => |quest_type_case| {
                const template = collection.getConfigByKey(@tagName(quest_type_case) ++ "_quest_template_tb", self.quest_id) orelse return error.MissingQuestTemplate;
                return @unionInit(QuestConfigExt, @tagName(quest_type_case), template);
            },
        }
    }
};

pub const HadalZoneQuestTemplate = struct {
    quest_id: u32,
    layer_id: u32,
};

pub const TrainingQuestTemplate = struct {
    id: u32,
    training_type: u32,
    battle_event_id: u32,
    special_training_name: []const u8,
    special_training_icon: []const u8,
};

pub const BattleEventConfigTemplate = struct {
    id: u32,
    level_design_id: u32,
    unlock_condition: []const u8,
    play_type: u32,
    desc: []const u8,
    normal_drop: []const u8,
    special_reward: []const u32 = &.{},
};

pub const AvatarTemplateConfiguration = struct {
    base_template: *const AvatarBaseTemplate,
    battle_template: *const AvatarBattleTemplate,
    special_awaken_templates: [6]?*const AvatarSpecialAwakenTemplate,
};

pub const AvatarSpecialAwakenTemplate = struct {
    id: u32,
    avatar_id: u32,
    upgrade_item_ids: []const u32 = &.{},
};
