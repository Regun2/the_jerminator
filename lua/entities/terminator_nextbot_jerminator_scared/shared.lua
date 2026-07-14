
AddCSLuaFile()

ENT.Base = "terminator_nextbot_jerminator"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Jerma984"
ENT.Spawnable = false
terminator_Extras.RegisterNPC( "terminator_nextbot_jerminator_scared", ENT )

if CLIENT then return end

function ENT:EnemyIsLethalInMelee()
    local enemy = self:GetEnemy()
    return IsValid( enemy ) and self.IsSeeEnemy

end