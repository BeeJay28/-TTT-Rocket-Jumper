---- Market Gardener SWEP

--IMPORTANT: THIS WEAPON SHOULD ONLY BE GIVEN BY THE EFFECT OF THE ROCKET JUMPER. OTHERWISE THIS WEAPON WILL ACT BROKEN.

-- First some standard GMod stuff
if SERVER then
	AddCSLuaFile()
end

-- Equipment menu information is only needed on the client
if CLIENT then
	SWEP.PrintName = "Market Gardener"
	SWEP.Instructions = "Hit a player while airborne from the Rocket Jumper to CRIT"

	SWEP.ViewModelFOV  = 65
	SWEP.ViewModelFlip = false

	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
end




-- Always derive from weapon_tttbase.
SWEP.Base				= "weapon_tttbase"

--- Standard GMod values

SWEP.HoldType			= "melee"

SWEP.Primary.Delay       = 0.08
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"
SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1


SWEP.ViewModel  = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"


SWEP.Primary.HitSound = Sound("Critical_Hit.mp3")
SWEP.Primary.MissSound = Sound("Weapon_Crowbar.Single")

-- Make sure these two are equal to their lua-filenames
local jumperWeaponString = "weapon_ttt_rocket_jumper"
local meleeWeaponString = "weapon_ttt_market_gardener"

--- Parameters
local hitboxRange = 120
local damageValue = 1000
local dropCheckInterval = 0.1
local meleeSwingDelay = 0.05

--- TTT config values

-- Kind specifies the category this weapon is in. Players can only carry one of
-- each. Can be: WEAPON_... MELEE, PISTOL, HEAVY, NADE, CARRY, EQUIP1, EQUIP2 or ROLE.
-- Matching SWEP.Slot values: 0      1       2     3      4      6       7        8
SWEP.Kind = WEAPON_EQUIP1

-- If AutoSpawnable is true and SWEP.Kind is not WEAPON_EQUIP1/2, then this gun can
-- be spawned as a random weapon. Of course this AK is special equipment so it won't,
-- but for the sake of example this is explicitly set to false anyway.
SWEP.AutoSpawnable = false

-- The AmmoEnt is the ammo entity that can be picked up when carrying this gun.
--SWEP.AmmoEnt = "item_ammo_smg1_ttt"

-- CanBuy is a table of ROLE_* entries like ROLE_TRAITOR and ROLE_DETECTIVE. If
-- a role is in this table, those players can buy this.
SWEP.CanBuy = {}
-- InLoadoutFor is a table of ROLE_* entries that specifies which roles should
-- receive this weapon as soon as the round starts. In this case, none.
SWEP.InLoadoutFor = nil

-- If LimitedStock is true, you can only buy one per round.
SWEP.LimitedStock = false

-- If AllowDrop is false, players can't manually drop the gun with Q
SWEP.AllowDrop = false

-- If IsSilent is true, victims will not scream upon death.
SWEP.IsSilent = false

-- If NoSights is true, the weapon won't have ironsights
SWEP.NoSights = true

-- other SWEPs
SWEP.UseHands = true
SWEP.Weight = 127
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.Spawnable = false
SWEP.AdminSpawnable = false
SWEP.ShouldDropOnDie = false

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()

	ply:LagCompensation(true)

	local shootPos = ply:GetShootPos()
	local endShootPos = (ply:GetAimVector() * hitboxRange) + shootPos
	local tMin = Vector(1, 1, 1) * -10
	local tMax = Vector(1, 1, 1) * 10

	local tr = util.TraceHull({
		start = shootPos,
		endpos = endShootPos,
		filter = ply,
		mask = MASK_SHOT_HULL,
		mins = tMin,
		maxs = tMax
	})

	if not IsValid(tr.Entity) then
		tr = util.TraceLine({
		start = shootPos,
		endpos = endShootPos,
		mask = MASK_SHOT_HULL,
		filter = ply
		})
	end

	local hitEnt = tr.Entity

	if (IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC())) then
		self:SendWeaponAnim(ACT_VM_HITCENTER)
		ply:SetAnimation(PLAYER_ATTACK1)

		if SERVER then
			timer.Simple(meleeSwingDelay, function ()
				local dmg = DamageInfo()
				dmg:SetDamage(damageValue)
				dmg:SetAttacker(ply)
				if IsValid(self) then dmg:SetInflictor(self) end
				dmg:SetDamageForce(ply:GetAimVector() * 5)
				dmg:SetDamagePosition(ply:GetPos())
				dmg:SetDamageType(DMG_CLUB)

				hitEnt:TakeDamageInfo(dmg)
			end)
		end
		self:EmitSound(self.Primary.HitSound)

	elseif not IsValid(hitEnt) then
		self:SendWeaponAnim(ACT_VM_MISSCENTER)
		ply:SetAnimation(PLAYER_ATTACK1)

		self:EmitSound(self.Primary.MissSound)
	end
	local delay = self:SequenceDuration()
	self:SetNextPrimaryFire(CurTime() + delay + 0.1)

	ply:LagCompensation(false)
end

function SWEP:Equip(newOwner)
	newOwner:SelectWeapon(meleeWeaponString)
end

function SWEP:Initialize()
	self:NextThink(CurTime() + dropCheckInterval)
end

if SERVER then
	function SWEP:Think()
		local ply = self:GetOwner()
		if IsValid(ply) and ply:OnGround() or ply:WaterLevel() ~= 0 then
			ply:StripWeapon(meleeWeaponString)
			ply:Give(jumperWeaponString)
		else
			self:NextThink(CurTime() + dropCheckInterval)
		end
	end

	function SWEP:Deploy()
		self:SetNextPrimaryFire(CurTime() + dropCheckInterval * 3)
	end

	hook.Add("OnPlayerHitGround", "market_gardener__DropMeleeOnFall", function(ply, inWater, onFloater, speed)
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == meleeWeaponString and ply:IsPlayer() then
			ply:StripWeapon(meleeWeaponString)
			ply:Give(jumperWeaponString)
		end
	end)

	hook.Add("PlayerSilentDeath", "market_gardener__DropMeleeOnSilentDeath", function (ply)
		if ply:HasWeapon(jumperWeaponString) then
			ply:StripWeapon(meleeWeaponString)
		end
	end)

	hook.Add("DoPlayerDeath", "market_gardener__DropMeleeOnDeath", function (ply, attacker, dmg)
		if ply:HasWeapon(meleeWeaponString) then
			ply:StripWeapon(meleeWeaponString)
		end
	end)
end