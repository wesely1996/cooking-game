class_name ShiftRules
extends RefCounted
## Base class for the per-level-type rules: when customers arrive, how
## serving is scored and when the shift ends. Rules never keep a reference to
## the Shift; it is passed to every call.

## Share of a dish's price paid as a tip when served instantly.
const TIP_SHARE := 0.5
const PERFECT_BONUS := 5
## Each serve in a row without losing a customer adds this much to the
## multiplier, up to COMBO_MAX steps.
const COMBO_STEP := 0.1
const COMBO_MAX := 10


static func create(type: String) -> ShiftRules:
	match type:
		LevelDef.TYPE_FESTIVAL:
			return FestivalRules.new()
		LevelDef.TYPE_COMPETITION:
			return CompetitionRules.new()
		LevelDef.TYPE_ARCADE:
			return ArcadeRules.new()
	return NormalRules.new()


func setup(_shift: Shift) -> void:
	pass


func tick(_shift: Shift, _delta: float) -> void:
	pass


## Returns the points for a served order.
func on_served(shift: Shift, order: Dictionary, item: KitchenItem) -> int:
	return serve_points(shift, order, item, true, true)


func on_lost(_shift: Shift, _order: Dictionary) -> void:
	pass


func is_finished(_shift: Shift) -> bool:
	return false


func outcome(_shift: Shift) -> Dictionary:
	return {}


## Price, plus a tip for speed, a bonus for perfect cooking, and the combo
## multiplier.
static func serve_points(shift: Shift, order: Dictionary, item: KitchenItem, with_tip: bool, with_combo: bool) -> int:
	var price := float(shift.db.items[order.dish].price)
	var points := price
	if with_tip:
		points += price * TIP_SHARE * OrderBook.patience_fraction(order)
	if item.perfect:
		points += PERFECT_BONUS
	if with_combo:
		shift.combo += 1
		points *= 1.0 + COMBO_STEP * mini(shift.combo - 1, COMBO_MAX)
	return roundi(points)


## Number of thresholds reached (0-3).
static func stars_for(value: float, thresholds: Array) -> int:
	var stars := 0
	for threshold in thresholds:
		if value >= float(threshold):
			stars += 1
	return stars
