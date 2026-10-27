extends RefCounted
## ALL THE NUMBERS AND JOKES IN ONE PLACE. Tweak freely!
## In text, {a} = the actor, {t} = the target, {e} = the enemy.

# timing = how fast the BASH timing marker moves (1.0 = crosses the bar in ~1.1s)
const PARTY := [
	{"id": "nova", "name": "NOVA", "hp": 64, "en": 20, "atk": 14, "def": 6, "spd": 12, "timing": 1.3,
		"techs": ["laser_volley", "overdrive"], "bash": "{a} FIRES A BLASTER AT {t}!"},
	{"id": "bolt", "name": "BOLT", "hp": 92, "en": 14, "atk": 12, "def": 10, "spd": 6, "timing": 0.8,
		"techs": ["arc_welder", "shield_wall"], "bash": "{a} SWINGS A WRENCH-ARM AT {t}!"},
	{"id": "ziggy", "name": "ZIGGY", "hp": 50, "en": 32, "atk": 8, "def": 5, "spd": 10, "timing": 1.0,
		"techs": ["psi_mend", "starstorm", "revive_spore"], "bash": "{a} BONKS {t} WITH A HYDROPONIC STAFF!"},
]

# BASH timing grades, checked in order. px = how far (in pixels) the marker can
# be from the center of the target zone. Not pressing at all = a miss.
# auto = how often auto-battle lands each grade.
const TIMING_GRADES := [
	{"id": "perfect", "px": 4, "mult": 1.8, "text": "PERFECT!!", "auto": 2},
	{"id": "great", "px": 12, "mult": 1.3, "text": "GREAT!", "auto": 4},
	{"id": "good", "px": 26, "mult": 1.0, "text": "GOOD", "auto": 3},
	{"id": "weak", "px": 9999, "mult": 0.5, "text": "WEAK...", "auto": 1},
]

# target: enemy | all_enemies | ally | ally_ko | all_allies | none
# effect: damage (uses ATK vs DEF) | magic (fixed power) | heal | energy | revive | shield | duck
const TECHS := {
	"laser_volley": {"name": "LASER VOLLEY", "cost": 5, "target": "all_enemies", "effect": "damage", "power": 0.9,
		"fx": "laser", "sfx": "tech_laser", "desc": "PEW PEW PEW. HITS ALL ENEMIES."},
	"overdrive": {"name": "OVERDRIVE", "cost": 7, "target": "enemy", "effect": "damage", "power": 2.2,
		"fx": "burst", "sfx": "tech_overdrive", "desc": "REDLINE THE ENGINES. BIG HIT ON ONE FOE."},
	"arc_welder": {"name": "ARC WELDER", "cost": 3, "target": "enemy", "effect": "damage", "power": 1.3, "stun": 0.4,
		"fx": "zap", "sfx": "tech_zap", "desc": "ZAP ONE ENEMY. MIGHT STUN IT."},
	"shield_wall": {"name": "SHIELD WALL", "cost": 6, "target": "all_allies", "effect": "shield", "turns": 3,
		"fx": "shield", "sfx": "tech_shield", "desc": "CREW TAKES LESS DAMAGE FOR 3 TURNS."},
	"psi_mend": {"name": "PSI MEND", "cost": 4, "target": "ally", "effect": "heal", "power": 40,
		"fx": "heal", "sfx": "heal", "desc": "RESTORES ABOUT 40 HP TO ONE ALLY."},
	"starstorm": {"name": "STARSTORM", "cost": 12, "target": "all_enemies", "effect": "magic", "power": 30,
		"fx": "stars", "sfx": "tech_psi", "desc": "CALL DOWN THE COSMOS ON ALL ENEMIES."},
	"revive_spore": {"name": "REVIVE SPORE", "cost": 8, "target": "ally_ko", "effect": "revive", "power": 0.4,
		"fx": "spore", "sfx": "revive", "desc": "REVIVES A KO'D ALLY WITH 40% HP."},
}

const ITEMS := {
	"burrito": {"name": "SPACE BURRITO", "count": 3, "target": "ally", "effect": "heal", "power": 40,
		"fx": "heal", "desc": "STILL FROZEN IN THE MIDDLE. HEALS 40 HP."},
	"nano_gel": {"name": "NANO GEL", "count": 2, "target": "ally", "effect": "heal", "power": 100,
		"fx": "heal", "desc": "TINY ROBOTS FIX EVERYTHING. HEALS 100 HP."},
	"energy_cell": {"name": "ENERGY CELL", "count": 2, "target": "ally", "effect": "energy", "power": 15,
		"fx": "energy", "desc": "RESTORES 15 EN TO ONE ALLY."},
	"grenade": {"name": "PLASMA GRENADE", "count": 2, "target": "all_enemies", "effect": "magic", "power": 24,
		"fx": "grenade", "sfx": "grenade", "desc": "ABOUT 24 DAMAGE TO ALL ENEMIES."},
	"duck": {"name": "RUBBER DUCK", "count": 1, "target": "none", "effect": "duck",
		"fx": "", "sfx": "duck_squeak", "desc": "IT SQUEAKS. THAT'S IT. THAT'S THE ITEM."},
}
const ITEM_ORDER := ["burrito", "nano_gel", "energy_cell", "grenade", "duck"]

# Enemy move kinds: attack | attack_all | drain_en | heal_self | nothing
# w = how likely the move is (weight). stun = chance to stun the target.
const ENEMIES := {
	"gloop": {"name": "GLOOP DRONE", "hp": 34, "atk": 11, "def": 4, "spd": 8, "exp": 12, "moves": [
		{"kind": "attack", "mult": 1.0, "w": 5, "text": "{e} BONKS {t} WITH ITS DOME!"},
		{"kind": "attack", "mult": 0.7, "w": 3, "text": "{e} DRIPS GOO ON {t}. GROSS!"},
		{"kind": "nothing", "w": 2, "text": "{e} IS HUMMING A LITTLE TUNE."},
	]},
	"moth": {"name": "VOID MOTH", "hp": 26, "atk": 12, "def": 2, "spd": 15, "exp": 10, "moves": [
		{"kind": "attack", "mult": 1.0, "w": 4, "text": "{e} FLUTTERS INTO {t}!"},
		{"kind": "attack_all", "mult": 0.6, "w": 3, "text": "{e} SCATTERS COSMIC DUST!"},
		{"kind": "nothing", "w": 2, "text": "{e} IS DISTRACTED BY THE HUD LIGHTS."},
	]},
	"slug": {"name": "CHROME SLUG", "hp": 48, "atk": 10, "def": 9, "spd": 3, "exp": 15, "moves": [
		{"kind": "attack", "mult": 1.2, "w": 4, "text": "{e} SLIME-TACKLES {t}!"},
		{"kind": "nothing", "w": 3, "text": "{e} LEAVES A SHINY TRAIL. IT'S KIND OF PRETTY."},
		{"kind": "heal_self", "amount": 12, "w": 2, "text": "{e} POLISHES ITSELF. (+12 HP)"},
	]},
	"securi": {"name": "SECURI-BOT", "hp": 40, "atk": 13, "def": 6, "spd": 9, "exp": 18, "moves": [
		{"kind": "attack", "mult": 1.0, "stun": 0.3, "w": 4, "text": "{e} FIRES A TASER AT {t}!"},
		{"kind": "attack", "mult": 1.4, "w": 2, "text": "{e} APPLIES THE BATON OF JUSTICE TO {t}!"},
		{"kind": "nothing", "w": 2, "text": "{e} DEMANDS TO SEE YOUR PARKING PERMIT."},
	]},
	"overmind": {"name": "OVERMIND.EXE", "hp": 240, "atk": 15, "def": 7, "spd": 11, "exp": 500, "boss": true, "moves": [
		{"kind": "attack", "mult": 1.3, "w": 4, "text": "{e} FIRES A DATA BEAM AT {t}!"},
		{"kind": "attack_all", "mult": 0.8, "w": 3, "text": "{e} RUNS SYSTEM_PURGE.BAT!"},
		{"kind": "drain_en", "amount": 6, "w": 2, "text": "{e} DOWNLOADS {t}'S THOUGHTS!"},
		{"kind": "nothing", "w": 1, "text": "{e} STARES INTO YOUR SOUL."},
	], "moves_phase2": [
		{"kind": "attack", "mult": 1.3, "w": 3, "text": "{e} FIRES A DATA BEAM AT {t}!"},
		{"kind": "attack_all", "mult": 1.0, "w": 3, "text": "{e} UNLEASHES THE BLUE SCREEN OF DEATH!"},
		{"kind": "attack", "mult": 1.1, "stun": 0.4, "w": 2, "text": "{e} FIRES FREEZE.EXE AT {t}!"},
		{"kind": "heal_self", "amount": 25, "w": 1, "text": "{e} DEFRAGMENTS ITSELF. (+25 HP)"},
	]},
}

const ENCOUNTERS := [
	["gloop", "gloop"],
	["moth", "gloop", "moth"],
	["slug", "securi"],
	["securi", "moth"],
	["gloop", "slug", "moth"],
]

const VICTORY_FLUFF := [
	"{a}'S FUNK LEVEL WENT UP BY 1!",
	"{a} LEARNED TO WHISTLE IN ZERO-G!",
	"{a}'S GROOVE BECAME 3% SMOOTHER!",
	"{a} FOUND A COOL ROCK.",
]
