NugHealth = CreateFrame("Frame","NugHealth", UIParent)

NugHealth:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
NugHealth:RegisterEvent("ADDON_LOADED")

local DB_VERSION = 1
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax


local vengeanceMinRange = 7000
local vengeanceMaxRange = 200000
local vengeanceRedRange = 60000

local defaults = {
    -- anchor = {
        point = "CENTER",
        relative_point = "CENTER",
        frame = "UIParent",
        x = 0,
        y = 0,
    -- }
}

local function SetupDefaults(t, defaults)
    for k,v in pairs(defaults) do
        if type(v) == "table" then
            if t[k] == nil then
                t[k] = CopyTable(v)
            else
                SetupDefaults(t[k], v)
            end
        else
            if t[k] == nil then t[k] = v end
        end
    end
end
local function RemoveDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if type(t[k]) == 'table' and type(v) == 'table' then
            RemoveDefaults(t[k], v)
            if next(t[k]) == nil then
                t[k] = nil
            end
        elseif t[k] == v then
            t[k] = nil
        end
    end
    return t
end

local function PercentColor(percent)
    if percent <= 0 then
        return 0, 1, 0
    elseif percent <= 0.5 then
        return percent*2, 1, 0
    elseif percent >= 1 then
        return 1, 0, 0
    else
        return 1, 2 - percent*2, 0
    end
end

function NugHealth.ADDON_LOADED(self,event,arg1)
    if arg1 == "NugHealth" then
        NugHealthDB = NugHealthDB or {}
        SetupDefaults(NugHealthDB, defaults)

        self:Create()

        -- self:RegisterUnitEvent("UNIT_HEALTH", "player")
        -- self:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
        -- if select(2, UnitClass"player") == "MONK" then
            -- self:SetScript("OnUpdate", NugHealth.StaggerOnUpdate)
        -- end
        -- self:RegisterUnitEvent("UNIT_ATTACK_POWER", "player");
        -- self:RegisterUnitEvent("UNIT_RAGE", "player");
        -- self:RegisterUnitEvent("UNIT_AURA", "player");
        NugHealth:SPELLS_CHANGED()


        self:RegisterEvent("PLAYER_LOGIN")
        self:RegisterEvent("PLAYER_LOGOUT")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")

        self:RegisterEvent("SPELLS_CHANGED")

        SLASH_NUGHEALTH1= "/nughealth"
        SLASH_NUGHEALTH2= "/nhe"
        SlashCmdList["NUGHEALTH"] = self.SlashCmd
    end
end

function NugHealth.PLAYER_LOGOUT(self, event)
    RemoveDefaults(NugHealthDB, defaults)
end

function NugHealth.PLAYER_LOGIN(self, event)
    -- self:UNIT_MAXHEALTH()
    self:UNIT_HEALTH()
    -- self:UNIT_AURA()
    if InCombatLockdown() then self:Show() else self:Hide() end
end

function NugHealth.SPELLS_CHANGED(self, event)
    local _, class = UnitClass("player")
    local spec = GetSpecialization()
    if  (class == "WARRIOR" and spec == 3) or 
        (class == "DEATHKNIGHT" and spec == 1) or 
        (class == "PALADIN" and spec == 2) or 
        (class == "DRUID" and spec == 3) or 
        (class == "MONK" and spec == 1)
    then
        self:Enable()
    else
        self:Disable()
    end
end

function NugHealth:Disable()
    self:UnregisterAllEvents()
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:SetScript("OnUpdate", nil)
    self:Hide()
    self.isDisabled = true
end

function NugHealth.ResolveOnUpdate(self, time)
    self._elapsed = (self._elapsed or 0) + time
    if self._elapsed < 0.3 then return end
    self._elapsed = 0

    local name, _,_, count, _, duration, expirationTime, caster, _,_, spellID, _, _, _, selfhealIncrease = UnitBuff("player", self.resolveName)

    local vp = (selfhealIncrease-10)/180

    self.resolve:SetValue(vp)
    self.resolve:SetStatusBarColor(PercentColor(vp*1.5))
end

function NugHealth.StaggerOnUpdate(self, time)
    self._elapsed = (self._elapsed or 0) + time
    if self._elapsed < 0.1 then return end
    self._elapsed = 0

    local stagger = UnitStagger("player")/UnitHealthMax("player")
    -- local name, _,_, count, _, duration, expirationTime, caster, _,_,
               -- spellID, _, _, _, attackPowerIncrease, val2 = UnitBuff("player", )
    self.resolve:SetValue(stagger)
    self.resolve:SetStatusBarColor(PercentColor(stagger*1.5))
end

function NugHealth.UNIT_ABSORB_AMOUNT_CHANGED(self, event, unit)
    self.absorb:SetValue(UnitGetTotalAbsorbs(unit)/ UnitHealthMax(unit))
end

function NugHealth:Enable()
    self:RegisterUnitEvent("UNIT_HEALTH", "player")
    -- self:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    self:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")

    self.resolveName = GetSpellInfo(158300)
    if self.resolveName then
        self:SetScript("OnUpdate", NugHealth.ResolveOnUpdate)
    end
    
    if select(2, UnitClass"player") == "MONK" then
        self:SetScript("OnUpdate", NugHealth.StaggerOnUpdate)
        self.power.auraname = GetSpellInfo(115307)
        self.power:SetColor(38/255, 221/255, 163/255)
        self:RegisterUnitEvent("UNIT_AURA", "player");
    end

    if select(2, UnitClass"player") == "WARRIOR" then
        self.power.auraname = GetSpellInfo(132404)
        self.power:SetColor(80/255, 83/255, 150/255)
        self:RegisterUnitEvent("UNIT_AURA", "player");
    end
    -- self:RegisterUnitEvent("UNIT_ATTACK_POWER", "player");
    -- self:RegisterUnitEvent("UNIT_RAGE", "player");

    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:PLAYER_LOGIN()
    self.isDisabled = nil
end


-- do
--     local vengeanceName = GetSpellInfo(132365)
--     local vengeanceAttackPower = 0

    -- local function CalculateEstimatedAbsorbValue(rage)
    --     local baseAttackPower, positiveBuff, negativeBuff = UnitAttackPower("player")
    --     local attackPower = baseAttackPower + positiveBuff + negativeBuff
    --     local _, strength = UnitStat("player", 1)
    --     local _, stamina = UnitStat("player", 3)
    --     local rageMultiplier = max(20, min(60, rage)) / 60.0
    --     return max(2 * (attackPower - 2 * strength), stamina * 2.5) * rageMultiplier
    -- end

    -- function NugHealth:UpdateAbsorbValue() --absorbForced)
    --     -- local rage = UnitPower("player")
    --     -- local absorb = CalculateEstimatedAbsorbValue(rage)
    --     -- absorb = absorbForced or absorb
    --     -- self.power:SetValue(absorb)
    --     self.power:SetValue(vengeanceAttackPower)
    --     local vRate = vengeanceAttackPower / vengeanceRedRange
    --     self.power:SetStatusBarColor(PercentColor(vRate))
    -- end
    -- function NugHealth.UNIT_ATTACK_POWER(self, event)
        -- self:UpdateAbsorbValue()
    -- end
    -- function NugHealth.UNIT_POWER(self,event,unit,powertype)
        -- if powertype == "RAGE" then
            -- self:UpdateAbsorbValue()
        -- end
    -- end

function NugHealth.UNIT_AURA(self, event)
        local name, _,_, count, _, duration, expirationTime, caster, _,_, spellID = UnitBuff("player", self.power.auraname)

        if name then
            self.power.startTime = expirationTime - duration
            self.power.endTime = expirationTime
            self.power:SetMinMaxValues(0, duration)
            self.power:Show()
        else
            self.power:Hide()
        end
end
-- end

function NugHealth.UNIT_HEALTH(self, event)
    local h = UnitHealth("player")
    local mh = UnitHealthMax("player")
    if mh == 0 then return end
    local vp = h/mh

    self.health:SetValue(vp)
    if vp >= self.healthlost.currentvalue or not UnitAffectingCombat("player") then
        self.healthlost.currentvalue = vp
        self.healthlost.endvalue = vp
        self.healthlost:SetValue(vp)
    else
        self.healthlost.endvalue = vp
    end

        if vp < 0.2 then
            self.glowanim:SetDuration(0.2)
            if not self.glow:IsPlaying() then
                self.glowanim.pending_stop = false
                self.glow:Play()
            end
        elseif vp < 0.35 then
            self.glowanim:SetDuration(0.4)
            if not self.glow:IsPlaying() then
                self.glowanim.pending_stop = false
                self.glow:Play()
            end
        else
            if self.glow:IsPlaying() then
                self.glowanim.pending_stop = true
            end
        end

end

-- function NugHealth.UNIT_MAXHEALTH(self, event)
--     local max = UnitHealthMax("player")
--     self.healthmax = max
--     self.health:SetMinMaxValues(0, max)
--     self.healthlost:SetMinMaxValues(0, max)
--     -- self.power:SetMinMaxValues(0, max)
-- end

function NugHealth.PLAYER_REGEN_DISABLED(self, event)
    self:Show()
end
function NugHealth.PLAYER_REGEN_ENABLED(self, event)
    self:Hide()
end

function NugHealth.Create(self)
    self:SetWidth(20)
    self:SetHeight(80)
    local backdrop = {
        bgFile = "Interface\\Addons\\NugHealth\\white", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }
    self:SetBackdrop(backdrop)
    self:SetBackdropColor(0, 0, 0, 1)

    local texture = [[Interface\AddOns\NugHealth\gradient]]
    local hp = CreateFrame("StatusBar", nil, self)
    hp:SetAllPoints(self)
    hp:SetStatusBarTexture(texture)
    hp:GetStatusBarTexture():SetDrawLayer("ARTWORK",-6)
    hp:SetMinMaxValues(0,1)
    hp:SetOrientation("VERTICAL")
    hp:SetValue(50)
    
    local hpbg = hp:CreateTexture(nil,"ARTWORK",nil,-8)
    hpbg:SetAllPoints(hp)
    hpbg:SetTexture(texture)
    hp.bg = hpbg

    local hplost = CreateFrame("StatusBar", nil, self)
    hplost:SetAllPoints(self)
    hplost:SetStatusBarTexture([[Interface\AddOns\NugHealth\gradient]])
    hplost:GetStatusBarTexture():SetDrawLayer("ARTWORK",-7)
    hplost:SetMinMaxValues(0,1)
    hplost:SetOrientation("VERTICAL")
    hplost:SetValue(0)
    hplost:SetStatusBarColor(.8,0,0, 1)

    hplost.currentvalue = 0
    hplost:SetScript("OnUpdate", function(self, time)
        self._elapsed = (self._elapsed or 0) + time
        if self._elapsed < 0.05 then return end
        self._elapsed = 0
        local diff = self.currentvalue - self.endvalue
        if diff > 0 then
            local d = (diff > .10) and 0.007 or 0.0035
            self.currentvalue = self.currentvalue - d
            self:SetValue(self.currentvalue)
        end
    end)

    self.healthlost = hplost

    local c = RAID_CLASS_COLORS.WARRIOR
    hp:SetStatusBarColor(c.r*.2, c.g*.2, c.b*.2)
    hp.bg:SetVertexColor(c.r, c.g, c.b)

    self.health = hp


    local at = self:CreateTexture(nil,"BACKGROUND", nil, -1)
    at:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    at:SetVertexColor(1, .2, .2)
    do
    local a,b,c,d = 0.00781250,0.50781250,0.27734375,0.52734375
    at:SetTexCoord(a,d,b,d,a,c,b,c)
    end

    local hmul,vmul = 2, 1.65
    if vertical then hmul, vmul = vmul, hmul end
    at:SetWidth(self:GetWidth()*hmul)
    at:SetHeight(self:GetHeight()*vmul)
    at:SetPoint("CENTER",self,"CENTER",0,0)
    at:SetAlpha(0)
    
    local sag = at:CreateAnimationGroup()
    sag:SetLooping("BOUNCE")
    local sa1 = sag:CreateAnimation("Alpha")
    sa1:SetChange(1)
    sa1:SetDuration(0.3)
    sa1:SetOrder(1)
    sa1:SetScript("OnFinished", function(self)
        if self.pending_stop then self:GetParent():Stop() end
    end)

    self.glow = sag
    self.glowanim = sa1


    local stagger = CreateFrame("Frame", nil, self)
    stagger:SetParent(self)
    stagger:SetPoint("BOTTOMRIGHT",self,"BOTTOMRIGHT",0,0)
    stagger:SetWidth(6)

    local at = stagger:CreateTexture(nil, "ARTWORK", nil, -4)
    at:SetTexture[[Interface\AddOns\NugHealth\white]]
    -- at:SetVertexColor(.7, .7, 1, 1)
    stagger.texture = at
    at:SetAllPoints(stagger)

    local atbg = stagger:CreateTexture(nil, "ARTWORK", nil, -5)
    atbg:SetTexture[[Interface\AddOns\NugHealth\white]]
    atbg:SetVertexColor(0,0,0,1)
    atbg:SetPoint("TOPLEFT", at, "TOPLEFT", -1,1)
    atbg:SetPoint("BOTTOMRIGHT", at, "BOTTOMRIGHT", 1,-1)

    stagger.maxheight = self:GetHeight()
    stagger.SetValue = function(self, p)
        if p > 1 then p = 1 end
        if p < 0 then p = 0 end
        if p == 0 then self:Hide() else self:Show() end
        self:SetHeight(p*self.maxheight)
    end
    stagger:SetValue(0)

    stagger.SetStatusBarColor = function(self, r,g,b)
        self.texture:SetVertexColor(r,g,b)
    end

    self.resolve = stagger



    local absorb = CreateFrame("Frame", nil, self)
    absorb:SetParent(self)
    absorb:SetPoint("TOPLEFT",self,"TOPLEFT",-3,0)
    absorb:SetWidth(4)

    local at = absorb:CreateTexture(nil, "ARTWORK", nil, -4)
    at:SetTexture[[Interface\AddOns\NugHealth\white]]
    at:SetVertexColor(.7, .7, 1, 1)
    absorb.texture = at
    at:SetAllPoints(absorb)

    local atbg = absorb:CreateTexture(nil, "ARTWORK", nil, -5)
    atbg:SetTexture[[Interface\AddOns\NugHealth\white]]
    atbg:SetVertexColor(0,0,0,1)
    atbg:SetPoint("TOPLEFT", at, "TOPLEFT", -1,1)
    atbg:SetPoint("BOTTOMRIGHT", at, "BOTTOMRIGHT", 1,-1)

    absorb.maxheight = self:GetHeight()
    absorb.SetValue = function(self, p)
        if p > 1 then p = 1 end
        if p < 0 then p = 0 end
        if p == 0 then self:Hide() else self:Show() end
        self:SetHeight(p*self.maxheight)
    end
    absorb:SetValue(0)

    absorb.SetStatusBarColor = function(self, r,g,b)
        self.texture:SetVertexColor(r,g,b)
    end

    self.absorb = absorb


    local powerbar = CreateFrame("StatusBar", nil, self)
    powerbar:SetWidth(4)
    powerbar:SetPoint("TOPLEFT",self,"TOPRIGHT",1,0)
    powerbar:SetPoint("BOTTOMLEFT",self,"BOTTOMRIGHT",1,0)
    powerbar:SetStatusBarTexture("Interface\\Addons\\NugHealth\\white")
    powerbar:GetStatusBarTexture():SetDrawLayer("ARTWORK",-2)
    powerbar:SetOrientation("VERTICAL")
    powerbar:SetMinMaxValues(0, 1)
    powerbar:SetValue(0)
    local backdrop = {
        bgFile = "Interface\\Addons\\NugHealth\\white", tile = true, tileSize = 0,
        insets = {left = -1, right = -2, top = -2, bottom = -2},
    }
    powerbar:SetBackdrop(backdrop)
    powerbar:SetBackdropColor(0, 0, 0, 1)
    
    local pbbg = powerbar:CreateTexture(nil,"ARTWORK",nil,-3)
    pbbg:SetAllPoints(powerbar)
    pbbg:SetTexture("Interface\\Addons\\NugHealth\\white")
    powerbar.bg = pbbg

    powerbar.SetColor = function(self, r,g,b)
        self:SetStatusBarColor(r,g,b)
        self.bg:SetVertexColor(r*.3,g*.3,b*.3)
    end

    powerbar:SetScript("OnUpdate", function(self, time)
        self:SetValue( self.endTime - GetTime())
    end)

    powerbar:Hide()

    self.power = powerbar


    
    self:EnableMouse(false)
    self:RegisterForDrag("LeftButton")
    self:SetMovable(true)
    self:SetScript("OnDragStart",function(self) self:StartMoving() end)
    self:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing();
        local p = NugHealthDB
        p.point, p.frame, p.relative_point, p.x, p.y = self:GetPoint(1)
    end)

    local p = NugHealthDB
    self:SetPoint(p.point, p.frame, p.relative_point, p.x, p.y)
    self:Hide()

    return self
end


local ParseOpts = function(str)
    local t = {}
    local capture = function(k,v)
        t[k:lower()] = tonumber(v) or v
        return ""
    end
    str:gsub("(%w+)%s*=%s*%[%[(.-)%]%]", capture):gsub("(%w+)%s*=%s*(%S+)", capture)
    return t
end
NugHealth.Commands = {
    ["unlock"] = function(v)
        NugHealth:EnableMouse(true)
        NugHealth:Show()
    end,
    ["lock"] = function(v)
        NugHealth:EnableMouse(false)
        local self = NugHealth
        if InCombatLockdown() then self:Show() else self:Hide() end
    end,
    -- ["set"] = function(v)
        -- local p = ParseOpts(v)
    -- end
}

function NugHealth.SlashCmd(msg)
    k,v = string.match(msg, "([%w%+%-%=]+) ?(.*)")
    if not k or k == "help" then 
        print([[Usage:
          |cff55ffff/nhe unlock|r
          |cff55ff55/nhe lock|r]]
        )
    end
    if NugHealth.Commands[k] then
        NugHealth.Commands[k](v)
    end    
end


