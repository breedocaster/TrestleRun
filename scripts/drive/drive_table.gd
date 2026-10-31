## Medal pars for SUMMIT and GAUNTLET levels ([gold, silver] seconds) and the bikes
## the checker got through each level. Written by the level checker (README, Dev checks):
##   godot --headless --path . -- --drive-levels --write             (pars, on the scrambler)
##   godot --headless --path . -- --drive-levels --bikes=all --beam=12 --write  (the lists)
extends RefCounted

const PARS := {
	"ga_crates": [26, 33],
	"ga_final": [33, 42],
	"ga_firstgear": [19, 24],
	"ga_gaps": [19, 23],
	"ga_hoist": [22, 27],
	"ga_hoodoo": [29, 36],
	"ga_lamplight": [26, 33],
	"ga_launch": [31, 40],
	"ga_pipes": [36, 45],
	"ga_quarry": [23, 28],
	"ga_switchback": [20, 25],
	"ga_woodpile": [22, 28],
	"su_farm": [41, 52],
	"su_hoodoo": [63, 80],
	"su_mesa": [61, 77],
	"su_mine": [99, 124],
	"su_night": [76, 96],
	"su_orchard": [59, 74],
	"su_pines": [59, 74],
	"su_quarry": [81, 102],
	"su_railbed": [70, 88],
	"su_redrock": [49, 62],
	"su_rocket": [82, 104],
	"su_summit": [88, 111],
}

const RIDEABLE := {
	"ga_crates": ["scrambler", "dirt", "cafe", "chopper", "sport", "surge", "boulder"],
	"ga_final": ["scrambler", "sport", "surge"],
	"ga_firstgear": ["scrambler", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "spark", "surge", "zip", "commuter", "boulder", "mono", "goliath"],
	"ga_gaps": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge"],
	"ga_hoist": ["scrambler", "dirt", "chopper", "sport"],
	"ga_hoodoo": ["scrambler", "dirt", "cafe", "chopper", "sport"],
	"ga_lamplight": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "boulder"],
	"ga_launch": ["scrambler", "dirt", "minibike", "cafe", "chopper", "sport", "spark", "surge", "commuter", "boulder"],
	"ga_pipes": ["scrambler", "dirt"],
	"ga_quarry": ["scrambler", "dirt", "cafe", "sport", "spark", "surge"],
	"ga_switchback": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "boulder", "mono", "goliath"],
	"ga_woodpile": ["scrambler", "dirt", "sport", "spark", "surge"],
	"su_farm": ["scrambler", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "spark", "surge", "zip", "commuter", "boulder", "mono", "goliath"],
	"su_hoodoo": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "boulder", "mono"],
	"su_mesa": ["scrambler", "dirt", "scooter", "cafe", "chopper", "sport", "spark", "surge", "commuter", "boulder", "mono", "goliath"],
	"su_mine": ["scrambler", "dirt", "cafe", "sport", "spark", "surge"],
	"su_night": ["scrambler", "dirt", "cafe", "spark", "surge", "goliath"],
	"su_orchard": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "boulder", "goliath"],
	"su_pines": ["scrambler", "dirt", "scooter", "cafe", "chopper", "spark", "surge", "boulder", "mono", "goliath"],
	"su_quarry": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge"],
	"su_railbed": ["scrambler", "dirt", "scooter", "cafe", "chopper", "sport", "spark", "surge", "boulder", "mono"],
	"su_redrock": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "commuter", "boulder", "mono", "goliath"],
	"su_rocket": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge"],
	"su_summit": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "mono"],
}
