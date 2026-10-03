extends RefCounted
class_name ProfileManager

const SAVE_PATH: String = "user://forest_profile.json"

static func default_profile() -> Dictionary:
    return {
        "player_name":"Racer",
        "level":1,
        "xp":0,
        "gold":12000,
        "win_streak":0,
        "selected_kart":"rookie",
        "owned_karts":[
            "rookie","koala_sprinter","bamboo_koala_gt","koala_drift_x","phantom",
            "yanghyunhoo_turbo","yanghyunhoo_blaze","koala_hyunhoo_mix","gold"
        ],
        "kart_levels":{
            "rookie":0,"koala_sprinter":0,"bamboo_koala_gt":0,"koala_drift_x":0,"phantom":0,
            "yanghyunhoo_turbo":0,"yanghyunhoo_blaze":0,"koala_hyunhoo_mix":0,"gold":0
        },
        "owned_equipment":["comfort_tire"],
        "equipped_equipment":"comfort_tire",
        "owned_cosmetics":[],
        "upgrade_material":0,
        "total_races":0,
        "wins":0
    }

static func load_profile() -> Dictionary:
    var base: Dictionary = default_profile()
    if not FileAccess.file_exists(SAVE_PATH):
        save_profile(base)
        return base

    var f: FileAccess = FileAccess.open(SAVE_PATH,FileAccess.READ)
    if f == null:
        return base

    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if not (parsed is Dictionary):
        return base

    var loaded: Dictionary = parsed as Dictionary
    for key in base.keys():
        if not loaded.has(key):
            loaded[key] = base[key]
    return loaded

static func save_profile(profile: Dictionary) -> void:
    var f: FileAccess = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(profile,"  "))
