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
 

SWEP.Primary.HitSound = Sound( "Critical_Hit.mp3" )
SWEP.Primary.MissSound = Sound( "Weapon_Crowbar.Single" ) 

 -- Make sure these two are equal to their lua-filenames
local jumper_weapon_string = "weapon_ttt_rocket_jumper"
local melee_weapon_string = "weapon_ttt_market_gardener"

--- Parameters
local hitbox_range = 120
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

    local shoot_pos = ply:GetShootPos()
    local end_shoot_pos = (ply:GetAimVector() * hitbox_range) + shoot_pos
    local t_min = Vector( 1, 1, 1 ) * -10
    local t_max = Vector( 1, 1, 1 ) * 10
    
    local tr = util.TraceHull( {
        start = shoot_pos,
        endpos = end_shoot_pos,
        filter = ply,
        mask = MASK_SHOT_HULL,
        mins = t_min,
        maxs = t_max
    } )

    if( not IsValid(tr.Entity)) then
        tr = util.TraceLine( {
        start = shoot_pos,
        endpos = end_shoot_pos,
        mask = MASK_SHOT_HULL,
        filter = ply
        } )
    end

    local ent = tr.Entity

    if(IsValid(ent) and (ent:IsPlayer() or ent:IsNPC())) then
        self.Weapon:SendWeaponAnim(ACT_VM_HITCENTER)
        ply:SetAnimation(PLAYER_ATTACK1)

        timer.Simple(meleeSwingDelay, function ()
            ent:SetHealth(ent:Health() - damageValue)
            if(ent:Health() < 1) then
            ent:Kill()
            end
        end)
        self:EmitSound(self.Primary.HitSound)

    elseif(not IsValid(ent)) then
        self.Weapon:SendWeaponAnim(ACT_VM_MISSCENTER)
        ply:SetAnimation(PLAYER_ATTACK1)

        self:EmitSound(self.Primary.MissSound)
    end
    local delay = self:SequenceDuration()
    self:SetNextPrimaryFire( CurTime() + delay + 0.1)

    ply:LagCompensation(false)
end

function SWEP:Equip(newOwner)
    newOwner:SelectWeapon(melee_weapon_string)
end

function SWEP:SetupDataTables()
	self:NetworkVar( "Float" , 0 , "NextDropCheck" )
end

function SWEP:Initialize()
	self:SetNextDropCheck( CurTime() + 0.1 )
  local owner = self:GetOwner()
    hook.Add("OnPlayerHitGround", "market_gardener__DropMeleeOnFall", function(ply, inWater, onFloater, speed)
        if CLIENT then return end
        if owner == ply then
            hook.Remove("OnPlayerHitGround", "market_gardener__DropMeleeOnFall")
            ply:StripWeapon(melee_weapon_string)
            ply:Give(jumper_weapon_string)
        end
    end)
    hook.Add("DoPlayerDeath", "market_gardener__DropMeleeOnDeath", function (ply, attacker, dmg)
      if CLIENT then return end
      if owner == ply then
        hook.Remove("DoPlayerDeath", "market_gardener__DropMeleeOnDeath")
        hook.Remove("OnPlayerHitGround", "market_gardener__DropMeleeOnFall")
        self:GetOwner():StripWeapon(melee_weapon_string)
      end
    end)
    hook.Add("PlayerSilentDeath", "market_gardener__DropMeleeOnSilentDeath", function (ply)
      if CLIENT then return end
      if owner == ply then
        hook.Remove("PlayerSilentDeath", "market_gardener__DropMeleeOnSilentDeath")
        hook.Remove("OnPlayerHitGround", "market_gardener__DropMeleeOnFall")
        owner:StripWeapon(melee_weapon_string)
      end
    end)
    hook.Add("TTTEndRound", "market_gardener__DropMeleeOnRoundEnd", function (result)
      if CLIENT then return end
      hook.Remove("TTTEndRound", "market_gardener__DropMeleeOnRoundEnd")
      hook.Remove("OnPlayerHitGround", "market_gardener__DropMeleeOnFall")
      owner:StripWeapon(melee_weapon_string)
    end)
end

function SWEP:Think()
    ShouldStripMelee(self, self:GetOwner())
end

function SWEP:Deploy()
    if SERVER then
        self:SetNextPrimaryFire(CurTime() + dropCheckInterval*3)
    end
end

function ShouldStripMelee(wep, ply)
    if SERVER and wep:GetNextDropCheck() < CurTime() then
        if ply:OnGround() or ply:WaterLevel() ~= 0 then
            ply:StripWeapon(melee_weapon_string)
            ply:Give(jumper_weapon_string)
        else
            wep:SetNextDropCheck(CurTime() + dropCheckInterval)
        end
    end
end




