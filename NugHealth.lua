NugHealth = CreateFrame("Frame","NugHealth", UIParent)

NugHealth:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)

NugHealth:RegisterEvent("ADDON_LOADED")

local LibCLHealth = LibStub("LibCombatLogHealth-1.0")
local DB_VERSION = 1
local UnitHealth = UnitHealth
local UnitHealthOriginal = UnitHealth
local UnitHealthMax = UnitHealthMax
local lowhpcolor = false


local vengeanceMinRange = 7000
local vengeanceMaxRange = 200000
local vengeanceRedRange = 60000


local stagerSide = "LEFT"
local staggerMul = 1
local resolveMaxPercent = 30
-- local staggerScaleFactor
local playerGUID = 0

local defaults = {
    -- anchor = {
        height = 80,
        width = 20,
        absorb_width = 5,
        point = "CENTER",
        relative_point = "CENTER",
        frame = "UIParent",
        classcolor = false,
        allSpecs = false,
        healthcolor = { 0.78, 0.61, 0.43 },
        x = 0,
        y = 0,
        showResolve = true,
        resolveLimit = 180,
        staggerLimit = 100,
        useCLH = true,
		lowhpcolor = true,
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

        resolveMaxPercent = NugHealthDB.resolveLimit
        staggerMul = 100/NugHealthDB.staggerLimit

		lowhpcolor = NugHealthDB.lowhpcolor

        NugHealth:SPELLS_CHANGED()


        self:RegisterEvent("PLAYER_LOGOUT")
        -- self:RegisterEvent("PLAYER_LOGIN") --registered in :Enable()
        -- self:RegisterEvent("PLAYER_REGEN_ENABLED")
        -- self:RegisterEvent("PLAYER_REGEN_DISABLED")

        self:RegisterEvent("SPELLS_CHANGED")

        SLASH_NUGHEALTH1= "/nughealth"
        SLASH_NUGHEALTH2= "/nhe"
        SlashCmdList["NUGHEALTH"] = self.SlashCmd

		local f = CreateFrame('Frame', nil, InterfaceOptionsFrame)
		f:SetScript('OnShow', function(self)
			self:SetScript('OnShow', nil)

			if not NugHealth.optionsPanel then
				NugHealth.optionsPanel = NugHealth:CreateGUI()
			end
		end)
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
    if  NugHealthDB.allSpecs or
       ((class == "WARRIOR" and spec == 3) or
        (class == "DEATHKNIGHT" and spec == 1) or
        (class == "PALADIN" and spec == 2) or
        (class == "DRUID" and spec == 3) or
        (class == "DEMONHUNTER" and spec == 2) or
        (class == "MONK" and spec == 1))
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
    if self._elapsed < self.timeout then return true end
    self._elapsed = 0

    local v = NugHealth:GatherResolveDamage(5)/UnitHealthMax("player") --damage during past 5seconds relative to max health
	-- ChatFrame4:AddMessage(string.format("CURRENT: %f %d", v, NugHealth:GatherResolveDamage(5)))
    local vp = v*100/resolveMaxPercent

    self.resolve:SetValue(vp)
    self.resolve:SetStatusBarColor(PercentColor(vp*1.5))
end

-- function NugHealth.StaggerOnUpdate(self, time)
--     self._elapsed = (self._elapsed or 0) + time
--     if self._elapsed < 0.1 then return end
--     self._elapsed = 0

--     local stagger = UnitStagger("player")/UnitHealthMax("player")
--     -- local name, _,_, count, _, duration, expirationTime, caster, _,_,
--                -- spellID, _, _, _, attackPowerIncrease, val2 = UnitBuff("player", )
--     self.resolve:SetValue(stagger)
--     self.resolve:SetStatusBarColor(PercentColor(stagger*3))
-- end

function NugHealth.StaggerOnUpdate(self, time)
    if NugHealth.ResolveOnUpdate(self, time) then return end


    -- local stagger = (UnitStagger("player")/UnitHealthMax("player")) * staggerMul
    -- local currentStagger = 0
    -- for i=1,100 do
    --     local name, _,_, count, _, duration, expirationTime, caster, _,_, spellID, _, _, _, st1, staggerValue = UnitDebuff("player", i)
    --     if spellID == 124273 or spellID == 124274 or spellID == 124275 then
    --         currentStagger = staggerValue --*duration
    --     end
    -- end
    local currentStagger = UnitStagger("player")

    local stagger = (currentStagger/UnitHealthMax("player")) * staggerMul
    -- local name, _,_, count, _, duration, expirationTime, caster, _,_,
               -- spellID, _, _, _, attackPowerIncrease, val2 = UnitBuff("player", )
    self.power:SetValue(stagger)
    if stagger == 0 then
        self.power:Hide()
    else
        -- print(stagger, self.power:GetMinMaxValues(), self.power:GetValue())
        self.power:Show()
    end
    self.power:SetColor(PercentColor(stagger))
	self.power:Extend(stagger)
end

local function MakeSetColor(mul)
    return function(self, r,g,b)
        self:SetStatusBarColor(r,g,b)
        self.bg:SetVertexColor(r*mul,g*mul,b*mul)
    end
end


function NugHealth.UNIT_ABSORB_AMOUNT_CHANGED(self, event, unit)
    local a,hm = UnitGetTotalAbsorbs(unit), UnitHealthMax(unit)
    local h = UnitHealth(unit)

    self.absorb:SetValue(a/hm, h/hm)
    self.absorb2:SetValue((h+a)/hm)
end

function NugHealth:Enable()
    playerGUID = UnitGUID("player")

    if LibCLHealth and NugHealthDB.useCLH then
        self:UnregisterEvent("UNIT_HEALTH")
        UnitHealth = LibCLHealth.UnitHealth
        LibCLHealth.RegisterCallback(self, "COMBAT_LOG_HEALTH", function(event, unit, eventType)
            return NugHealth:UNIT_HEALTH(eventType, unit)
        end)
    else
        self:RegisterUnitEvent("UNIT_HEALTH", "player")
        UnitHealth = UnitHealthOriginal
        if LibCLHealth then
            LibCLHealth.UnregisterCallback(self, "COMBAT_LOG_HEALTH")
        end
    end
    -- self:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    self:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")

    if NugHealthDB.showResolve then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self.timeout = 0.3
        self:SetScript("OnUpdate", NugHealth.ResolveOnUpdate)
    end

    if select(2, UnitClass"player") == "MONK" then
        self.timeout = 0.05
        self:SetScript("OnUpdate", NugHealth.StaggerOnUpdate)
        self.power:SetScript("OnUpdate",nil)
        self.power:SetMinMaxValues(0,1)
        self.power:SetValue(0)
        self.power.SetColor = MakeSetColor(0.1)
        -- self.power.auraname = GetSpellInfo(115307)
        self.power:SetColor(38/255, 221/255, 163/255)
        self.power:Show()

        -- self.power.auraname = GetSpellInfo(215479)
        -- self.power:SetColor(80/255, 83/255, 150/255)
        -- self:RegisterUnitEvent("UNIT_AURA", "player");
    end

    -- if select(2, UnitClass"player") == "WARRIOR" then
    --     self.power.auraname = GetSpellInfo(132404)
    --     self.power:SetColor(80/255, 83/255, 150/255)
    --     self:RegisterUnitEvent("UNIT_AURA", "player");
    -- end

    -- if select(2, UnitClass"player") == "DEMONHUNTER" then
    --     self.power.auraname = GetSpellInfo(203819)
    --     self.power:SetColor(.7, 1, 0)
    --     self:RegisterUnitEvent("UNIT_AURA", "player");
    -- end

    -- if select(2, UnitClass"player") == "DEATHKNIGHT" then
    --     -- self.power.auraname = GetSpellInfo(171049)
    --     -- self.power:SetColor(.7, 0, 0)
    --     -- self:RegisterUnitEvent("UNIT_AURA", "player");
    -- end

    -- if select(2, UnitClass"player") == "PALADIN" then
    --     self.power.auraname = GetSpellInfo(132403)
    --     self.power:SetColor( 226/255, 35/255, 103/255 )
    --     self:RegisterUnitEvent("UNIT_AURA", "player");
    -- end

    -- if select(2, UnitClass"player") == "DRUID" then
    --     self.power.auraname = GetSpellInfo(192081)
    --     self.power:SetColor(.7, .2, .2)
    --     self:RegisterUnitEvent("UNIT_AURA", "player");
    -- end

    -- self:RegisterUnitEvent("UNIT_ATTACK_POWER", "player");
    -- self:RegisterUnitEvent("UNIT_RAGE", "player");

    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:PLAYER_LOGIN()
    self.isDisabled = nil
end

-- function NugHealth.UNIT_AURA(self, event)
--         local name, _,_, count, _, duration, expirationTime, caster, _,_, spellID = UnitAura("player", self.power.auraname, "HELPFUL")

--         if name then
--             self.power.startTime = expirationTime - duration
--             self.power.endTime = expirationTime
--             self.power:SetMinMaxValues(0, duration)
--             self.power:Show()
--         else
--             self.power:Hide()
--         end
-- end

function NugHealth.UNIT_HEALTH(self, event)
    local h = UnitHealth("player")
    local mh = UnitHealthMax("player")
    local a = UnitGetTotalAbsorbs("player")
    if mh == 0 then return end
    local vp = h/mh

    self.health:SetValue(vp)
    self.absorb:SetValue(a/mh, vp)
    self.absorb2:SetValue((h+a)/mh)
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
				if NugHealthDB.lowhpcolor then self.health:SetColor(1,.1,.1) end
                self.glowanim.pending_stop = false
                self.glow:Play()
            end
        elseif vp < 0.35 then
            self.glowanim:SetDuration(0.4)

            if not self.glow:IsPlaying() then
				if NugHealthDB.lowhpcolor then self.health:SetColor(.9,0,0) end
                self.glowanim.pending_stop = false
                self.glow:Play()
            end
        else
            if self.glow:IsPlaying() then
				self.health:RestoreColor()
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
	local height = NugHealthDB.height
    local width = NugHealthDB.width
    local absorb_width = NugHealthDB.absorb_width

    self:SetWidth(width)
    self:SetHeight(height)
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
    hplost:SetStatusBarTexture([[Interface\AddOns\NugHealth\white]])
    hplost:GetStatusBarTexture():SetDrawLayer("ARTWORK",-7)
    hplost:SetMinMaxValues(0,1)
    hplost:SetOrientation("VERTICAL")
    hplost:SetValue(0)
    hplost:SetStatusBarColor(1,0,0, 1)
    -- hplost:SetStatusBarColor(1,1,1, .9)

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

    hp.SetColor = function(self, r,g,b)
        self:SetStatusBarColor(r*0.2,g*0.2,b*0.2)
        self.bg:SetVertexColor(r,g,b)
    end

	hp.RestoreColor = function(self)
		if NugHealthDB.classcolor then
	        local _, class = UnitClass("player")
	        local c = RAID_CLASS_COLORS[class]
	        self:SetColor(c.r,c.g,c.b)
	    else
	        self:SetColor(unpack(NugHealthDB.healthcolor))
	    end
	end

	hp:RestoreColor()


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
    sa1:SetFromAlpha(0)
    sa1:SetToAlpha(1)
    sa1:SetDuration(0.3)
    sa1:SetOrder(1)
    sa1:SetScript("OnFinished", function(self)
        if self.pending_stop then self:GetParent():Stop() end
    end)

    self.glowtex = at
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
    absorb:SetWidth(absorb_width)

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
    absorb.SetValue = function(self, p, h)
        if p > 1 then p = 1 end
        if p < 0 then p = 0 end
        if p <= 0.015 then self:Hide(); return; else self:Show() end

        local missing_health_height = (1-h)*self.maxheight
        local absorb_height = p*self.maxheight

        self:SetHeight(p*self.maxheight)

        if absorb_height >= missing_health_height then
            self:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", -3 ,0)
        else
            self:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", -3, -(missing_health_height - absorb_height))
        end
    end
    absorb:SetValue(0)

    absorb.SetStatusBarColor = function(self, r,g,b)
        self.texture:SetVertexColor(r,g,b)
    end

    self.absorb = absorb

    local absorb2 = CreateFrame("StatusBar", nil, self)
    absorb2:SetPoint("BOTTOMLEFT",self,"BOTTOMLEFT",0,0)
    absorb2:SetPoint("TOPRIGHT",self,"TOPRIGHT",0,0)
    absorb2:SetStatusBarTexture("Interface\\AddOns\\NugHealth\\shieldtex")
    absorb2:GetStatusBarTexture():SetDrawLayer("ARTWORK",-7)
    absorb2:GetStatusBarTexture():SetVertTile(true)
    absorb2:SetMinMaxValues(0,1)
    absorb2:SetAlpha(0.65)
    absorb2:SetOrientation("VERTICAL")
    absorb2.parent = self
    self.absorb2 = absorb2


    local powerbar = CreateFrame("StatusBar", nil, self)
    powerbar:SetWidth(7)
    -- powerbar:SetPoint("TOPLEFT",self,"TOPRIGHT",1,0)
    powerbar:SetPoint("BOTTOMLEFT",self,"BOTTOMRIGHT",2,0)
	powerbar:SetHeight(height)
	powerbar.baseheight = height
	powerbar.Extend = function(self, v)
		if v > 1.5 then v = 1.5 end
		if v > 1 then
			self:SetHeight(self.baseheight*v)
		else
			self:SetHeight(self.baseheight)
		end
	end

    powerbar:SetStatusBarTexture("Interface\\Addons\\NugHealth\\white")
    powerbar:GetStatusBarTexture():SetDrawLayer("ARTWORK",-2)
    powerbar:SetOrientation("VERTICAL")
    powerbar:SetMinMaxValues(0, 1)
    powerbar:SetValue(0)
    local backdrop = {
        bgFile = "Interface\\Addons\\NugHealth\\white", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
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

    self.Resize = function(self)
        local height = NugHealthDB.height
        local width = NugHealthDB.width
        local absorb_width = NugHealthDB.absorb_width

        self:SetWidth(width)
        self:SetHeight(height)
        self.power:SetHeight(height)
        self.power.baseheight = height
        self.absorb.maxheight = height
        self.absorb:SetWidth(absorb_width)
        self.resolve.maxheight = height
        self.glowtex:SetWidth(width*hmul)
        self.glowtex:SetHeight(height*vmul)
    end



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
	["gui"] = function(v)
        local self = NugHealth
		if not self.optionsPanel then
			self.optionsPanel = self:CreateGUI()
		end
		InterfaceOptionsFrame_OpenToCategory (self.optionsPanel)
		InterfaceOptionsFrame_OpenToCategory (self.optionsPanel)
    end,
    ["resolvelimit"] = function(v, silent)
        local num = tonumber(v)
        if not num or num < 5 or num > 300 then
            num = 180
            print('correct range is 5-500')
        end
        NugHealthDB.resolveLimit = num
        resolveMaxPercent = NugHealthDB.resolveLimit
        if not silent then print("New resolve limit =", num) end
    end,
    ["staggerlimit"] = function(v, silent)
        local num = tonumber(v)
        if not num or num < 5 or num > 100 then
            num = defaults.staggerLimit
            print('correct range is 10-500')
        end
        NugHealthDB.staggerLimit = num
        staggerMul = 100/NugHealthDB.staggerLimit
        if not silent then print("New stagger limit =", num) end
    end,
    ["classcolor"] = function(v)
        NugHealthDB.classcolor = not NugHealthDB.classcolor
        NugHealth.health:RestoreColor()
    end,
	["lowhpcolor"] = function(v)
        NugHealthDB.lowhpcolor = not NugHealthDB.lowhpcolor
        lowhpcolor = NugHealthDB.lowhpcolor
    end,

    ["healthcolor"] = function(v)
        ColorPickerFrame:Hide()
        ColorPickerFrame:SetColorRGB(unpack(NugHealthDB.healthcolor))
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = {unpack(NugHealthDB.healthcolor)} -- otherwise we'll get reference to changed table
        ColorPickerFrame.func = function(previousValues)
            local r,g,b
            if previousValues then
                r,g,b = unpack(previousValues)
            else
                r,g,b = ColorPickerFrame:GetColorRGB();
            end
            NugHealthDB.healthcolor[1] = r
            NugHealthDB.healthcolor[2] = g
            NugHealthDB.healthcolor[3] = b
            NugHealth.health:SetColor(r,g,b)
        end
        ColorPickerFrame.cancelFunc = ColorPickerFrame.func
        ColorPickerFrame:Show()
    end,
    ["lock"] = function(v)
        NugHealth:EnableMouse(false)
        local self = NugHealth
        if InCombatLockdown() then self:Show() else self:Hide() end

    end,

    ["resolve"] = function(v, silent)
        NugHealthDB.showResolve = not NugHealthDB.showResolve
        if not silent then print("show resolve :", NugHealthDB.showResolve) end
        NugHealth:SPELLS_CHANGED()
    end,

    ["allspecs"] = function(v, silent)
        NugHealthDB.allSpecs = not NugHealthDB.allSpecs
        NugHealth:SPELLS_CHANGED()
    end,


    ["useclh"] = function(v)
        NugHealthDB.useCLH = not NugHealthDB.useCLH
        if NugHealthDB.useCLH then
            UnitHealth = UnitHealthOriginal
            NugHealth:RegisterUnitEvent("UNIT_HEALTH", "player")
            LibCLHealth.UnregisterCallback(NugHealth, "COMBAT_LOG_HEALTH")
            print("Fast health updates enabled")
        else
            NugHealth:UnregisterEvent("UNIT_HEALTH")
            UnitHealth = LibCLHealth.UnitHealth
            LibCLHealth.RegisterCallback(NugHealth, "COMBAT_LOG_HEALTH", function(event, unit, eventType)
                return NugHealth:UNIT_HEALTH(eventType, unit)
            end)
            print("Fast health updates disabled")
        end
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
          |cff55ff55/nhe lock|r
          |cffffaaaa/nhe gui|r
          |cff55ff22/nhe useclh - use LibCombatLogHealth
          |cff55ff22/nhe classcolor
          |cff55ff22/nhe healthcolor - use custom color
          |cff55ff22/nhe lowhpcolor
          |cff55ff22/nhe resolve - toggle recent dmg taken|r
          |cff55ff22/nhe resolvelimit <5-500> - damage taken in last 5 sec relative to X max health percent
          |cff55ff22/nhe staggerlimit <10-500> - upper limit of stagger bar in player max health percent|r]]
        )
    end
    if NugHealth.Commands[k] then
        NugHealth.Commands[k](v)
    end
end

do
    local damageHistory = {}
    local math_floor = math.floor
    local roundToInteger = function(v) return math_floor(v*10+.1) end

    function NugHealth:COMBAT_LOG_EVENT_UNFILTERED(
                    event, timestamp, eventType, hideCaster,
                    srcGUID, srcName, srcFlags, srcFlags2,
                    dstGUID, dstName, dstFlags, dstFlags2, ...)

        if dstGUID == playerGUID then
            local amount
            if(eventType == "SWING_DAMAGE") then --autoattack
                amount = (...); -- putting in braces will autoselect the first arg, no need to use select(1, ...);
            elseif(eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "SPELL_DAMAGE"
            or eventType == "DAMAGE_SPLIT" or eventType == "DAMAGE_SHIELD") then
                amount = select(4, ...);
            elseif(eventType == "ENVIRONMENTAL_DAMAGE") then
                amount = select(2, ...);
            -- elseif(eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL") then
            --     amount = select(4, ...) - select(5, ...) -- heal amount - overheal
            --     if amount == 0 then return end
            elseif(eventType == "SPELL_ABSORBED") then
				local numArg = select("#",...)
				if numArg == 8 then
                	amount = select(8, ...);
				else
					amount = select(11, ...);
				end
            end

            if amount then
				-- ChatFrame4:AddMessage(string.format("DAMAGE: %d", amount))
                local ts = roundToInteger(GetTime())
                if not damageHistory[ts] then
                    damageHistory[ts] = amount
                else
                    damageHistory[ts] = damageHistory[ts] + amount
                end
            end
        end
    end


    local lastCheckTime = 0
    local lastAmount
    function NugHealth:GatherResolveDamage(t)
        local timeframeBorder = roundToInteger(GetTime()-t)
        local acc = 0
        if timeframeBorder == lastCheckTime then return lastAmount end

        for ts, amount in pairs(damageHistory) do
            if ts < timeframeBorder then
                damageHistory[ts] = nil
            else
                acc = acc + amount
            end
        end
        lastCheckTime = timeframeBorder
        lastAmount = acc

        return acc
    end
end


function NugHealth:CreateGUI()
	local opt = {
        type = 'group',
        name = "NugHealth Settings",
        order = 1,
        args = {
			unlock = {
				name = "Unlock",
				type = "execute",
				desc = "Unlock anchor for dragging",
				func = function() NugHealth.Commands.unlock() end,
				order = 1,
			},
			lock = {
				name = "Lock",
				type = "execute",
				desc = "Lock anchor",
				func = function() NugHealth.Commands.lock() end,
				order = 2,
			},
            anchors = {
                type = "group",
                name = " ",
                guiInline = true,
                order = 3,
                args = {
					classColor = {
                        name = "Class Color",
                        type = "toggle",
                        get = function(info) return NugHealthDB.classcolor end,
                        set = function(info, v)
							NugHealthDB.classcolor = not NugHealthDB.classcolor
							NugHealth.health:RestoreColor()
						end,
                        order = 1,
                    },
					customcolor = {
                        name = "Custom Color",
                        type = 'color',
						order = 2,
                        get = function(info)
							local r,g,b = unpack(NugHealthDB.healthcolor)
                            return r,g,b
                        end,
                        set = function(info, r, g, b)
							NugHealthDB.classcolor = false
                            NugHealthDB.healthcolor = {r,g,b}
							NugHealth.health:RestoreColor()
                        end,
                    },
                    lowhpcolor = {
                        name = "Low HP Color",
                        type = "toggle",
                        desc = "Change healthbar color when below 35%",
                        get = function(info) return NugHealthDB.lowhpcolor end,
                        set = function(info, v) NugHealth.Commands.lowhpcolor(v, true) end,
                        order = 3,
                    },
                    resolve = {
                        name = "Resolve",
                        type = "toggle",
                        desc = "Show recent damage taken bar",
                        get = function(info) return NugHealthDB.showResolve end,
                        set = function(info, v) NugHealth.Commands.resolve(nil, true) end,
                        order = 4,
                    },
					resolveLimit = {
                        name = "Resolve Limit",
                        type = "range",
						desc = "Damage taken in last 5 sec relative to X max health percent",
						width = "double",
                        get = function(info) return NugHealthDB.resolveLimit end,
                        set = function(info, v)
							NugHealth.Commands.resolvelimit(v, true)
						end,
                        min = 10,
                        max = 500,
                        step = 10,
                        order = 5,
                    },
					clh = {
                        name = "Use LibCombatLogHealth",
                        type = "toggle",
                        desc = "Fast health updates for nerds",
                        get = function(info) return NugHealthDB.useCLH end,
                        set = function(info, v) NugHealth.Commands.useclh() end,
                        order = 6,
                    },
					staggerLimit = {
                        name = "Stagger Limit",
                        type = "range",
						desc = "Upper limit of Monk's Stagger bar in player max health percent",
						width = "double",
                        get = function(info) return NugHealthDB.staggerLimit end,
                        set = function(info, v)
							NugHealth.Commands.staggerlimit(v, true)
						end,
                        min = 20,
                        max = 300,
                        step = 10,
                        order = 7,
                    },

                    width = {
                        name = "Width",
                        type = "range",
                        get = function(info) return NugHealthDB.width end,
                        set = function(info, v)
                            NugHealthDB.width = tonumber(v)
                            NugHealth:Resize()
                        end,
                        min = 10,
                        max = 120,
                        step = 1,
                        order = 8,
                    },
                    height = {
                        name = "Height",
                        type = "range",
                        get = function(info) return NugHealthDB.height end,
                        set = function(info, v)
                            NugHealthDB.height = tonumber(v)
                            NugHealth:Resize()
                        end,
                        min = 30,
                        max = 160,
                        step = 1,
                        order = 9,
                    },
                    absorb_width = {
                        name = "Absorb Width",
                        type = "range",
                        get = function(info) return NugHealthDB.absorb_width end,
                        set = function(info, v)
                            NugHealthDB.absorb_width = tonumber(v)
                            NugHealth:Resize()
                        end,
                        min = 2,
                        max = 12,
                        step = 1,
                        order = 10,
                    },
                    allSpecs = {
                        name = "Show for all specializations",
                        type = "toggle",
                        width = "double",
                        desc = "not just tanks",
                        get = function(info) return NugHealthDB.allSpecs end,
                        set = function(info, v) NugHealth.Commands.allspecs() end,
                        order = 11,
                    },
                },
            }, --
        },
    }

	local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
    AceConfigRegistry:RegisterOptionsTable("NugHealthOptions", opt)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local panelFrame = AceConfigDialog:AddToBlizOptions("NugHealthOptions", "NugHealth")

    return panelFrame
end
