class_name Controls
extends RefCounted

const PADS: Dictionary = {"interact":JOY_BUTTON_A, "inventory":JOY_BUTTON_Y, "skills":JOY_BUTTON_BACK, "pause":JOY_BUTTON_START, "hp_potion":JOY_BUTTON_DPAD_LEFT, "mp_potion":JOY_BUTTON_DPAD_RIGHT, "portal":JOY_BUTTON_DPAD_DOWN, "secondary_0":JOY_BUTTON_LEFT_SHOULDER, "secondary_1":JOY_BUTTON_RIGHT_SHOULDER, "secondary_2":JOY_BUTTON_X, "cycle_spell":JOY_BUTTON_B, "map":JOY_BUTTON_DPAD_UP}
const KEYS: Dictionary = {"fire":[KEY_SPACE],"move_left":[KEY_A,KEY_Q,KEY_LEFT], "move_right":[KEY_D,KEY_RIGHT], "move_up":[KEY_W,KEY_Z,KEY_UP], "move_down":[KEY_S,KEY_DOWN], "interact":[KEY_E], "inventory":[KEY_I], "skills":[KEY_K], "portal":[KEY_T], "hp_potion":[KEY_R], "mp_potion":[KEY_F], "secondary_0":[KEY_1], "secondary_1":[KEY_2], "secondary_2":[KEY_3], "cycle_spell":[KEY_TAB], "pause":[KEY_ESCAPE], "map":[KEY_M]}
const LABELS: Dictionary = {"fire":"Tirer (souris ou clavier)","move_left":"Gauche", "move_right":"Droite", "move_up":"Haut", "move_down":"Bas", "interact":"Interagir", "inventory":"Inventaire", "skills":"Grimoire", "portal":"Portail du village", "hp_potion":"Potion de vie", "mp_potion":"Potion de mana", "secondary_0":"Rituel 1", "secondary_1":"Rituel 2", "secondary_2":"Rituel 3", "cycle_spell":"Changer de magie", "pause":"Pause", "map":"Carte"}

static func setup(bindings: Dictionary = {}, pad_bindings: Dictionary = {}) -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var codes: Array = [int(bindings[action])] if bindings.has(action) else KEYS[action]
		for code: int in codes:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mouse)
	var pads: Dictionary = PADS.duplicate()
	pads.merge(pad_bindings,true)
	for action: String in pads:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = pads[action]
		InputMap.action_add_event(action, event)

static func caption(action: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return action
