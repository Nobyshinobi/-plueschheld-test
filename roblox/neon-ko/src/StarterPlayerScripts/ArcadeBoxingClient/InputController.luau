-- Kampfeingaben für Tastatur/Maus und Gamepad. Bevorzugt das Input Action System
-- (InputContext/InputAction/InputBinding); falls es im Projekt nicht erstellt werden kann,
-- automatischer Rückfall auf ContextActionService. Touch läuft über die HUD-Buttons.
-- Alle Bindungen sind nur während des Kampfs aktiv und werden danach vollständig entfernt.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))

local InputController = {}

local ACTIONS = { "Light", "Heavy", "Block", "Dodge", "Special", "Skip", "Leave" }

local handler: ((string, boolean) -> ())? = nil
local backend: string? = nil
local context: Instance? = nil
local connections: { RBXScriptConnection } = {}
local boundCas: { string } = {}

local function dispatch(name: string, down: boolean)
	if handler then
		local ok, err = pcall(handler, name, down)
		if not ok then
			warn("[NEON K.O.] Eingabefehler:", err)
		end
	end
end

local function keysFor(name: string): { Enum.KeyCode }
	local list = {}
	for _, key in Config.Input.Keyboard[name] or {} do
		table.insert(list, key)
	end
	for _, key in Config.Input.Gamepad[name] or {} do
		table.insert(list, key)
	end
	return list
end

local function buildInputActionSystem(parent: Instance): boolean
	local ok, err = pcall(function()
		local ctx = Instance.new("InputContext")
		ctx.Name = "ABX_FightContext"
		ctx.Priority = Config.Input.Priority
		ctx.Sink = Config.Input.SinkDuringFight
		ctx.Enabled = false
		for _, name in ACTIONS do
			local action = Instance.new("InputAction")
			action.Name = "ABX_" .. name
			action.Type = Enum.InputActionType.Bool
			for index, key in keysFor(name) do
				local binding = Instance.new("InputBinding")
				binding.Name = name .. "_" .. index
				binding.KeyCode = key
				binding.Parent = action
			end
			action.Parent = ctx
			table.insert(
				connections,
				action.Pressed:Connect(function()
					dispatch(name, true)
				end)
			)
			table.insert(
				connections,
				action.Released:Connect(function()
					dispatch(name, false)
				end)
			)
		end
		ctx.Parent = parent
		context = ctx
	end)
	if not ok then
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		if context then
			context:Destroy()
			context = nil
		end
		warn("[NEON K.O.] Input Action System nicht verfügbar, nutze ContextActionService:", err)
	end
	return ok
end

local function toCasInput(key: Enum.KeyCode): Enum.KeyCode | Enum.UserInputType
	if key == Enum.KeyCode.MouseLeftButton then
		return Enum.UserInputType.MouseButton1
	elseif key == Enum.KeyCode.MouseRightButton then
		return Enum.UserInputType.MouseButton2
	end
	return key
end

local function bindCas()
	for _, name in ACTIONS do
		local inputs = {}
		for _, key in keysFor(name) do
			table.insert(inputs, toCasInput(key))
		end
		local actionName = "ABX_" .. name
		ContextActionService:BindActionAtPriority(actionName, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				dispatch(name, true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				dispatch(name, false)
			end
			return if Config.Input.SinkDuringFight then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
		end, false, Config.Input.Priority, table.unpack(inputs))
		table.insert(boundCas, actionName)
	end
end

-- Einmalig vorbereiten (Kontext bleibt deaktiviert, bis enable() aufgerufen wird).
function InputController.init(parent: Instance)
	if backend then
		return
	end
	if Config.Input.PreferInputActionSystem and buildInputActionSystem(parent) then
		backend = "InputActionSystem"
	else
		backend = "ContextActionService"
	end
end

function InputController.backend(): string?
	return backend
end

function InputController.enable(onInput: (string, boolean) -> ())
	handler = onInput
	if backend == "InputActionSystem" and context then
		(context :: any).Enabled = true
	elseif backend == "ContextActionService" then
		bindCas()
	end
end

function InputController.disable()
	handler = nil
	if context then
		(context :: any).Enabled = false
	end
	for _, actionName in boundCas do
		ContextActionService:UnbindAction(actionName)
	end
	table.clear(boundCas)
end

-- Bevorzugtes Eingabegerät für Hinweise und Touch-Buttons.
function InputController.preferred(): string
	local ok, value = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok and value == Enum.PreferredInput.Touch then
		return "Touch"
	elseif ok and value == Enum.PreferredInput.Gamepad then
		return "Gamepad"
	elseif ok and value == Enum.PreferredInput.KeyboardAndMouse then
		return "KeyboardAndMouse"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardAndMouse"
end

function InputController.onPreferredChanged(callback: (string) -> ()): RBXScriptConnection
	local ok, signal = pcall(function()
		return UserInputService:GetPropertyChangedSignal("PreferredInput")
	end)
	if ok and signal then
		return signal:Connect(function()
			callback(InputController.preferred())
		end)
	end
	return UserInputService.LastInputTypeChanged:Connect(function()
		callback(InputController.preferred())
	end)
end

return InputController
