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


local VM_JUMPER = 0
local VM_GARDEN = 1

-- Always derive from weapon_tttbase.
SWEP.Base				 = "weapon_tttbase"

--- Standard GMod values

SWEP.HoldType			 = "rpg"
SWEP.HoldType1			 = "melee"

SWEP.Primary.Delay       = 0.08
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"
SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1

SWEP.Primary.HitSound = Sound("Critical_Hit.mp3")
SWEP.Primary.MissSound = Sound("Weapon_Crowbar.Single")

SWEP.ViewModel  = "models/weapons/v_rpg.mdl"
SWEP.ViewModel0  = "models/weapons/v_rpg.mdl"
SWEP.ViewModel1  = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.WorldModel0 = "models/weapons/w_rocket_launcher.mdl"
SWEP.WorldModel1 = "models/weapons/w_crowbar.mdl"

local shootSound = Sound( "Weapon_Crossbow.Single" )

--- Parameters
local thrustSpeed = 1000
local traceRange = 200
-- gardener:
local hitboxRange = 120
local damageValue = 1000
local dropCheckInterval = 0.1
local meleeSwingDelay = 0.05
local swap_speed = 4
local deploy_urgency = 100
local gardenerExtents = 10
local meleeForce = 5
local deployLag = 3

-- Make sure these two are equal to their lua-filenames
local jumperWeaponString = "weapon_ttt_rocket_jumper"


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

local function IsJumping(ply)
	return IsValid(ply) and ply:IsPlayer() and ply:HasWeapon(jumperWeaponString)
end

function SWEP:SetupDataTables()
	self:NetworkVar( "Bool", 0, "IsJumper" )

	self:NetworkVarNotify( "IsJumper", self.JumperStateChange )
end

-- it's easier to latch this on the netvar so the client doesn't
-- trip over prediction a boatload
function SWEP:JumperStateChange( name, old, new )
	if new ~= self.lastJumperState then
		self.lastJumperState = new
		if CLIENT then
			if new then
				self:BecomeJumper()
			else
				self:BecomeGardener()
			end
		end
	end
end

function SWEP:Initialize()
	self:NextThink(CurTime() + dropCheckInterval)
	self:SetIsJumper(true)
	if CLIENT then
		self:RefreshTTT2HUDHelp()
	end
end

function SWEP:GetActiveViewModelIndex()
	return not self:GetIsJumper() and VM_GARDEN or VM_JUMPER
end

function SWEP:Equip(ply)
	ply:SelectWeapon(self:GetClass())
end

-- jumper attack
function SWEP:PrimaryAttack()
	-- if CLIENT and not IsFirstTimePredicted() then return end
	if self:GetIsJumper() then
		self:JumperFire()
	else
		self:GardenerSwing()
	end
end

function SWEP:Reload()
	if SERVER and not self:GetIsJumper() then
		self:BecomeJumper()
	end
end

function SWEP:JumperFire()
	local ply = self:GetOwner()

	local world_target_pos, is_in_range = GetAimedAtVector(ply)

	if is_in_range then
		if SERVER then
			ply:SetVelocity(-ply:GetAimVector() * thrustSpeed)

			spawnExplosion(world_target_pos)

			self:EmitSound(shootSound)

			self:BecomeGardener()
		end

		self:RemoveFlags( FL_ONGROUND )

		self:SendWeaponAnim(ACT_RANGE_ATTACK_RPG, VM_JUMPER )
		ply:SetAnimation(PLAYER_ATTACK1)
		self:SetNextPrimaryFire( CurTime() + self:SequenceDuration() + 0.1)

		local nextThink = CurTime() + dropCheckInterval
		self:NextThink(nextThink)
		if CLIENT then
			self:SetNextClientThink(nextThink)
		end
	end
end

function SWEP:GardenerSwing()
	local ply = self:GetOwner()

	ply:LagCompensation(true)

	local shootPos = ply:GetShootPos()
	local endShootPos = (ply:GetAimVector() * hitboxRange) + shootPos
	local tMin = Vector(1, 1, 1) * -gardenerExtents
	local tMax = Vector(1, 1, 1) * gardenerExtents

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
		self:SendViewModelAnim(ACT_VM_HITCENTER, VM_GARDEN)
		ply:SetAnimation(PLAYER_ATTACK1)

		if SERVER then
			timer.Simple(meleeSwingDelay, function ()
				local dmg = DamageInfo()
				dmg:SetDamage(damageValue)
				dmg:SetAttacker(ply)
				if IsValid(self) then dmg:SetInflictor(self) end
				dmg:SetDamageForce(ply:GetAimVector() * meleeForce)
				dmg:SetDamagePosition(ply:GetPos())
				dmg:SetDamageType(DMG_CLUB)

				hitEnt:TakeDamageInfo(dmg)
			end)
		end
		self:EmitSound(self.Primary.HitSound)

	elseif not IsValid(hitEnt) then
		self:SendViewModelAnim(ACT_VM_MISSCENTER, VM_GARDEN)
		ply:SetAnimation(PLAYER_ATTACK1)

		self:EmitSound(self.Primary.MissSound)
	end
	local delay = self:SequenceDuration()
	self:SetNextPrimaryFire(CurTime() + delay + 0.1)

	ply:LagCompensation(false)
end

function SWEP:BecomeGardener()
	if SERVER then
		self:SetIsJumper(false)
	end

	self:SetModel( self.WorldModel1 )
	self.WorldModel = self.WorldModel1
	self:SendViewModelAnim( ACT_VM_DRAW, VM_JUMPER, -swap_speed)
	self:SendViewModelAnim( ACT_VM_DRAW , VM_GARDEN, swap_speed)
	self:SetHoldType("melee")
	if CLIENT then
		self:RefreshTTT2HUDHelp()
	end
end

function SWEP:BecomeJumper()
	if SERVER then
		self:SetIsJumper(true)
	end

	self:SetModel( self.WorldModel0 )
	self.WorldModel = self.WorldModel0
	self:SendViewModelAnim( ACT_VM_HOLSTER, VM_GARDEN, swap_speed)
	self:SendViewModelAnim( ACT_VM_DRAW, VM_JUMPER, swap_speed)
	self:SetHoldType("rpg")
	if CLIENT then
		self:RefreshTTT2HUDHelp()
	end
end

function SWEP:Deploy()
	if SERVER and not self:GetIsJumper() then
		self:SetNextPrimaryFire(CurTime() + dropCheckInterval * deployLag)
	end

	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local vm1 = ply:GetViewModel( VM_GARDEN )
	if ( IsValid( vm1 ) ) then
		--associate its weapon to us
		vm1:SetWeaponModel( self.ViewModel1, self )
	end

	if self:GetIsJumper() then
		self:SendViewModelAnim( ACT_VM_HOLSTER, VM_GARDEN, swap_speed * deploy_urgency )
	else
		self:SendViewModelAnim( ACT_VM_DRAW, VM_JUMPER, -swap_speed * deploy_urgency )
	end

	return true
end

function SWEP:Holster()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local vm1 = ply:GetViewModel( VM_GARDEN )
	if ( IsValid( vm1 ) ) then
		--set its weapon to nil, this way the viewmodel won't show up again
		vm1:SetWeaponModel( self.ViewModel1 , nil )
	end

	return true
end

function SWEP:SendViewModelAnim( act , index , rate )
	if ( not game.SinglePlayer() and not IsFirstTimePredicted() ) then
		return
	end

	local vm = self:GetOwner():GetViewModel( index )

	if ( not IsValid( vm ) ) then
		return
	end

	local seq = vm:SelectWeightedSequence( act )

	if ( seq == -1 ) then
		return
	end

	vm:SendViewModelMatchingSequence( seq )
	vm:SetPlaybackRate( rate or 1 )
end

function SWEP:Think()
	local ply = self:GetOwner()
	if not self:GetIsJumper() then
		if IsValid(ply) and (ply:OnGround() or ply:WaterLevel() ~= 0) then
			if SERVER then
				self:BecomeJumper()
			end
		else
			local nextThink = CurTime() + dropCheckInterval
			self:NextThink(nextThink)
			if CLIENT then
				self:SetNextClientThink(nextThink)
			end
		end
	end
end

function SWEP:RefreshTTT2HUDHelp()
	self.HUDHelp = {
		bindingLines = {},
		max_length = 0
	}

	if not self:GetIsJumper() then
		self:AddHUDHelpLine("rocket_jumper_primary", Key("+attack", "MOUSE1"))
	else
		self:AddHUDHelpLine("market_gardener_primary", Key("+attack", "MOUSE1"))
		self:AddHUDHelpLine("market_gardener_cancel", Key("+reload", "R"))
	end
end

hook.Add("OnPlayerHitGround", "market_gardener__DropMeleeOnFall", function(ply, inWater, onFloater, speed)
	local wep = ply:GetActiveWeapon()
	if SERVER and IsValid(wep) and wep:GetClass() == jumperWeaponString and (not wep:GetIsJumper()) and ply:IsPlayer() then
		wep:BecomeJumper()
	end
end)

if SERVER then
	-- rocket jumper logic
	hook.Add("EntityTakeDamage", "rocket_jumper__NoFallDamage", function (target, dmgInfo)
		local inflictor = dmgInfo:GetInflictor()

		if (IsJumping(target) and dmgInfo:IsFallDamage())
		or (IsJumping(inflictor) and dmgInfo:IsDamageType(DMG_CRUSH)) then
			dmgInfo:SetDamage(0)
		end
	end)
end