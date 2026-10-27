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
	"su_hoodoo": [67, 85],
	"su_mesa": [63, 80],
	"su_mine": [110, 138],
	"su_night": [80, 100],
	"su_orchard": [62, 78],
	"su_pines": [61, 77],
	"su_quarry": [88, 110],
	"su_railbed": [72, 91],
	"su_redrock": [54, 67],
	"su_rocket": [87, 110],
	"su_summit": [91, 115],
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
	"ga_switchback": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "boulder", "goliath"],
	"ga_woodpile": ["scrambler", "dirt", "sport", "spark", "surge"],
	"su_farm": ["scrambler", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "spark", "surge", "zip", "commuter", "boulder", "mono", "goliath"],
	"su_hoodoo": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "goliath"],
	"su_mesa": ["scrambler", "dirt", "scooter", "cafe", "chopper", "sport", "spark", "surge", "commuter", "boulder"],
	"su_mine": ["scrambler", "dirt", "sport", "spark", "surge"],
	"su_night": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "goliath"],
	"su_orchard": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "mono"],
	"su_pines": ["scrambler", "dirt", "scooter", "cafe", "chopper", "sport", "spark", "surge", "boulder", "mono", "goliath"],
	"su_quarry": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "mono"],
	"su_railbed": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "mono", "goliath"],
	"su_redrock": ["scrambler", "dirt", "scooter", "cafe", "chopper", "sport", "spark", "surge", "boulder", "mono", "goliath"],
	"su_rocket": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "mono", "goliath"],
	"su_summit": ["scrambler", "dirt", "cafe", "chopper", "sport", "spark", "surge", "mono", "goliath"],
}
