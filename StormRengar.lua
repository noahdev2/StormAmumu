--[[
 +-+-+-+-+-+ +-+-+-+-+-+-+
 |S|t|r|o|m| |R|e|n|g|a|r|
 +-+-+-+-+-+ +-+-+-+-+-+-+
]]
if Player.CharName ~= "Rengar" then return end
require("common.log")
module("Storm Rengar", package.seeall, log.setup)
local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs
local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()

--recaller
local Rengar = {}
local RengarHP = {}
local RengarNP = {}

-- spells
local Q = Spell.Active({
    Slot = Enums.SpellSlots.Q,
    Key = "Q",
})
local W = Spell.Active({
    Slot = Enums.SpellSlots.W,
    Range =  450,
    Delay = 0,
    Key = "W",

})
local E = Spell.Skillshot({
    Slot = Enums.SpellSlots.E,
    Range =  1000,
    Delay = 0.25,
    Speed = 1500,
    Radius = 70,
    Collisions = { Heroes = true, Minions = true, WindWall = true},
    Key = "E",
    Type = "Linear"
})
local R = Spell.Active({
    Slot = Enums.SpellSlots.R,
    Key = "R",
})
local Summoner2 = Spell.Targeted({
    Slot = Enums.SpellSlots.Summoner2,
    Range = 600,
    Key = "I"
})
local Summoner1 = Spell.Targeted({
    Slot = Enums.SpellSlots.Summoner1,
    Range = 600,
    Key = "I"
})


local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function dmg(spell)
    local dmg = 0
    if spell.Key == "E" then
        dmg = (55 + (E:GetLevel() - 1) * 45) + (0.8 * Player.BonusAD)
    end
    return dmg
end

function Rengar.OnHighPriority() 
    if not GameIsAvailable() then
        return
    end
    if Player:GetBuff("RengarR") then return end
    if Rengar.Auto() then return end

    local ModeToExecute = RengarHP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end

function Rengar.OnNormalPriority()
    if not GameIsAvailable() then
        return
    end   
    if Player:GetBuff("RengarR") then return end
    local ModeToExecute = RengarNP[Orbwalker.GetMode()]
    if ModeToExecute then
		ModeToExecute()
	end
end


-- DRAW
function Rengar.OnDraw()
    local Pos = Player.Position
   
    local spells = {W,E}
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..v.Key..".Enabled", true) and v:IsReady() then
            Renderer.DrawCircle3D(Pos, v.Range, 30, 3, Menu.Get("Drawing."..v.Key..".Color"))
        end
    end
    if Menu.Get("DrawText") then 
        local mode = nil 
        if Menu.Get("comboMode") == 0 then mode = "Q" end
        if Menu.Get("comboMode") == 1 then mode = "W" end
        if Menu.Get("comboMode") == 2 then mode = "E" end
        if mode == nil then return end
        Renderer.DrawText(Renderer.WorldToScreen(Player.Position) + Geometry.Vector(-45, 50, 0),
        Geometry.Vector(200, 15,0),"Combo Mode = " .. mode ,Menu.Get("color"))
    end
end


-- SPELL HELPERS
local function CanCast(spell,mode)
    return spell:IsReady() and Menu.Get(mode .. ".Cast"..spell.Key)
end

local function HitChance(spell)
    return Menu.Get("Chance."..spell.Key)
end

local function Jungle(spell)
    return spell:IsReady() and Menu.Get("Jungle."..spell.Key)
end

local function GetTargetsRange(Range)
    return {TS:GetTarget(Range,true)}
end

local function GetTargets(Spell)
    return {TS:GetTarget(Spell.Range,true)}
end

local function Count(spell,team,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(team, type)) do
        local minion = v.AsAI
        local Tar    = spell:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
        if minion and Tar then
            num = num + 1
        end
    end
    return num
end

local function GetBestAdAlly(spell)
    local heroes = {}
    for k, v in pairs(ObjManager.Get("ally", "heroes")) do
        if not v.IsDead and not v.IsMe and v.IsValid and spell:IsInRange(v) then 
            insert(heroes,v.AsHero)
        end
    end
    table.sort(heroes,function(a, b) return a.TotalAD > b.TotalAD end)
    for  k,v  in ipairs(heroes) do 
        if v then
            return v.Position
        end
    end
end

local function IsUnderTurrent(pos)
    local sortme = {}
    for k, v in pairs(ObjManager.Get("enemy", "turrets")) do
        if not v.IsDead and v.IsTurret then 
            insert(sortme,v)
        end
    end
    table.sort(sortme,function(a, b) return b:Distance(Player) > a:Distance(Player) end)
    for  k,v  in ipairs(sortme) do 
        return v:Distance(pos) <= 870
    end
end

local function KS(spell)
    return Menu.Get("KS."..spell.Key) and spell:IsReady()
end


-- CALLBACKS
function Rengar.Auto()
    if KS(E) then 
        for k, eTarget in pairs(GetTargets(E)) do
            local eDmg = DmgLib.CalculatePhysicalDamage(Player, eTarget, dmg(E))
            local ksHealth = E:GetKillstealHealth(eTarget)
            if  eDmg > ksHealth and E:CastOnHitChance(eTarget, HitChance(E)) then
                return
            end
        end
    end
end

function Rengar.OnBuffGain(obj, buffInst)
    if not obj.IsMe or not string.match(W:GetName(), "Emp") or not Menu.Get("Misc.W")then return end
    if buffInst.BuffType == Enums.BuffTypes.Taunt or buffInst.BuffType == Enums.BuffTypes.Snare or buffInst.BuffType == Enums.BuffTypes.Charm or buffInst.BuffType == Enums.BuffTypes.Asleep or buffInst.BuffType == Enums.BuffTypes.Suppression or buffInst.BuffType == Enums.BuffTypes.Stun then 
        if W:Cast() then return end
    end
end

function Rengar.OnPreAttack(args)
    local Target = args.Target.AsAI
    local mode = Orbwalker.GetMode()
    if mode == "Combo" then 
        if CanCast(Q,mode) and string.match(Q:GetName(), "Emp") and Menu.Get("comboMode") == 0 then 
            Q:Cast()
            return
        end
    end
    if mode == "Harass" and Target.IsHero then 
        if CanCast(Q,mode) and string.match(Q:GetName(), "Emp") and Menu.Get("HarassMode") == 0 then 
            Q:Cast()
            return
        end
    end
    if mode == "Waveclear" and Target.IsMonster and Target.MaxHealth > 6  then 
        if Jungle(Q)  and string.match(Q:GetName(), "Emp") and  Menu.Get("WaveclearMode") == 0  then 
            if Q:Cast() then return end
        end
    end
end

function Rengar.OnPostAttack(target)
    local Target = target.AsAI
    local mode = Orbwalker.GetMode()
    if mode == "Combo" then 
        if CanCast(Q,mode) and not string.match(Q:GetName(), "Emp") then 
            if Q:Cast() then return end
        end
    end
    if mode == "Harass" and Target.IsHero then 
        if CanCast(Q,mode) and not string.match(Q:GetName(), "Emp") then 
            if Q:Cast() then return end
        end
    end
    if mode == "Waveclear" and target.IsMonster and target.MaxHealth > 6 then 
        if Jungle(Q)  and not string.match(Q:GetName(), "Emp") then 
            if Q:Cast() then return end
        end
    end
end
-- RECALLERS
function RengarHP.Combo()
    local mode = "Combo"
    if Player:GetBuff("rengarpassivebuff") then return end
    if  string.match(E:GetName(), "Emp") and  CanCast(E,mode) and Menu.Get("comboMode") == 2  then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
    if string.match(W:GetName(), "Emp") and CanCast(W,mode) and Menu.Get("comboMode") == 1   then
        for k,v in pairs(GetTargets(W)) do 
            if W:Cast() then return end
        end
    end
end

function  RengarNP.Combo()
    local mode = "Combo"
    if Player:GetBuff("rengarpassivebuff") then return end
    if (string.match(Q:GetName(), "Emp") or string.match(W:GetName(), "Emp") or string.match(E:GetName(), "Emp"))  then return end
    if CanCast(W,mode) then 
        for k,v in pairs(GetTargets(W)) do 
            if W:Cast() then return end
        end
    end
    if CanCast(E,mode) then 
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function RengarHP.Harass()
    local mode = "Harass"
    if Player:GetBuff("rengarpassivebuff") then return end
    if  string.match(E:GetName(), "Emp") and  CanCast(E,mode) and Menu.Get("HarassMode") == 2  then
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
    if string.match(W:GetName(), "Emp") and CanCast(W,mode) and Menu.Get("HarassMode") == 1   then
        for k,v in pairs(GetTargets(W)) do 
            if W:Cast() then return end
        end
    end
end

function RengarNP.Harass()
    local mode = "Harass"
    if Player:GetBuff("rengarpassivebuff") then return end
    if (string.match(Q:GetName(), "Emp") or string.match(W:GetName(), "Emp") or string.match(E:GetName(), "Emp"))  then return end
    if CanCast(W,mode) then 
        for k,v in pairs(GetTargets(W)) do 
            if W:Cast() then return end
        end
    end
    if CanCast(E,mode) then 
        for k,v in pairs(GetTargetsRange(Menu.Get("Max.E"))) do 
            if E:CastOnHitChance(v,HitChance(E)) then return end
        end
    end
end

function RengarHP.Waveclear()
    if Player:GetBuff("rengarpassivebuff") then return end
    if  string.match(E:GetName(), "Emp") and  Jungle(E) and Menu.Get("WaveclearMode") == 2  then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do 
            local minion = v.AsAI
            local minionInRange = E:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                if E:Cast(minion.Position) then return end     
            end                  
        end
    end
    if string.match(W:GetName(), "Emp") and Jungle(W) and Menu.Get("WaveclearMode") == 1   then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do 
            local minion = v.AsAI
            local minionInRange = W:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                if W:Cast() then return end     
            end                  
        end
    end

end
function RengarNP.Waveclear()
    if Player:GetBuff("rengarpassivebuff") then return end
    if (string.match(Q:GetName(), "Emp") or string.match(W:GetName(), "Emp") or string.match(E:GetName(), "Emp"))  then return end
    if Jungle(W) then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do 
            local minion = v.AsAI
            local minionInRange = W:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                if W:Cast() then return end     
            end                  
        end
    end
    if Jungle(E) then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do 
            local minion = v.AsAI
            local minionInRange = E:IsInRange(minion) and minion.MaxHealth > 6 and minion.IsTargetable
            if minionInRange then
                if E:Cast(minion.Position) then return end     
            end                  
        end
    end
end


-- MENU
function Rengar.LoadMenu()
    Menu.RegisterMenu("StormRengar", "Storm Rengar", function()
        Menu.NewTree("Combo", "Combo Options", function()
            Menu.Dropdown("comboMode","Combo mode",0,{"Q", "W","E"})
            Menu.Checkbox("Combo.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Combo.CastW",   "Use [W]", true)
            Menu.Checkbox("Combo.CastE",   "Use [E]", true)
        end)
        Menu.NewTree("Harass", "Harass Options", function()
            Menu.Dropdown("HarassMode","Harass mode",0,{"Q", "W","E"})
            Menu.Checkbox("Harass.CastQ",   "Use [Q]", true)
            Menu.Checkbox("Harass.CastW",   "Use [W]", true)
            Menu.Checkbox("Harass.CastE",   "Use [E]", true)
        end)
        Menu.NewTree("Waveclear", "Waveclear Options", function()
            Menu.Dropdown("WaveclearMode","Waveclear mode",0,{"Q", "W","E"})
            Menu.Checkbox("Jungle.Q",   "Use [Q]", true)
            Menu.Checkbox("Jungle.W",   "Use [W]", true)
            Menu.Checkbox("Jungle.E",   "Use [E]", true)
        end)
        Menu.NewTree("KS", "KillSteal Options", function()
            Menu.Checkbox("KS.E"," Use E to Ks", true)
        end)
        Menu.NewTree("Misc", "Misc Options", function()
            Menu.Checkbox("Misc.W","Auto W | to Remove Debuff",true)
        end)
        Menu.NewTree("Prediction", "Prediction Options", function()
            Menu.Slider("Chance.E","E HitChance", 0.7, 0, 1, 0.05)
        end)
        Menu.NewTree("Range", "Spell Range Options", function()
            Menu.Slider("Max.E","[E] Max Range", 975, 600, 1000)
        end)
        Menu.NewTree("Draw", "Drawing Options", function()
            Menu.Checkbox("DrawText",   "Draw Combo Mode ",true)
            Menu.ColorPicker("color", "Text Color", 0xFFFFFFFF)
            Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range",false)
            Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)
            Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range",true)
            Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)
        end)
    end)     
end


-- LOAD
function OnLoad()
    Rengar.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Rengar[eventName] then
            EventManager.RegisterCallback(eventId, Rengar[eventName])
        end
    end    
    return true
end