-- Kurze, waagerechte Bewegungsimpulse (Rückstoß, Ausweichschritt) über LinearVelocity.
-- Wird dort ausgeführt, wo die Physik des Körpers simuliert wird: Server für NPCs,
-- Client für den eigenen Charakter. Die Schwerkraft bleibt unberührt (nur X/Z begrenzt).

local Motion = {}

local PUSH_NAME = "ABX_Push"

function Motion.push(root: BasePart, velocity: Vector3, duration: number)
	if not root.Parent then
		return
	end
	local old = root:FindFirstChild(PUSH_NAME)
	if old then
		old:Destroy()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = PUSH_NAME
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	local force = math.max(root.AssemblyMass, 1) * 3000
	lv.MaxAxesForce = Vector3.new(force, 0, force)
	lv.VectorVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	lv.Parent = attachment
	attachment.Parent = root
	task.delay(duration, function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

function Motion.clear(root: BasePart)
	local old = root:FindFirstChild(PUSH_NAME)
	if old then
		old:Destroy()
	end
end

return Motion
