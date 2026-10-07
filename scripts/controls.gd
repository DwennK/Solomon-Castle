class_name Controls
extends RefCounted

const PADS: Dictionary = {"interact":JOY_BUTTON_A, "inventory":JOY_BUTTON_Y, "skills":JOY_BUTTON_BACK, "pause":JOY_BUTTON_START, "hp_potion":JOY_BUTTON_DPAD_LEFT, "mp_potion":JOY_BUTTON_DPAD_RIGHT, "portal":JOY_BUTTON_DPAD_DOWN, "secondary_0":JOY_BUTTON_LEFT_SHOULDER, "secondary_1":JOY_BUTTON_RIGHT_SHOULDER, "secondary_2":JOY_BUTTON_X, "cycle_spell":JOY_BUTTON_B, "map":JOY_BUTTON_DPAD_UP}
const KEYS: Dictionary = {"fire":[KEY_SPACE],"move_left":[KEY_A,KEY_Q,KEY_LEFT], "move_right":[KEY_D,KEY_RIGHT], "move_up":[KEY_W,KEY_Z,KEY_UP], "move_down":[KEY_S,KEY_DOWN], "interact":[KEY_E], "inventory":[KEY_I], "skills":[KEY_K], "portal":[KEY_T], "hp_potion":[KEY_R], "mp_potion":[KEY_F], "secondary_0":[KEY_1], "secondary_1":[KEY_2], "secondary_2":[KEY_3], "cycle_spell":[KEY_TAB], "pause":[KEY_ESCAPE], "map":[KEY_M]}
const LABELS: Dictionary = {"fire":"Fire (mouse or keyboard)","move_left":"Left", "move_right":"Right", "move_up":"Up", "move_down":"Down", "interact":"Interact", "inventory":"Inventory", "skills":"Grimoire", "portal":"Village portal", "hp_potion":"Health potion", "mp_potion":"Mana potion", "secondary_0":"Ritual 1", "secondary_1":"Ritual 2", "secondary_2":"Ritual 3", "cycle_spell":"Switch magic", "pause":"Pause", "map":"Map"}

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

static var using_pad: bool = false
static var pad_device: int = 0
static var pad_name: String = ""

static func observe(event: InputEvent) -> void:
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y] and absf(event.axis_value)>(0.2 if event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] else 0.23)):
		using_pad = true
		pad_device = event.device
		pad_name = Input.get_joy_name(event.device)
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventMouseMotion and event.relative.length()>3):
		using_pad = false

static func disconnected(device: int, connected: bool) -> void:
	if not connected and device == pad_device: using_pad = false

static func pad_caption(code: int) -> String:
	var names: Dictionary = {JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y",JOY_BUTTON_BACK:"Select",JOY_BUTTON_START:"Start",JOY_BUTTON_LEFT_SHOULDER:"LB",JOY_BUTTON_RIGHT_SHOULDER:"RB",JOY_BUTTON_DPAD_UP:"↑",JOY_BUTTON_DPAD_DOWN:"↓",JOY_BUTTON_DPAD_LEFT:"←",JOY_BUTTON_DPAD_RIGHT:"→",JOY_BUTTON_LEFT_STICK:"L3",JOY_BUTTON_RIGHT_STICK:"R3",JOY_BUTTON_GUIDE:"Guide"}
	if "playstation" in pad_name.to_lower() or "dualshock" in pad_name.to_lower() or "dualsense" in pad_name.to_lower() or "ps4" in pad_name.to_lower() or "ps5" in pad_name.to_lower():
		names.merge({JOY_BUTTON_A:"×",JOY_BUTTON_B:"○",JOY_BUTTON_X:"□",JOY_BUTTON_Y:"△",JOY_BUTTON_LEFT_SHOULDER:"L1",JOY_BUTTON_RIGHT_SHOULDER:"R1",JOY_BUTTON_BACK:"Share",JOY_BUTTON_START:"Options"},true)
	return names.get(code,"Button %d" % code)

static func caption(action: String, keyboard_only: bool = false) -> String:
	if using_pad and not keyboard_only:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton: return pad_caption(event.button_index)
		if action == "fire": return "R Stick"
		if action.begins_with("move_"): return "L Stick"
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode).replace("Escape","Esc")
	return action
