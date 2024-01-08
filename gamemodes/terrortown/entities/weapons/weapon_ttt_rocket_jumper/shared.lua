---- Rocket Jumper SWEP

-- First some standard GMod stuff
if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/rocketjumper_icon.vmt")
end

-- Equipment menu information is only needed on the client
if CLIENT then

	-- Text shown in the equip menu
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "Rocket Jumper",
		desc = "LMB: Launch into the air\nLMB again: Melee another player while midair to CRIT",
	}

	-- Path to the icon material
	SWEP.Icon = "vgui/ttt/rocketjumper_icon.vtf"

	SWEP.PrintName = "Rocket Jumper"
	SWEP.Instructions = "LMB off the ground, melee another player while midair to CRIT"

	SWEP.ViewModelFOV  = 65
	SWEP.ViewModelFlip = false

	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
end




-- Always derive from weapon_tttbase.
SWEP.Base				 = "weapon_tttbase"

--- Standard GMod values

SWEP.HoldType			 = "rpg"

SWEP.Primary.Delay       = 0.08
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"
SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1


SWEP.ViewModel  = "models/weapons/v_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"

local shootSound = Sound( "Weapon_Crossbow.Single" )

--- Parameters
local thrustSpeed = 1000
local traceRange = 200

-- Make sure these two are equal to their lua-filenames
local jumperWeaponString = "weapon_ttt_rocket_jumper"
local meleeWeaponString = "weapon_ttt_market_gardener"


--- TTT config values

-- Kind specifies the category this weapon is in. Players can only carry one of
-- each. Can be: WEAPON_... MELEE, PISTOL, HEAVY, NADE, CARRY, EQUIP1, EQUIP2 or ROLE.
-- Matching SWEP.Slot values: 0      1       2     3      4      6       7        8
SWEP.Kind = WEAPON_EQUIP1

-- If AutoSpawnable is true and SWEP.Kind is not WEAPON_EQUIP1/2, then this gun can
-- be spawned as a random weapon.
SWEP.AutoSpawnable = false

-- CanBuy is a table of ROLE_* entries like ROLE_TRAITOR and ROLE_DETECTIVE. If
-- a role is in this table, those players can buy this.
SWEP.CanBuy = { ROLE_TRAITOR }

-- InLoadoutFor is a table of ROLE_* entries that specifies which roles should
-- receive this weapon as soon as the round starts. In this case, none.
SWEP.InLoadoutFor = nil

-- If LimitedStock is true, you can only buy one per round.
SWEP.LimitedStock = true

-- If AllowDrop is false, players can't manually drop the gun with Q
SWEP.AllowDrop = true

-- If IsSilent is true, victims will not scream upon death.
SWEP.IsSilent = false

-- If NoSights is true, the weapon won't have ironsights
SWEP.NoSights = true

-- other SWEPs
SWEP.UseHands = true
SWEP.Weight = 5
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.Spawnable = false
SWEP.AdminSpawnable = true
SWEP.ShouldDropOnDie = true

local function GetAimedAtVector(ply)
	local worldShootPos = ply:GetShootPos()
	local viewTargetPos = ply:GetAimVector() * traceRange
	local tr = util.TraceLine({
		start = worldShootPos,
		endpos = worldShootPos + viewTargetPos,
		filter = ply,
		mask = MASK_NPCSOLID_BRUSHONLY
	})
	local world_target_pos = worldShootPos + tr.Fraction * viewTargetPos
	return world_target_pos, tr.Fraction < 1
end

local function spawnExplosion(explosionLocation)
	local exp = ents.Create( "env_explosion" )
	exp:SetPos( explosionLocation )
	exp:Spawn()
	exp:SetKeyValue( "iMagnitude", "0" )
	exp:Fire( "Explode", 0, 0 )
end

local function HotswapWeapons(ply, old, new)
	ply:StripWeapon(old)
	ply:Give(new)
end

local function IsJumping(ply)
	return IsValid(ply) and ply:IsPlayer() and (ply:HasWeapon(meleeWeaponString) or ply:HasWeapon(jumperWeaponString))
end

function SWEP:PrimaryAttack()
	if CLIENT then return end
	local ply = self:GetOwner()

	local world_target_pos, is_in_range = GetAimedAtVector(ply)

	if is_in_range then
		ply:SetVelocity(-ply:GetAimVector() * thrustSpeed)

		spawnExplosion(world_target_pos)

		self:SendWeaponAnim(ACT_RANGE_ATTACK_RPG)
		ply:SetAnimation(PLAYER_ATTACK1)
		self:EmitSound(shootSound)

		self:SetNextPrimaryFire( CurTime() + self:SequenceDuration() + 0.1)

		HotswapWeapons(ply, jumperWeaponString, meleeWeaponString)
	end
end

function SWEP:Equip(newOwner)
	newOwner:SelectWeapon(jumperWeaponString)
end

hook.Add("EntityTakeDamage", "rocket_jumper__NoFallDamage", function (target, dmgInfo)
	local inflictor = dmgInfo:GetInflictor()

	if (IsJumping(target) and dmgInfo:IsFallDamage())
	or (IsJumping(inflictor) and dmgInfo:IsDamageType(DMG_CRUSH)) then
		dmgInfo:SetDamage(0)
	end
end)