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
SWEP.Base				= "weapon_tttbase"

--- Standard GMod values

SWEP.HoldType			= "rpg"

SWEP.Primary.Delay       = 0.08
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"
SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1


SWEP.ViewModel  = "models/weapons/v_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"

local shoot_sound = Sound( "Weapon_Crossbow.Single" )

--- Parameters
local thrust_speed = 1000
local trace_range = 200
local FallDamageDenyCheckInterval = 0.1

--- Helper variables
local ShouldDenyFallDamage = false
local CollisionDmgFlagId = 0

-- Make sure these two are equal to their lua-filenames
local jumper_weapon_string = "weapon_ttt_rocket_jumper"
local melee_weapon_string = "weapon_ttt_market_gardener"


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


function SWEP:PrimaryAttack()
	if CLIENT then return end

  local ply = self:GetOwner()

  local world_target_pos, is_in_range = GetAimedAtVector(ply)
  if(is_in_range) then
    ply:SetVelocity(-ply:GetAimVector() * thrust_speed)

    spawnExplosion(world_target_pos)

    self.Weapon:SendWeaponAnim(ACT_RANGE_ATTACK_RPG)
    ply:SetAnimation(PLAYER_ATTACK1)
    self.Weapon:EmitSound(shoot_sound)

    self:SetNextPrimaryFire( CurTime() + self:SequenceDuration() + 0.1)
    
    AddHooksForAttack(ply)
    ShouldDenyFallDamage = true

    HotswapWeapons(ply, jumper_weapon_string, melee_weapon_string)
  end
end 

function GetAimedAtVector(ply)
  local world_shoot_pos = ply:GetShootPos()
  local view_target_pos = ply:GetAimVector() * trace_range
  local tr = util.TraceLine( { 
    start = world_shoot_pos,
    endpos = world_shoot_pos + view_target_pos,
    filter = ply,
    mask = MASK_NPCSOLID_BRUSHONLY
  } )
  local world_target_pos = world_shoot_pos + tr.Fraction * view_target_pos
  return world_target_pos, tr.Fraction < 1
end

function spawnExplosion(explosionLocation)
  local exp = ents.Create( "env_explosion" )
  exp:SetPos( explosionLocation )
  exp:Spawn()
  exp:SetKeyValue( "iMagnitude", "0" )
  exp:Fire( "Explode", 0, 0 )
end

function SWEP:Equip(newOwner)
  newOwner:SelectWeapon(jumper_weapon_string)
end

function HotswapWeapons(ply, old, new)
  ply:StripWeapon(old)
  ply:Give(new)
end

function SWEP:SetupDataTables()
  self:NetworkVar( "Float" , 0 , "NextFallDamageDenyCheck" )
end

function SWEP:Initialize()
  self:SetNextFallDamageDenyCheck( CurTime() )
end

function SWEP:Think()
   if SERVER then
      if ShouldDenyFallDamage and self:GetNextFallDamageDenyCheck() < CurTime() then
         local ply = self:GetOwner()
         if ply:OnGround() or ply:WaterLevel() ~= 0 then
          RemoveFallDamageMitigation(ply)
         end
      end
      self:SetNextFallDamageDenyCheck(CurTime() + FallDamageDenyCheckInterval)
   end
end

function AddHooksForAttack(ply)
  --BUG: On some maps you ocassionally take damage despite this hook. No fix in development as it happens quite rarely and inconsistently
  hook.Add("EntityTakeDamage", "rocket_jumper__NoFallDamage", function (target, dmgInfo)
    if (ply == target and dmgInfo:IsFallDamage()) then
      RemoveFallDamageMitigation()
      dmgInfo:SetDamage(0)
    elseif (dmgInfo:GetInflictor() == ply and dmgInfo:IsDamageType(DMG_CRUSH)) then
      dmgInfo:SetDamage(0)
    end
  end)

  hook.Add("TTT2PostPlayerDeath", "rocketJumper__RemoveFallDamageMitigationPostDeath", function (victim, inflictor, attacker)
    if (ply == victim) then
      hook.Remove("TTT2PostPlayerDeath", "rocketJumper__RemoveFallDamageMitigationPostDeath")
      RemoveFallDamageMitigation()
    end
  end)

  hook.Add("TTTEndRound", "rocketJumper__RemoveFallDamageMitigationRoundEnd", function(result)
    hook.Remove("TTTEndRound", "rocketJumper__RemoveFallDamageMitigationRoundEnd")
    RemoveFallDamageMitigation()
  end)
end

function RemoveFallDamageMitigation()
   hook.Remove("EntityTakeDamage", "rocket_jumper__NoFallDamage")
   ShouldDenyFallDamage = false
end