extends RefCounted
class_name ProfileManager

const SAVE_PATH: String = "user://forest_profile.json"

static func default_profile() -> Dictionary:
    return {
        "account_created":false,
        "profile_id":"",
        "player_name":"",
        "level":1,
        "xp":0,
        "gold":12000,
        "win_streak":0,
        "selected_kart":"rookie",
        "owned_karts":[
            "rookie","koala_sprinter","bamboo_koala_gt","koala_drift_x","phantom",
            "yanghyunhoo_turbo","yanghyunhoo_blaze","koala_hyunhoo_mix","running_seala","gold"
        ],
        "kart_levels":{
            "rookie":0,"koala_sprinter":0,"bamboo_koala_gt":0,"koala_drift_x":0,"phantom":0,
            "yanghyunhoo_turbo":0,"yanghyunhoo_blaze":0,"koala_hyunhoo_mix":0,"running_seala":0,"gold":0
        },
        "owned_equipment":["comfort_tire"],
        "equipped_equipment":"comfort_tire",
        "owned_cosmetics":[],
        "upgrade_material":0,
        "total_races":0,
        "wins":0,
        "redeemed_codes":[]
    }

static func sanitize_nickname(value: String) -> String:
    var clean: String = value.strip_edges().replace("\n"," ").replace("\r"," ").replace("\t"," ")
    while clean.contains("  "):
        clean = clean.replace("  "," ")
    if clean.length() > 12:
        clean = clean.substr(0,12)
    return clean

static func create_profile_id() -> String:
    var stamp: int = int(Time.get_unix_time_from_system()) % 1000000
    var salt: int = 100 + int(randi() % 900)
    return "%06d-%03d" % [stamp,salt]

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

    loaded["player_name"] = sanitize_nickname(str(loaded.get("player_name","")))

    # v71 migration: make the new running koala available on existing local profiles.
    var owned: Array = loaded.get("owned_karts",[]) as Array
    if not owned.has("running_seala"):
        owned.append("running_seala")
    loaded["owned_karts"] = owned

    var levels: Dictionary = loaded.get("kart_levels",{}) as Dictionary
    if not levels.has("running_seala"):
        levels["running_seala"] = 0
    loaded["kart_levels"] = levels

    return loaded

static func create_or_update_account(profile: Dictionary, nickname: String) -> Dictionary:
    var out: Dictionary = profile.duplicate(true)
    var clean: String = sanitize_nickname(nickname)
    if clean.length() < 2:
        return out
    if str(out.get("profile_id","")).is_empty():
        out["profile_id"] = create_profile_id()
    out["player_name"] = clean
    out["account_created"] = true
    save_profile(out)
    return out

static func save_profile(profile: Dictionary) -> void:
    var f: FileAccess = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(profile,"  "))
