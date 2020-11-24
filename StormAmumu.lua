--[[
    First Release By Storm Team (Martin) @ 24.Nov.2020    
]]

if Player.CharName ~= "Amumu" then return end

require("common.log")
module("Storm Amumu", package.seeall, log.setup)

local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Amumu = {}

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 1050,
        Radius = 80,
        Delay = 0.25,
        Speed = 2000,
        Collisions = {WindWall = true,Minions=true },
        Type = "Linear",
        UseHitbox = true
    }),
    W = Spell.Active({
        Slot = Enums.SpellSlots.W,
        Range = 300
    }),
    E = Spell.Active({
        Slot = Enums.SpellSlots.E,
        Range = 350,
    }),
    R = Spell.Active({
        Slot = Enums.SpellSlots.R,
        Range = 550,
        Delay = 0.25,
    }),
}

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Amumu.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end
local lastTick = 0
function Amumu.OnTick()    
    if not GameIsAvailable() then return end 

    local gameTime = Game.GetTime()
    if gameTime < (lastTick + 0.25) then return end
    lastTick = gameTime    
    if Amumu.Auto() then return end
    if not Orbwalker.CanCast() then return end

    local ModeToExecute = Amumu[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end
function Amumu.OnDraw() 
    local playerPos = Player.Position
    local pRange = Orbwalker.GetTrueAutoAttackRange(Player)   
    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..k..".Enabled", true) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 2, Menu.Get("Drawing."..k..".Color")) 
        end
    end
end

function Amumu.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Amumu.ComboLogic(mode)
    if Amumu.IsEnabledAndReady("Q", mode) then
        local qChance = Menu.Get(mode .. ".ChanceQ")
        for k, qTarget in ipairs(Amumu.GetTargets(spells.Q.Range)) do
            if spells.Q:CastOnHitChance(qTarget, qChance) then
                return
            end
        end
    end
    if Amumu.IsEnabledAndReady("W", mode) then
        for k, wTarget in ipairs(Amumu.GetTargets(spells.W.Range)) do
            if not Player:GetBuff("AuraOfDespair") then
                spells.W:Cast()
                return
            end
        end
    end
    if Amumu.IsEnabledAndReady("E", mode) then
        for k, wTarget in ipairs(Amumu.GetTargets(spells.E.Range)) do
            if spells.E:Cast() then
                return
            end
        end
    end
    if Amumu.IsEnabledAndReady("R", mode) then 
        if spells.R:IsReady() and #TS:GetTargets(spells.R.Range, true) >= Menu.Get("Combo.R") then
                spells.R:Cast()
                return
        end
    end
end
---@param source AIBaseClient
---@param spell SpellCast
function Amumu.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.IntQ") and spells.E:IsReady() and danger > 2) then return end

    spells.Q:CastOnHitChance(source, Enums.HitChance.VeryHigh)
end
function Amumu.Auto()
   
end
function Amumu.Combo()  Amumu.ComboLogic("Combo")  end
function Amumu.Waveclear()
    local Q = Menu.Get("Clear.UseQ")
    local W = Menu.Get("Clear.UseW")
    local E = Menu.Get("Clear.UseE")
    if Q and spells.Q:IsReady() then 
          for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and spells.Q:IsInRange(minion) then
                    if spells.Q:Cast(minion) then 
                        return
                    end
                end 
            end                       
        end
    end
    if W and spells.W:IsReady() then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
          local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and spells.W:IsInRange(minion) then
                    if not Player:GetBuff("AuraOfDespair") then
                    spells.W:Cast() return
                    end
                end
            end    
        end
    end
    if E and spells.E:IsReady() then 
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
          local minion = v.AsAI
            if minion then
                if minion.IsTargetable and minion.MaxHealth > 6 and spells.E:IsInRange(minion) then
                  spells.E:Cast()  
                end 
            end                       
        end
    end
end

function Amumu.LoadMenu()

    Menu.RegisterMenu("StormAmumu", "Storm Amumu", function()
        Menu.ColumnLayout("cols", "cols", 1, true, function()
            Menu.ColoredText("Combo", 0xFFD700FF, true)
            Menu.Checkbox("Combo.UseQ",   "Use [Q]", true) 
            Menu.Slider("Combo.ChanceQ", "HitChance [Q]", 0.7, 0, 1, 0.05)   
            Menu.Checkbox("Combo.UseW",   "Use [W]", true)
            Menu.Checkbox("Combo.UseE",   "Use [E]", true)
            Menu.Checkbox("Combo.UseR",   "Use [R]", true)
            Menu.Slider("Combo.R", "Min Hit", 2, 1, 5, 1) 
        end)
        Menu.Separator()
        Menu.ColoredText("Jungle", 0xFFD700FF, true)
        Menu.Checkbox("Clear.UseQ",   "Use [Q] Jungle", true) 
        Menu.Checkbox("Clear.UseW",   "Use [W] Jungle", true) 
        Menu.Checkbox("Clear.UseE",   "Use [E] Jungle", true) 
        Menu.Separator()

        Menu.ColoredText("Misc Options", 0xFFD700FF, true)      
        Menu.Checkbox("Misc.IntQ", "Use [Q] Interrupt", true)   
        Menu.Separator()

        Menu.ColoredText("Draw Options", 0xFFD700FF, true)
        Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range")
        Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)    
        Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range")
        Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)  
        Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range")
        Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)    
        Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range")
        Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)     
    end)     
end

function OnLoad()
    Amumu.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Amumu[eventName] then
            EventManager.RegisterCallback(eventId, Amumu[eventName])
        end
    end    
    return true
end
