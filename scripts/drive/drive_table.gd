## Medal pars for SUMMIT and GAUNTLET levels ([gold, silver] seconds) and the bikes
## the checker got through each level. Written by the level checker (README, Dev checks):
##   godot --headless --path . -- --drive-levels --write             (pars, on the scrambler)
##   godot --headless --path . -- --drive-levels --bikes=all --beam=12 --write  (the lists)
extends RefCounted

const PARS := {
	"ga_crates": [20, 25],
	"ga_final": [36, 46],
	"ga_firstgear": [19, 23],
	"ga_gaps": [19, 23],
	"ga_hoist": [43, 54],
	"ga_hoodoo": [27, 34],
	"ga_lamplight": [24, 30],
	"ga_launch": [22, 27],
	"ga_pipes": [24, 31],
	"ga_quarry": [24, 30],
	"ga_switchback": [18, 22],
	"ga_woodpile": [21, 27],
	"su_farm": [41, 52],
	"su_hoodoo": [66, 83],
	"su_mesa": [62, 79],
	"su_mine": [116, 146],
	"su_night": [78, 98],
	"su_orchard": [60, 76],
	"su_pines": [59, 74],
	"su_quarry": [88, 111],
	"su_railbed": [71, 89],
	"su_redrock": [51, 64],
	"su_rocket": [88, 111],
	"su_summit": [94, 119],
}

const RIDEABLE := {
	"ga_crates": ["scrambler", "commuter", "spark", "boulder", "surge", "dirt", "chopper", "sport"],
	"ga_final": ["scrambler", "surge"],
	"ga_firstgear": ["scrambler", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "zip", "commuter", "spark", "boulder", "mono", "surge", "goliath"],
	"ga_gaps": ["scrambler", "spark", "surge", "dirt", "cafe", "chopper", "sport"],
	"ga_hoist": ["scrambler", "spark", "surge", "dirt", "cafe"],
	"ga_hoodoo": ["scrambler", "spark", "dirt", "cafe", "sport"],
	"ga_lamplight": ["scrambler", "spark", "surge", "dirt", "cafe", "sport"],
	"ga_launch": ["scrambler", "spark", "surge", "dirt", "cafe", "chopper", "sport"],
	"ga_pipes": ["scrambler", "spark", "boulder", "dirt", "sport"],
	"ga_quarry": ["scrambler", "spark", "surge", "dirt", "cafe", "sport"],
	"ga_switchback": ["scrambler", "commuter", "spark", "boulder", "mono", "surge", "goliath", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "zip"],
	"ga_woodpile": ["scrambler", "spark", "boulder", "surge", "dirt", "minibike", "cafe", "sport", "zip"],
	"su_farm": ["scrambler", "commuter", "spark", "boulder", "mono", "surge", "goliath", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "zip"],
	"su_hoodoo": ["scrambler", "spark", "boulder", "surge", "goliath", "dirt", "cafe", "chopper", "sport"],
	"su_mesa": ["scrambler", "commuter", "spark", "boulder", "goliath", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "zip"],
	"su_mine": ["scrambler", "surge", "dirt"],
	"su_night": ["scrambler", "spark", "surge", "dirt", "cafe", "chopper", "sport"],
	"su_orchard": ["scrambler", "spark", "boulder", "mono", "surge", "goliath", "dirt", "cafe", "chopper", "sport"],
	"su_pines": ["scrambler", "commuter", "spark", "boulder", "mono", "surge", "goliath", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "zip"],
	"su_quarry": ["scrambler", "spark", "boulder", "surge", "dirt", "cafe", "chopper"],
	"su_railbed": ["scrambler", "spark", "boulder", "surge", "dirt", "cafe", "chopper", "sport"],
	"su_redrock": ["scrambler", "commuter", "spark", "boulder", "mono", "surge", "goliath", "dirt", "minibike", "scooter", "cafe", "chopper", "sport", "zip"],
	"su_rocket": ["scrambler", "spark", "surge", "dirt", "cafe", "chopper", "sport"],
	"su_summit": ["scrambler", "spark", "surge", "dirt", "cafe", "chopper", "sport"],
}
