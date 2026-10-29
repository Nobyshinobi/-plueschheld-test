-- Posen und Zeitachsen für alle Kampfaktionen.
-- Dieselben Daten treiben (a) die prozeduralen Motor6D-Animationen im Client (PoseDriver) und
-- (b) das Studio-Werkzeug 04, das daraus KeyframeSequences für den Animation Editor erzeugt.
--
-- Winkel in Grad im Koordinatensystem des Elternteils am Gelenk (Figur blickt nach -Z):
--   rx > 0  Gliedmaße nach vorne heben (Arme/Beine) · Oberkörper/Kopf nach hinten neigen
--   ry > 0  Drehung gegen den Uhrzeigersinn von oben (rechte Schulter nach vorne)
--   rz > 0  rechter Arm/Bein nach außen · Oberkörper nach links neigen
--   rx am Ellbogen > 0 = beugen, am Knie < 0 = beugen
-- px/py/pz: Verschiebung (nur Root), in "halben Rumpfhöhen" – wird mit der Figurgröße skaliert.

local Poses = {}

export type JointPose = { rx: number?, ry: number?, rz: number?, px: number?, py: number?, pz: number? }
export type Pose = { [string]: JointPose }
export type Key = { t: number, pose: string, ease: string? }

Poses.JointOrder = {
	"Root",
	"Waist",
	"Neck",
	"RShoulder",
	"RElbow",
	"RWrist",
	"LShoulder",
	"LElbow",
	"LWrist",
	"RHip",
	"RKnee",
	"RAnkle",
	"LHip",
	"LKnee",
	"LAnkle",
}

-- Gelenk → {Teil, Motor6D} für R15 und R6.
Poses.R15 = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	RWrist = { "RightHand", "RightWrist" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	LWrist = { "LeftHand", "LeftWrist" },
	RHip = { "RightUpperLeg", "RightHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	RAnkle = { "RightFoot", "RightAnkle" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
	LAnkle = { "LeftFoot", "LeftAnkle" },
}

Poses.R6 = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	RShoulder = { "Torso", "Right Shoulder" },
	LShoulder = { "Torso", "Left Shoulder" },
	RHip = { "Torso", "Right Hip" },
	LHip = { "Torso", "Left Hip" },
}
-- R6 hat keine Ellbogen/Taille: Anteil, mit dem Ellbogen in die Schulter und Taille in Root einfließen.
Poses.R6ElbowFold = 0.35
Poses.R6WaistFold = 0.6

-- Gelenke, die zum Unterkörper zählen (werden im Stand vom normalen Lauf-Animate-Skript bewegt).
Poses.LegJoints = { Root = true, RHip = true, RKnee = true, RAnkle = true, LHip = true, LKnee = true, LAnkle = true }

Poses.Library = {
	Guard = {
		Root = { py = -0.12 },
		Waist = { rx = -6, ry = -12 },
		Neck = { rx = -8, ry = 9 },
		RShoulder = { rx = 55, ry = 22, rz = 12 },
		RElbow = { rx = 120 },
		LShoulder = { rx = 70, ry = -15, rz = -12 },
		LElbow = { rx = 100 },
		RHip = { rx = -8 },
		RKnee = { rx = -16 },
		RAnkle = { rx = 8 },
		LHip = { rx = 14 },
		LKnee = { rx = -14 },
		LAnkle = { rx = 2 },
	},
	Jab = {
		Root = { py = -0.12, pz = -0.15 },
		Waist = { rx = -9, ry = -26 },
		Neck = { rx = -10, ry = 18 },
		RShoulder = { rx = 58, ry = 24, rz = 12 },
		RElbow = { rx = 122 },
		LShoulder = { rx = 92, ry = -6, rz = -4 },
		LElbow = { rx = 6 },
		RHip = { rx = -12 },
		RKnee = { rx = -12 },
		LHip = { rx = 18 },
		LKnee = { rx = -18 },
	},
	HeavyWindup = {
		Root = { py = -0.2, pz = 0.12 },
		Waist = { rx = -3, ry = -30 },
		Neck = { rx = -8, ry = 22 },
		RShoulder = { rx = 38, ry = 8, rz = 20 },
		RElbow = { rx = 135 },
		LShoulder = { rx = 72, ry = -18, rz = -10 },
		LElbow = { rx = 105 },
		RHip = { rx = -14 },
		RKnee = { rx = -24 },
		LHip = { rx = 16 },
		LKnee = { rx = -20 },
	},
	HeavyStrike = {
		Root = { py = -0.22, pz = -0.35 },
		Waist = { rx = -13, ry = 34 },
		Neck = { rx = -10, ry = -20 },
		RShoulder = { rx = 93, ry = 12, rz = 2 },
		RElbow = { rx = 6 },
		LShoulder = { rx = 60, ry = -24, rz = -10 },
		LElbow = { rx = 125 },
		RHip = { rx = -4 },
		RKnee = { rx = -6 },
		RAnkle = { rx = -10 },
		LHip = { rx = 24 },
		LKnee = { rx = -26 },
	},
	SpecialWindup = {
		Root = { py = -0.6, pz = 0.1 },
		Waist = { rx = -22, ry = -22 },
		Neck = { rx = 6, ry = 18 },
		RShoulder = { rx = 10, ry = 4, rz = 26 },
		RElbow = { rx = 95 },
		LShoulder = { rx = 70, ry = -20, rz = -14 },
		LElbow = { rx = 110 },
		RHip = { rx = 32 },
		RKnee = { rx = -52 },
		RAnkle = { rx = 18 },
		LHip = { rx = 36 },
		LKnee = { rx = -50 },
		LAnkle = { rx = 16 },
	},
	SpecialStrike = {
		Root = { py = 0.35, pz = -0.3 },
		Waist = { rx = 12, ry = 26 },
		Neck = { rx = 16, ry = -12 },
		RShoulder = { rx = 165, ry = 12, rz = 8 },
		RElbow = { rx = 38 },
		LShoulder = { rx = 40, ry = -10, rz = -30 },
		LElbow = { rx = 80 },
		RHip = { rx = -6 },
		RKnee = { rx = -4 },
		RAnkle = { rx = -20 },
		LHip = { rx = 10 },
		LKnee = { rx = -10 },
		LAnkle = { rx = -18 },
	},
	Block = {
		Root = { py = -0.3 },
		Waist = { rx = -12, ry = -4 },
		Neck = { rx = -16 },
		RShoulder = { rx = 86, ry = 30, rz = 6 },
		RElbow = { rx = 146 },
		LShoulder = { rx = 86, ry = -30, rz = -6 },
		LElbow = { rx = 146 },
		RHip = { rx = 10 },
		RKnee = { rx = -24 },
		RAnkle = { rx = 12 },
		LHip = { rx = 18 },
		LKnee = { rx = -22 },
		LAnkle = { rx = 6 },
	},
	Dodge = {
		Root = { py = -0.55 },
		Waist = { rx = -20, rz = 20 },
		Neck = { rx = -6, rz = -10 },
		RShoulder = { rx = 62, ry = 26, rz = 10 },
		RElbow = { rx = 130 },
		LShoulder = { rx = 66, ry = -24, rz = -10 },
		LElbow = { rx = 125 },
		RHip = { rx = 28, rz = 6 },
		RKnee = { rx = -46 },
		RAnkle = { rx = 18 },
		LHip = { rx = 30, rz = -6 },
		LKnee = { rx = -44 },
		LAnkle = { rx = 16 },
	},
	Hit = {
		Root = { py = -0.1, pz = 0.3 },
		Waist = { rx = 18, ry = 8 },
		Neck = { rx = 26, ry = -6 },
		RShoulder = { rx = 34, ry = 14, rz = 22 },
		RElbow = { rx = 85 },
		LShoulder = { rx = 30, ry = -10, rz = -24 },
		LElbow = { rx = 80 },
		RHip = { rx = -12 },
		RKnee = { rx = -10 },
		LHip = { rx = 6 },
		LKnee = { rx = -12 },
	},
	GuardBreak = {
		Root = { py = -0.05, pz = 0.25 },
		Waist = { rx = 16 },
		Neck = { rx = 18 },
		RShoulder = { rx = 42, rz = 58 },
		RElbow = { rx = 30 },
		LShoulder = { rx = 42, rz = -58 },
		LElbow = { rx = 30 },
		RHip = { rx = -8 },
		LHip = { rx = -4 },
	},
	KO = {
		Root = { py = -1.0, pz = 0.2 },
		Waist = { rx = -26, rz = 8 },
		Neck = { rx = -30, rz = 16 },
		RShoulder = { rx = 12, rz = 10 },
		RElbow = { rx = 22 },
		LShoulder = { rx = 14, rz = -10 },
		LElbow = { rx = 18 },
		RHip = { rx = 82 },
		RKnee = { rx = -98 },
		RAnkle = { rx = 20 },
		LHip = { rx = 18 },
		LKnee = { rx = -100 },
		LAnkle = { rx = -30 },
	},
	Victory = {
		Root = { py = 0.0 },
		Waist = { rx = 6, ry = 6 },
		Neck = { rx = 14 },
		RShoulder = { rx = 172, rz = 10 },
		RElbow = { rx = 14 },
		LShoulder = { rx = 58, ry = -10, rz = -42 },
		LElbow = { rx = 112 },
		RHip = { rx = -2 },
		LHip = { rx = 4 },
	},
	Taunt = {
		Root = { py = -0.1 },
		Waist = { rx = -4 },
		Neck = { rx = -4 },
		RShoulder = { rx = 74, ry = 36, rz = 4 },
		RElbow = { rx = 72 },
		LShoulder = { rx = 74, ry = -36, rz = -4 },
		LElbow = { rx = 72 },
		RHip = { rx = -4 },
		RKnee = { rx = -10 },
		LHip = { rx = 8 },
		LKnee = { rx = -10 },
	},
}

-- Gespiegelte Variante (links/rechts tauschen, Drehungen um Y/Z umkehren).
local MIRROR = {
	RShoulder = "LShoulder",
	LShoulder = "RShoulder",
	RElbow = "LElbow",
	LElbow = "RElbow",
	RWrist = "LWrist",
	LWrist = "RWrist",
	RHip = "LHip",
	LHip = "RHip",
	RKnee = "LKnee",
	LKnee = "RKnee",
	RAnkle = "LAnkle",
	LAnkle = "RAnkle",
}

function Poses.mirror(pose: Pose): Pose
	local out = {}
	for joint, jp in pose do
		local target = MIRROR[joint] or joint
		out[target] = {
			rx = jp.rx,
			ry = jp.ry and -jp.ry,
			rz = jp.rz and -jp.rz,
			px = jp.px and -jp.px,
			py = jp.py,
			pz = jp.pz,
		}
	end
	return out
end

Poses.Library.DodgeLeft = Poses.Library.Dodge
Poses.Library.DodgeRight = Poses.mirror(Poses.Library.Dodge)

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

Poses.Ease = {
	linear = function(x)
		return math.clamp(x, 0, 1)
	end,
	smooth = smoothstep,
	out = easeOut,
}

-- Zeitachse je Aktion. Zeiten für Angriffe stammen direkt aus Config.Attacks,
-- damit Treffermoment und ausgestreckte Faust exakt übereinstimmen.
function Poses.track(
	action: string,
	cfg,
	opts: { extraWindup: number?, dodgeSide: number?, duration: number? }?
): ({ Key }, boolean)
	local o = opts or {}
	if action == "Light" then
		local def = cfg.Attacks.Light
		local w = def.Windup + (o.extraWindup or 0)
		return {
			{ t = 0, pose = "Guard" },
			{ t = w, pose = "Jab", ease = "out" },
			{ t = w + def.Active, pose = "Jab" },
			{ t = w + def.Active + def.Recovery, pose = "Guard", ease = "smooth" },
		},
			false
	elseif action == "Heavy" then
		local def = cfg.Attacks.Heavy
		local w = def.Windup + (o.extraWindup or 0)
		return {
			{ t = 0, pose = "Guard" },
			{ t = w * 0.72, pose = "HeavyWindup", ease = "smooth" },
			{ t = w, pose = "HeavyStrike", ease = "out" },
			{ t = w + def.Active + 0.05, pose = "HeavyStrike" },
			{ t = w + def.Active + def.Recovery, pose = "Guard", ease = "smooth" },
		},
			false
	elseif action == "Special" then
		local def = cfg.Attacks.Special
		local w = def.Windup + (o.extraWindup or 0)
		return {
			{ t = 0, pose = "Guard" },
			{ t = w * 0.78, pose = "SpecialWindup", ease = "smooth" },
			{ t = w, pose = "SpecialStrike", ease = "out" },
			{ t = w + def.Active + 0.12, pose = "SpecialStrike" },
			{ t = w + def.Active + def.Recovery, pose = "Guard", ease = "smooth" },
		},
			false
	elseif action == "Dodge" then
		local d = cfg.Dodge.Duration
		local pose = if (o.dodgeSide or -1) > 0 then "DodgeRight" else "DodgeLeft"
		return {
			{ t = 0, pose = "Guard" },
			{ t = 0.1, pose = pose, ease = "out" },
			{ t = d - 0.1, pose = pose },
			{ t = d, pose = "Guard", ease = "smooth" },
		},
			false
	elseif action == "Hitstun" then
		local d = o.duration or cfg.Attacks.Light.Hitstun
		return {
			{ t = 0, pose = "Guard" },
			{ t = 0.06, pose = "Hit", ease = "out" },
			{ t = d * 0.6, pose = "Hit" },
			{ t = d, pose = "Guard", ease = "smooth" },
		},
			false
	elseif action == "GuardBreak" then
		local d = o.duration or cfg.Fighter.GuardBreakStun
		return {
			{ t = 0, pose = "Block" },
			{ t = 0.1, pose = "GuardBreak", ease = "out" },
			{ t = d * 0.75, pose = "GuardBreak" },
			{ t = d, pose = "Guard", ease = "smooth" },
		},
			false
	elseif action == "Block" then
		return { { t = 0, pose = "Guard" }, { t = 0.08, pose = "Block", ease = "out" } }, true
	elseif action == "KO" then
		return { { t = 0, pose = "Hit" }, { t = 0.12, pose = "Hit" }, { t = 0.55, pose = "KO", ease = "smooth" } }, true
	elseif action == "Victory" then
		return { { t = 0, pose = "Guard" }, { t = 0.35, pose = "Victory", ease = "out" } }, true
	elseif action == "Taunt" then
		return {
			{ t = 0, pose = "Guard" },
			{ t = 0.25, pose = "Taunt", ease = "out" },
			{ t = 0.6, pose = "Taunt" },
			{ t = 0.9, pose = "Guard", ease = "smooth" },
		},
			false
	end
	return { { t = 0, pose = "Guard" } }, true
end

-- Dauer einer Zeitachse.
function Poses.duration(keys: { Key }): number
	return keys[#keys].t
end

local function lerp(a: number?, b: number?, alpha: number): number?
	if a == nil and b == nil then
		return nil
	end
	local x = a or 0
	local y = b or 0
	return x + (y - x) * alpha
end

function Poses.blend(a: Pose, b: Pose, alpha: number): Pose
	local out = {}
	for _, joint in Poses.JointOrder do
		local ja = a[joint]
		local jb = b[joint]
		if ja or jb then
			ja = ja or {}
			jb = jb or {}
			out[joint] = {
				rx = lerp(ja.rx, jb.rx, alpha),
				ry = lerp(ja.ry, jb.ry, alpha),
				rz = lerp(ja.rz, jb.rz, alpha),
				px = lerp(ja.px, jb.px, alpha),
				py = lerp(ja.py, jb.py, alpha),
				pz = lerp(ja.pz, jb.pz, alpha),
			}
		end
	end
	return out
end

-- Pose zum Zeitpunkt t einer Zeitachse.
function Poses.sample(keys: { Key }, t: number): Pose
	local lib = Poses.Library
	if t <= keys[1].t or #keys == 1 then
		return lib[keys[1].pose]
	end
	for i = 2, #keys do
		local k = keys[i]
		if t <= k.t then
			local prev = keys[i - 1]
			local span = k.t - prev.t
			local alpha = if span > 0 then (t - prev.t) / span else 1
			local ease = Poses.Ease[k.ease or "linear"] or Poses.Ease.linear
			return Poses.blend(lib[prev.pose], lib[k.pose], ease(alpha))
		end
	end
	return lib[keys[#keys].pose]
end

-- Rotation (und bei Root Verschiebung) einer Gelenkpose im Elternraum.
function Poses.toCFrame(jp: JointPose, scale: number): CFrame
	local rot = CFrame.fromEulerAnglesYXZ(math.rad(jp.rx or 0), math.rad(jp.ry or 0), math.rad(jp.rz or 0))
	if jp.px or jp.py or jp.pz then
		return CFrame.new((jp.px or 0) * scale, (jp.py or 0) * scale, (jp.pz or 0) * scale) * rot
	end
	return rot
end

return Poses
