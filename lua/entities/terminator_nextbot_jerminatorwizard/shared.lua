AddCSLuaFile()

ENT.Base = "terminator_nextbot_jerminator_realistic"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Jerma991"
ENT.Spawnable = false
ENT.Author = "regunkyle"
terminator_Extras.RegisterNPC( "terminator_nextbot_jerminatorwizard", ENT )

if CLIENT then return end

    ------------------------------------------------------------------------
    -- custom fire trail
    -- a clientside mimic of env_fire_trail ( C_FireTrail::Update ) with a
    -- customisable color. flamelet sprites are stamped along the carrier's
    -- movement path to fill gaps, plus a smoke puff, all tinted with the
    -- trail's color.
    -- the trail's size automatically scales with the carrier's model size,
    -- so a big meteor gets big flames that wrap around its whole body,
    -- while a small fireball keeps its small, neat trail.
    -- attach one serverside with jerminator_WizardExtras.SetCustomFireTrail( ent, r, g, b )
    ------------------------------------------------------------------------
    jerminator_CustomFireTrail = jerminator_CustomFireTrail or {}

    do
        -- material NAME STRINGS, not Material() handles!
        -- handles built at file-load time can end up with unloaded textures, and the
        -- emitter then draws blank particles. passing names lets the particle system
        -- load each material itself, at runtime, when it's definitely safe to do so.
        local FLAMELET_NAMES = {
            "sprites/flamelet1",
            "sprites/flamelet2",
            "sprites/flamelet3",
            "sprites/flamelet4",
            "sprites/flamelet5",
        }
        local SMOKE_NAME = "particle/particle_smokegrenade"

        local flameletNames = table.Copy( FLAMELET_NAMES )
        local warmedUp = false

        -- one-time warmup, runs during gameplay rather than at file load.
        -- forces the vmts to load, and swaps out any flamelet that genuinely
        -- doesn't exist on this client for flamelet1
        local function warmupTrailMaterials()
            if warmedUp then return end
            warmedUp = true

            for i, name in ipairs( FLAMELET_NAMES ) do
                if Material( name ):IsError() then
                    flameletNames[i] = FLAMELET_NAMES[1]
                end
            end
            Material( SMOKE_NAME )
        end

        local activeTrails = {}

        function jerminator_CustomFireTrail.Add( ent, color )
            if not IsValid( ent ) then return end
            warmupTrailMaterials()

            local existing = activeTrails[ent]
            if existing then
                existing.color = color
                return
            end

            activeTrails[ent] = {
                color = color,
                lastPos = ent:GetPos(),
            }
        end

        function jerminator_CustomFireTrail.Remove( ent )
            activeTrails[ent] = nil
        end

        hook.Add( "Think", "jerminator_customfiretrail", function()
            if not next( activeTrails ) then return end

            for ent, data in pairs( activeTrails ) do
                if not IsValid( ent ) then
                    activeTrails[ent] = nil
                    continue
                end

                local pos = ent:GetPos()
                if ent:IsDormant() then
                    -- out of PVS, sync up so there's no giant streak when it wakes
                    data.lastPos = pos
                    continue
                end

                -- emitter created and finished every frame, the safe pattern
                local emitter = ParticleEmitter( pos )
                if not emitter then
                    data.lastPos = pos
                    continue
                end

                local color = data.color

                local sizeMul = data.sizeMul
                if not sizeMul then
                    local radius = ent:GetModelRadius() or 0
                    if radius > 0 then
                        sizeMul = math.Clamp( radius / 8, 1, 5 )
                        data.sizeMul = sizeMul
                        data.wrapRadius = math.max( radius * 0.85, 4 )
                    else
                        sizeMul = 1
                    end
                end
                local wrapRadius = data.wrapRadius or 4

                local moveDiff = pos - data.lastPos
                local moveLength = moveDiff:Length()

                local dir = vector_origin
                if moveLength > 0.1 then
                    dir = moveDiff / moveLength
                end

                local flameDie = 0.4 + 0.1 * sizeMul
                local numPuffs = math.max( 1, math.floor( moveLength / 4 ) )
                numPuffs = math.min( numPuffs, 32 )
                local step = moveLength / numPuffs

                for i = 1, numPuffs do
                    local part = emitter:Add( flameletNames[math.random( 1, #flameletNames )], data.lastPos + dir * ( step * i ) + VectorRand() * wrapRadius )
                    if part then
                        part:SetDieTime( flameDie )
                        part:SetVelocity( Vector( math.Rand( 0, 1 ), math.Rand( 0, 1 ), math.Rand( 0, 1 ) ) * math.Rand( 32, 64 ) * sizeMul + Vector( 0, 0, 50 * sizeMul ) )
                        part:SetColor( color.r, color.g, color.b )
                        part:SetStartSize( 16 * sizeMul )
                        part:SetEndSize( 4 * sizeMul )
                        part:SetStartAlpha( 255 )
                        part:SetEndAlpha( 0 )
                        part:SetRoll( 0 )
                        part:SetRollDelta( math.Rand( -16, 16 ) )
                    end
                end

                -- smoke puff, tinted toward the trail color
                local part = emitter:Add( SMOKE_NAME, pos + VectorRand() * math.max( wrapRadius * 0.5, 4 ) )
                if part then
                    part:SetDieTime( 0.75 + math.Rand( 0.05, 0.1 ) * sizeMul )
                    part:SetVelocity( Vector( math.Rand( 0, 1 ), math.Rand( 0, 1 ), math.Rand( 0, 1 ) ) * math.Rand( 32, 64 ) * sizeMul + Vector( 0, 0, math.Rand( 50, 100 ) * sizeMul ) )
                    part:SetColor( color.r * 0.5, color.g * 0.5, color.b * 0.5 )
                    local startSize = 16 * sizeMul * math.Rand( 0.75, 1.25 )
                    part:SetStartSize( startSize )
                    part:SetEndSize( startSize * 2.5 )
                    part:SetStartAlpha( 64 )
                    part:SetEndAlpha( 0 )
                    part:SetRoll( math.random( 0, 360 ) )
                    part:SetRollDelta( math.Rand( -16, 16 ) )
                end

                emitter:Finish()

                data.lastPos = pos
            end
        end )

        net.Receive( "jerminator_firetrail", function()
            local ent = net.ReadEntity()
            local r = net.ReadUInt( 8 )
            local g = net.ReadUInt( 8 )
            local b = net.ReadUInt( 8 )
            if not IsValid( ent ) then return end
            jerminator_CustomFireTrail.Add( ent, Color( r, g, b ) )
        end )
    end

    return
end

jerminator_WizardExtras = jerminator_WizardExtras or {}

util.AddNetworkString( "jerminator_firetrail" )

-- never get close to enemy
function ENT:EnemyIsLethalInMelee()
    local enemy = self:GetEnemy()
    return IsValid( enemy ) and self.IsSeeEnemy and enemy:Health() >= 10

end

ENT.CoroutineThresh = terminator_Extras.baseCoroutineThresh / 5

ENT.term_SoundLevelShift = 10

ENT.WalkSpeed = 75
ENT.MoveSpeed = 200
ENT.RunSpeed = 360
ENT.TERM_WEAPON_PROFICIENCY = WEAPON_PROFICIENCY_POOR
ENT.AccelerationSpeed = 1500
ENT.JumpHeight = 70 * 6
ENT.Term_Leaps = true
ENT.FistDamageMul = 0.25
ENT.ThrowingForceMul = 0.5
ENT.SpawnHealth = 250
ENT.HealthRegen = 10
ENT.HealthRegenInterval = 0.5
ENT.MyPhysicsMass = 150

ENT.FootstepClomping = false
ENT.duelEnemyTimeoutMul = 5

ENT.jerm_HoldType = "magic"

-- cone/hat look, subclasses can override these
ENT.WizardConeColor = Color( 150, 0, 255 )
ENT.WizardConeScale = 0.69
ENT.WizardConeGlow = nil -- no glow by default

-- Wizard specific settings
ENT.LightningRange = 1200
ENT.LightningDamage = 35
ENT.LightningBoltCount = 5
ENT.FireballRange = 3500
ENT.FireballDamage = 50
ENT.FireballSpeed = 2000
ENT.FireballBlastRadius = 100 -- radius of the fireball's detonation blast
ENT.FireballLifetime = 5 -- seconds before a stray fireball detonates on its own
ENT.CanFindWeaponsOnTheGround = false

-- Pre-defined colors table for rainbow lightning (created once)
local LIGHTNING_COLORS = {
    Angle( 255, 50, 50 ),      -- Red
    Angle( 50, 255, 50 ),      -- Green
    Angle( 50, 50, 255 ),      -- Blue
    Angle( 255, 255, 50 ),     -- Yellow
    Angle( 255, 50, 255 ),     -- Magenta
    Angle( 50, 255, 255 ),     -- Cyan
    Angle( 255, 150, 50 ),     -- Orange
    Angle( 180, 50, 255 ),     -- Purple
    Angle( 255, 100, 200 ),    -- Pink
    Angle( 100, 255, 150 ),    -- Mint
}

local function RandomLightningColor()
    return LIGHTNING_COLORS[math.random( 1, #LIGHTNING_COLORS )]
end

-- pulls r, g, b out of one of the LIGHTNING_COLORS angles
-- ( the arc fx reads them as Angle( r, g, b ) )
local function lightningColorToRGB( colAng )
    return colAng.p, colAng.y, colAng.r
end

local function GetCastingStartPos( bot )
    local attachment = bot:GetAttachment( bot:LookupAttachment( "anim_attachment_RH" ) )
    if attachment then return attachment.Pos end

    return bot:WorldSpaceCenter() + bot:GetForward() * 20
end

-- rainbow lightning arc fx, pass colorOverride to use a specific lightning color
local function wizardArcFX( startPos, endPos, parent, scale, magnitude, radius, colorOverride )
    scale = scale or 1.5
    magnitude = magnitude or 10
    radius = radius or 30

    local fx = EffectData()
    fx:SetOrigin( startPos )
    fx:SetStart( endPos )
    fx:SetNormal( ( endPos - startPos ):GetNormalized() )
    fx:SetScale( scale )
    fx:SetMagnitude( magnitude )
    fx:SetRadius( radius )
    fx:SetAngles( colorOverride or RandomLightningColor() )
    fx:SetDamageType( 3 )
    fx:SetEntity( parent or game.GetWorld() )
    fx:SetFlags( 0 )
    util.Effect( "eff_term_goodarc", fx )
end

-- attaches the customisable fire trail ( see the client section ) to an entity
-- also stores the color as an NWVector, so other addons can spot player-thrown fireballs
-- calling it again with a new color updates an existing trail
local function setCustomFireTrail( ent, r, g, b )
    if not IsValid( ent ) then return end
    ent:SetNWVector( "jerminator_FireTrailColor", Vector( r / 255, g / 255, b / 255 ) )
    net.Start( "jerminator_firetrail" )
        net.WriteEntity( ent )
        net.WriteUInt( r, 8 )
        net.WriteUInt( g, 8 )
        net.WriteUInt( b, 8 )
    net.Broadcast()
end

-- small patch of fire left behind by explosions
local function createFirePatch( pos, firesize, lifetime )
    local fire = ents.Create( "env_fire" )
    if not IsValid( fire ) then return end
    fire:SetPos( pos )
    fire:SetKeyValue( "health", "30" )
    fire:SetKeyValue( "firesize", tostring( firesize ) )
    fire:SetKeyValue( "fireattack", "4" )
    fire:SetKeyValue( "damagescale", "1" )
    fire:SetKeyValue( "spawnflags", "281" )
    fire:Spawn()
    fire:Activate()
    fire:Fire( "StartFire", "", 0 )

    timer.Simple( 0.1, function()
        if not IsValid( fire ) then return end
        fire:DropToFloor()
    end )
    SafeRemoveEntityDelayed( fire, lifetime )
end

jerminator_WizardExtras.RandomLightningColor = RandomLightningColor
jerminator_WizardExtras.LightningColors = LIGHTNING_COLORS
jerminator_WizardExtras.LightningColorToRGB = lightningColorToRGB
jerminator_WizardExtras.GetCastingStartPos = GetCastingStartPos
jerminator_WizardExtras.ArcFX = wizardArcFX
jerminator_WizardExtras.SetCustomFireTrail = setCustomFireTrail
jerminator_WizardExtras.CreateFirePatch = createFirePatch

------------------------------------------------------------------------
-- fireball!
-- the fireball is an invisible physics prop that flies dead straight and detonates on impact
-- it only ever deals damage through its detonation blast ( DMG_BURN + DMG_BLAST )
-- the prop itself never deals its own kinetic impact damage
-- ( that prop impact damage was the old bug where a 50 damage fireball hit for ~200 )
------------------------------------------------------------------------

local FIREBALL_MODEL = "models/props_junk/popcan01a.mdl"
local FIREBALL_TRACKER_CLASS = "jerminator_wizard_fireball"
local FIREBALL_TICK = 0.1

-- green, for fireballs that have been touched by a player
local PLAYER_FIRE_R, PLAYER_FIRE_G, PLAYER_FIRE_B = 60, 255, 130

-- our projectiles only ever deal damage through their own blasts/zaps. the props' kinetic impact damage ( DMG_CRUSH from a heavy object at speed ) is blocked, that stacking was the annoying 200 damage bug
hook.Add( "EntityTakeDamage", "jerminator_wizard_impactfix", function( target, dmg )
    local inflictor = dmg:GetInflictor()
    if not IsValid( inflictor ) then return end

    local isOurProjectile = inflictor.jerminator_IsWizardFireball
        or inflictor.jerma_IsLightningOrb
        or inflictor.jerma_IsWizardMeteor
        or inflictor.jerma_IsWizardMeteorDebris

    if not isOurProjectile then return end

    if not ( dmg:IsDamageType( DMG_BURN ) or dmg:IsDamageType( DMG_BLAST ) or dmg:IsDamageType( DMG_SHOCK ) or dmg:IsDamageType( DMG_DISSOLVE ) ) then
        return true -- blocks the prop's own kinetic impact damage

    elseif IsValid( target ) then
        -- soften hits on the caster's own team ( never softens player-thrown fireballs )
        local owner = inflictor:GetOwner()
        local ownerChummy = IsValid( owner ) and owner.isTerminatorHunterChummy or nil
        if ownerChummy and target.isTerminatorHunterChummy == ownerChummy then
            dmg:ScaleDamage( 0.25 )
        end
    end
end )

local function detonateWizardFireball( fireball, hitPos )
    if not IsValid( fireball ) then return end
    if fireball.jerminator_FireballDetonated then return end
    fireball.jerminator_FireballDetonated = true

    hitPos = hitPos or fireball:GetPos()

    local owner = fireball:GetOwner()
    local attacker = IsValid( owner ) and owner or fireball

    -- boom
    local boomFx = EffectData()
    boomFx:SetOrigin( hitPos )
    boomFx:SetScale( 1 )
    util.Effect( "Explosion", boomFx )

    sound.Play( "ambient/explosions/explode_" .. math.random( 3, 5 ) .. ".wav", hitPos, 100, math.random( 90, 110 ) )

    if fireball.jerma_PlayerThrown then
        -- a little green flare on player-thrown hits
        local flare = EffectData()
        flare:SetOrigin( hitPos )
        flare:SetNormal( vector_up )
        flare:SetScale( 2 )
        util.Effect( "Sparks", flare )
    end

    -- the only damage a fireball ever deals, exactly FireballDamage
    local dmg = DamageInfo()
    dmg:SetDamage( fireball.jerminator_FireballDamage or 50 )
    dmg:SetDamageType( bit.bor( DMG_BURN, DMG_BLAST ) )
    dmg:SetAttacker( attacker )
    dmg:SetInflictor( fireball )
    dmg:SetDamagePosition( hitPos )

    util.BlastDamageInfo( dmg, hitPos, fireball.jerminator_FireballBlastRadius or 100 )

    -- leave a patch of fire behind
    createFirePatch( hitPos, 64, 4 )

    -- the prop has done its job, CallOnRemove cleans up its trail, light and held fx
    SafeRemoveEntity( fireball )
end

local function wizardFireballLight( fireball, colorString )
    SafeRemoveEntity( fireball.jerma_LightEnt )

    local light = ents.Create( "light_dynamic" )
    if not IsValid( light ) then return end
    light:SetKeyValue( "brightness", "6" )
    light:SetKeyValue( "distance", "300" )
    light:SetKeyValue( "_light", colorString )
    light:SetPos( fireball:GetPos() )
    light:SetParent( fireball )
    light:SetTransmitWithParent( true )
    light:Spawn()
    light:Fire( "TurnOn" )

    fireball.jerma_LightEnt = light
end

-- switches the fireball over to the green custom fire trail + green light
-- a fireball touched by a player stays green for the rest of its life
local function makeWizardFireballPlayerThrown( fireball )
    if fireball.jerma_PlayerTrailApplied then return end
    fireball.jerma_PlayerTrailApplied = true

    -- the wizard's orange env_fire_trail is swapped for the custom green one
    SafeRemoveEntity( fireball.jerma_FireTrailEnt )
    fireball.jerma_FireTrailEnt = nil

    setCustomFireTrail( fireball, PLAYER_FIRE_R, PLAYER_FIRE_G, PLAYER_FIRE_B )
    wizardFireballLight( fireball, "60 255 130 255" )
end

-- green glow while it's trapped in the gravity gun's beam
local function setWizardFireballHeld( fireball, held )
    if held then
        if IsValid( fireball.jerma_HeldGlow ) then return end

        local glow = ents.Create( "env_sprite" )
        if IsValid( glow ) then
            glow:SetKeyValue( "model", "sprites/glow04_noz.vmt" )
            glow:SetKeyValue( "rendercolor", "60 255 130" )
            glow:SetKeyValue( "scale", "1.5" )
            glow:SetPos( fireball:GetPos() )
            glow:SetParent( fireball )
            glow:SetTransmitWithParent( true )
            glow:Spawn()
            fireball.jerma_HeldGlow = glow
        end

        fireball:EmitSound( "ambient/levels/citadel/portal_beam_shoot5.wav", 75, math.random( 115, 135 ) )

    else
        SafeRemoveEntity( fireball.jerma_HeldGlow )
        fireball.jerma_HeldGlow = nil
        -- the green fire trail ( and light ) stays, it's a player's fireball now
    end
end

local function wizardFireballPuntFX( fireball )
    local pos = fireball:GetPos()

    local sparks = EffectData()
    sparks:SetOrigin( pos )
    sparks:SetNormal( vector_up )
    sparks:SetMagnitude( 3 )
    sparks:SetScale( 1 )
    sparks:SetRadius( 8 )
    util.Effect( "Sparks", sparks )

    fireball:EmitSound( "ambient/fire/gascan_ignite1.wav", 80, math.random( 105, 125 ) )
    fireball:EmitSound( "ambient/levels/citadel/weapon_disintegrate4.wav", 80, math.random( 110, 130 ) )
end

------------------------------------------------------------------------
-- gravity gun interaction
-- grabbed: the fuse FREEZES, and the trail switches to the custom green fire trail
-- punted: the fuse RESETS to full, and the fireball becomes the player's
------------------------------------------------------------------------

hook.Add( "GravGunPickupAllowed", "jerminator_wizard_fireball_pickup", function( _ply, ent )
    if IsValid( ent ) and ent.jerminator_IsWizardFireball then return true end
end )

hook.Add( "GravGunOnPickedUp", "jerminator_wizard_fireball_grab", function( ply, ent )
    if not IsValid( ent ) or not ent.jerminator_IsWizardFireball then return end
    if ent.jerminator_FireballDetonated then return end

    ent.jerma_HeldBy = ply

    makeWizardFireballPlayerThrown( ent )
    setWizardFireballHeld( ent, true )
end )

hook.Add( "GravGunOnDropped", "jerminator_wizard_fireball_drop", function( ply, ent )
    if not IsValid( ent ) or not ent.jerminator_IsWizardFireball then return end
    if ent.jerma_HeldBy ~= ply then return end

    ent.jerma_HeldBy = nil
    setWizardFireballHeld( ent, false )
end )

hook.Add( "GravGunPunt", "jerminator_wizard_fireball_punt", function( ply, ent )
    if not IsValid( ent ) or not ent.jerminator_IsWizardFireball then return end
    if ent.jerminator_FireballDetonated then return end

    ent.jerma_HeldBy = nil
    setWizardFireballHeld( ent, false )

    -- it's the player's fireball now, they get the kill credit and it won't hit them
    ent:SetOwner( ply )
    ent:CollisionRulesChanged()
    ent.jerma_PlayerThrown = true

    -- punting resets the fuse back to full
    ent.jerma_FuseRemaining = ent.jerma_FuseLifetime

    wizardFireballPuntFX( ent )
end )

-- runs the fireball's fuse
-- the fuse is FROZEN while a player holds the fireball with the gravity gun
-- and RESET back to full whenever the fireball gets punted
local function manageWizardFireballFuse( fireball, lifetime )
    local timerName = "jerminator_wizard_fireball_fuse_" .. fireball:GetCreationID()

    fireball.jerma_FuseLifetime = lifetime
    fireball.jerma_FuseRemaining = lifetime

    timer.Create( timerName, FIREBALL_TICK, 0, function()
        if not IsValid( fireball ) or fireball.jerminator_FireballDetonated then
            timer.Remove( timerName )
            return
        end

        -- grab detection fallback, in case the gravity gun hooks were missed
        local physicallyHeld = fireball:IsPlayerHolding()
        if physicallyHeld and fireball.jerma_HeldBy == nil then
            fireball.jerma_HeldBy = true -- holder unknown
            makeWizardFireballPlayerThrown( fireball )
            setWizardFireballHeld( fireball, true )
        end

        local heldBy = fireball.jerma_HeldBy

        if isentity( heldBy ) and ( not IsValid( heldBy ) or not heldBy:Alive() ) then
            -- the holder died or vanished, treat it as dropped
            fireball.jerma_HeldBy = nil
            setWizardFireballHeld( fireball, false )
            heldBy = nil

        elseif heldBy == true and not physicallyHeld then
            -- slipped out without a drop hook
            fireball.jerma_HeldBy = nil
            setWizardFireballHeld( fireball, false )
            heldBy = nil
        end

        if physicallyHeld or heldBy ~= nil then
            -- fuse frozen while held, the trapped fire crackles
            if math.random() < 0.2 then
                fireball:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav", 65, math.random( 150, 190 ), 0.4 )
            end
            return
        end

        fireball.jerma_FuseRemaining = ( fireball.jerma_FuseRemaining or lifetime ) - FIREBALL_TICK
        if fireball.jerma_FuseRemaining <= 0 then
            timer.Remove( timerName )
            detonateWizardFireball( fireball, fireball:GetPos() )
        end
    end )
end

local function createWizardFireball( bot, startPos, aimDir )
    local fireball = ents.Create( "prop_physics" )
    if not IsValid( fireball ) then return end

    fireball:SetOwner( bot ) -- stops the fireball colliding with its caster

    fireball:SetModel( FIREBALL_MODEL )
    fireball:SetPos( startPos )
    fireball:SetAngles( aimDir:Angle() )
    fireball:Spawn()

    fireball:SetNoDraw( true )
    fireball:SetCollisionGroup( COLLISION_GROUP_PROJECTILE )
    fireball:CollisionRulesChanged()

    -- the fireball's settings travel with it
    fireball.jerminator_IsWizardFireball = true
    fireball.terminator_Judger_WepClassToCredit = FIREBALL_TRACKER_CLASS
    fireball.jerminator_FireballDamage = bot.FireballDamage or 50
    fireball.jerminator_FireballBlastRadius = bot.FireballBlastRadius or 100
    fireball.jerminator_FireballSpeed = bot.FireballSpeed or 2000

    local phys = fireball:GetPhysicsObject()
    if not IsValid( phys ) then
        SafeRemoveEntity( fireball )
        return
    end

    phys:SetMass( 100 )
    phys:SetVelocity( aimDir * fireball.jerminator_FireballSpeed )
    phys:EnableGravity( false )

    local fireEffect = ents.Create( "env_fire_trail" )
    if IsValid( fireEffect ) then
        fireEffect:SetPos( startPos )
        fireEffect:SetParent( fireball )
        fireEffect:Spawn()
        fireball.jerma_FireTrailEnt = fireEffect
    end

    wizardFireballLight( fireball, "255 100 0 255" )

    -- everything hanging off the fireball gets cleaned up with it
    fireball:CallOnRemove( "jerminator_wizard_fireball_cleanup", function( ent )
        SafeRemoveEntity( ent.jerma_FireTrailEnt )
        SafeRemoveEntity( ent.jerma_LightEnt )
        SafeRemoveEntity( ent.jerma_HeldGlow )
    end )

    -- armed the instant it leaves the caster's hand
    fireball:AddCallback( "PhysicsCollide", function( ent, data )
        if ent.jerminator_FireballDetonated then return end
        if ent:IsPlayerHolding() then return end -- snatched mid-flight, the fuse is frozen

        if data.HitEntity == ent:GetOwner() then return end -- never detonate on the caster ( or the punter )
        if data.Speed < 40 then return end -- ignore soft scrapes

        detonateWizardFireball( ent, data.HitPos )
    end )

    return fireball
end

function ENT:ThrowWizardFireball( driver, enemy )
    local startPos = GetCastingStartPos( self )
    local aimDir

    if not IsValid( driver ) and IsValid( enemy ) then
        -- lead the target a bit so the fireball actually connects
        local targetPos = enemy:WorldSpaceCenter()
        local flightTime = startPos:Distance( targetPos ) / math.max( self.FireballSpeed or 2000, 1 )
        targetPos = targetPos + enemy:GetVelocity() * flightTime * 0.75
        aimDir = ( targetPos - startPos ):GetNormalized()

    else
        aimDir = self:GetAimVector()
    end

    local fireball = createWizardFireball( self, startPos, aimDir )
    if not IsValid( fireball ) then return end

    self:EmitSound( "ambient/fire/gascan_ignite1.wav", 80 )
    fireball:EmitSound( "ambient/fire/ignite.wav", 80 )

    manageWizardFireballFuse( fireball, self.FireballLifetime or 5 )
end

ENT.MySpecialActions = {
    ["LightningStrike"] = {
        inBind = IN_RELOAD,
        drawHint = true,
        name = "Lightning",
        desc = "Rainbow lightning!",
        ratelimit = 2,

        svAction = function( _drive, driver, bot )
            local enemy = bot:GetEnemy()
            local targetPos

            bot:DoWizardSounds()

            bot:DoGesture( ACT_GMOD_GESTURE_RANGE_FRENZY, 1 )

            timer.Simple( 0.5, function()
                if not IsValid( bot ) then return end

                local startPos = GetCastingStartPos( bot )

                if not IsValid( driver ) and IsValid( enemy ) then
                    targetPos = enemy:WorldSpaceCenter()

                else
                    local tr = util.TraceLine( {
                        start = bot:EyePos(),
                        endpos = bot:EyePos() + bot:GetAimVector() * bot.LightningRange,
                        filter = bot,
                        mask = MASK_SHOT
                    } )
                    targetPos = tr.HitPos

                end

                local tr = util.TraceLine( {
                    start = startPos,
                    endpos = targetPos,
                    filter = bot,
                    mask = MASK_SHOT
                } )
                local hitPos = tr.HitPos

                -- Create multiple rainbow lightning bolts
                for i = 1, bot.LightningBoltCount do
                    timer.Simple( ( i - 1 ) * 0.05, function()
                        if not IsValid( bot ) then return end

                        local offset = VectorRand() * 30
                        local boltTarget = hitPos + offset

                        wizardArcFX( startPos, boltTarget, bot )

                        if i ~= 1 then return end

                        bot:EmitSound( "ambient/energy/zap" .. math.random( 1, 9 ) .. ".wav", 90, math.random( 90, 110 ) )

                    end )
                end

                -- Deal damage to entities near the target
                timer.Simple( 0.1, function()
                    if not IsValid( bot ) then return end

                    local dmg = DamageInfo()
                    dmg:SetDamage( bot.LightningDamage )
                    dmg:SetDamageType( DMG_DISSOLVE + DMG_SHOCK )
                    dmg:SetAttacker( bot )
                    dmg:SetInflictor( bot )
                    dmg:SetDamagePosition( hitPos )

                    util.BlastDamageInfo( dmg, hitPos, 60 )

                end )
            end )
        end,
    },

    ["Fireball"] = {
        inBind = IN_ATTACK2,
        drawHint = true,
        name = "Fireball",
        desc = "Launches a fireball at enemy",
        ratelimit = 3,

        svAction = function( _drive, driver, bot )
            bot:DoWizardSounds()

            bot:DoGesture( ACT_GMOD_GESTURE_ITEM_THROW, 1.2 )

            timer.Simple( 0.5, function()
                if not IsValid( bot ) then return end
                bot:ThrowWizardFireball( driver, bot:GetEnemy() )

            end )
        end,
    },
}

function ENT:DoWizardSounds()
    local duration = self:Term_SpeakSoundNow( self:jerm_RandomSoundPath( "shootwizard" ) ) -- speak one line NOW
    timer.Simple( duration, function()
        if not IsValid( self ) then return end
        self:Term_SpeakSound( self:jerm_RandomSoundPath( "shootwizard" ) ) -- and put another wizard line in the queue

    end )
end

local function CreateWizardCone( bot )
    local cone = ents.Create( "prop_dynamic" )
    if not IsValid( cone ) then return end

    cone:SetModel( "models/props_junk/trafficcone001a.mdl" )
    cone:SetPos( bot:GetPos() + Vector( 0, 0, 80 ) )
    cone:Spawn()
    cone:SetColor( bot.WizardConeColor or Color( 150, 0, 255 ) )
    cone:SetMaterial( "models/debug/debugwhite" )
    cone:SetModelScale( bot.WizardConeScale or 0.69 )

    local glowColor = bot.WizardConeGlow
    if glowColor then
        local glow = ents.Create( "env_sprite" )
        if IsValid( glow ) then
            glow:SetKeyValue( "model", "sprites/glow04_noz.vmt" )
            glow:SetKeyValue( "rendercolor", string.format( "%d %d %d", glowColor.r, glowColor.g, glowColor.b ) )
            glow:SetKeyValue( "scale", "0.75" )
            glow:SetPos( cone:GetPos() )
            glow:SetParent( cone )
            glow:SetLocalPos( Vector( 0, 0, 14 ) )
            glow:SetTransmitWithParent( true )
            glow:Spawn()
            cone:DeleteOnRemove( glow )
        end
    end

    local headBone = bot:LookupBone( "ValveBiped.Bip01_Head1" )
    if headBone then
        cone:FollowBone( bot, headBone )
        cone:SetLocalPos( Vector( 14.72, 5.31, 0 ) )
        cone:SetLocalAngles( Angle( 90, 19.06, 0 ) )

    else
        cone:SetParent( bot )
        cone:SetLocalPos( Vector( 14.72, 5.31, 0 ) )
        cone:SetLocalAngles( Angle( 90, 19.06, 0 ) )

    end

    bot:DeleteOnRemove( cone )
    bot.WizardCone = cone

end

local function DropWizardCone( bot )
    if not IsValid( bot.WizardCone ) then return end

    local conePos = bot.WizardCone:GetPos()
    local coneAng = bot.WizardCone:GetAngles()

    SafeRemoveEntity( bot.WizardCone )
    bot.WizardCone = nil

    local droppedCone = ents.Create( "prop_physics" )
    if not IsValid( droppedCone ) then return end

    droppedCone:SetModel( "models/props_junk/trafficcone001a.mdl" )
    droppedCone:SetPos( conePos )
    droppedCone:SetAngles( coneAng )
    droppedCone:Spawn()
    droppedCone:SetColor( bot.WizardConeColor or Color( 150, 0, 255 ) )
    droppedCone:SetMaterial( "models/debug/debugwhite" )
    droppedCone:SetModelScale( bot.WizardConeScale or 0.69 )

    local phys = droppedCone:GetPhysicsObject()
    if IsValid( phys ) then
        phys:SetVelocity( Vector( math.Rand( -50, 50 ), math.Rand( -50, 50 ), 100 ) )
        phys:AddAngleVelocity( VectorRand() * 200 )

    end

    SafeRemoveEntityDelayed( droppedCone, 30 )

end

local function SummonWizardCone( bot )
    if bot.RespawningCone then return end
    bot.RespawningCone = true

    bot:DoWizardSounds()

    -- todo, better gesture, and use wait
    bot:DoGesture( ACT_GMOD_GESTURE_ITEM_GIVE, 1, true )

    timer.Simple( 0.6, function()
        if not IsValid( bot ) then return end

        local headPos = bot:GetPos() + Vector( 0, 0, 80 )

        for i = 1, 5 do
            timer.Simple( ( i - 1 ) * 0.06, function()
                if not IsValid( bot ) then return end

                wizardArcFX( headPos, headPos + VectorRand() * 40, bot, 1, 8, 20 )
                bot:EmitSound( "ambient/energy/zap" .. math.random( 1, 9 ) .. ".wav", 75, math.random( 120, 140 ) )

            end )
        end

        timer.Simple( 0.4, function()
            if not IsValid( bot ) then return end
            CreateWizardCone( bot )
            bot.RespawningCone = false

        end )
    end )
end

ENT.MyClassTask = {
    OnCreated = function( self, data )
        data.lastSpell = CurTime()

        timer.Simple( 0.1, function()
            if not IsValid( self ) then return end
            SummonWizardCone( self )
        end )
    end,

    BehaveUpdatePriority = function( self, data )
        if not IsValid( self.WizardCone ) then
            local lastSpot = self.LastEnemySpotTime or 0
            if CurTime() - lastSpot > 5 then
                SummonWizardCone( self )
                data.lastSpell = CurTime()
            end
        end

        local add = self:IsReallyAngry() and math.Rand( 1, 2 ) or math.Rand( 5, 10 )
        if ( data.lastSpell + add ) > CurTime() then return end

        local enemy = self:GetEnemy()
        if not IsValid( enemy ) then return end
        if not self.NothingOrBreakableBetweenEnemy then return end

        local dist = self.DistToEnemy or self:GetPos():Distance( enemy:GetPos() )

        if dist < self.LightningRange and dist > 100 and ( self:getLostHealth() > 10 or self:inSeriousDanger() ) then
            if not self:CanTakeAction( "LightningStrike" ) then return end

            self:TakeAction( "LightningStrike" )
            return

        end

        if dist < self.FireballRange and dist > 150 then
            if not self:CanTakeAction( "Fireball" ) then return end

            self:TakeAction( "Fireball" )
            return

        end
    end,

    OnKilled = function( self, _data )
        DropWizardCone( self )

    end,
}
