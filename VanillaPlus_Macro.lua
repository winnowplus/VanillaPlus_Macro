local function Mixin(object, ...)
    for index, mixin in ipairs(arg) do
		for key, value in pairs(mixin) do
			object[key] = value;
		end
	end

	return object;
end

local function CreateFromMixins(...)
	return Mixin({}, unpack(arg))
end

function CreateAndInitFromMixin1(mixin, ...)
	local object = CreateFromMixins(mixin);
	object:Init(unpack(arg));
	
	return object;
end

-------

local INTERNAL_OWNER_COUNT		= 0;
local INTERNAL_OWNER_FORMAT		= "VP_INTERNAL_CALLBACK_OWNER_%d";
local INTERNAL_OWNER_PATTERN	= "VP_INTERNAL_CALLBACK_OWNER_%d+";

local CallbackRegistryMixin     = {};

local function GenerateInternalOwner()
	INTERNAL_OWNER_COUNT = INTERNAL_OWNER_COUNT + 1;
	
	return string.format(INTERNAL_OWNER_FORMAT, INTERNAL_OWNER_COUNT);
end

local function IsInternalOwner(owner)
	if(type(owner) == "string") then
		local startIndex, endIndex = string.find(owner, INTERNAL_OWNER_PATTERN);

		return startIndex == 1 and endIndex == string.len(owner);
	else
		return false;
	end
end

function CallbackRegistryMixin:Init()
	self.callbackTable = {};
	self.callbackCount = {};
end

function CallbackRegistryMixin:RegisterCallback(event, func, owner)
	assert(type(event) == "string", "Illegal event: " .. tostring(event) .. ", a string is required.");
	assert(type(func) == "function", "Illegal func: " .. tostring(func) .. ", a function is required.");

	if(owner == nil) then
		owner = GenerateInternalOwner();
	end

	self.callbackTable[event] = self.callbackTable[event] or {};

	if(self.callbackTable[event][owner] == nil) then
		self.callbackCount[event] = (self.callbackCount[event] or 0) + 1;
	end

	self.callbackTable[event][owner] = func;

	return owner;
end

function CallbackRegistryMixin:UnregisterCallback(event, owner)
	assert(type(event) == "string", "Illegal event: " .. tostring(event) .. ", a string is required.");
	assert(owner ~= nil, "Illegal owner: nil.");

	if(self.callbackTable[event] ~= nil and self.callbackTable[event][owner] ~= nil) then
		self.callbackTable[event][owner] = nil;
		self.callbackCount[event] = self.callbackCount[event] - 1;

		if(self.callbackCount[event] == 0) then
			self.callbackTable[event] = nil;
		end
	end
end

function CallbackRegistryMixin:TriggerEvent(event, ...)
	if(self.callbackTable[event] ~= nil) then
		for owner, func in pairs(self.callbackTable[event]) do
			if(IsInternalOwner(owner)) then
				func(unpack(arg));
			else
				func(owner, unpack(arg));
			end
		end
	end
end

-------

local EventRegistryMixin        = CreateFromMixins(CallbackRegistryMixin);

function EventRegistryMixin:Init(eventFrame)
    assert(type(eventFrame) == "table" and type(eventFrame.IsObjectType) == "function" and eventFrame:IsObjectType("Frame") == 1, "Illegal eventFrame: " .. tostring(eventFrame) .. ", a Frame is required.");

    CallbackRegistryMixin.Init(self);
    self.eventFrame = eventFrame;
    self.eventFrame:SetScript("OnEvent", function()
		self:TriggerEvent(event);
	end);
    self.eventFrame:SetScript("OnUpdate", function()
		self:TriggerEvent("UPDATE", GetTime());
	end);
end

function EventRegistryMixin:RegisterFrameEventAndCallback(frameEvent, func, owner)
    local original = self.callbackCount[frameEvent];
    local result = self:RegisterCallback(frameEvent, func, owner);
    local current = self.callbackCount[frameEvent];

    if(current == 1 and original ~= 1) then
        self.eventFrame:RegisterEvent(frameEvent);
    end

    return result;
end

function EventRegistryMixin:UnregisterFrameEventAndCallback(frameEvent, owner)
    local original = self.callbackCount[frameEvent];
    local result = self:UnregisterCallback(frameEvent, owner);
    local current = self.callbackCount[frameEvent];

    if(current == 0 and original ~= 0)then
        self.eventFrame:UnregisterEvent(frameEvent);
    end

    return result;
end

-------

MacroEventRegistry = CreateAndInitFromMixin1(EventRegistryMixin, MacroEventFrame);

local SPELL_COST_PATTERN        = "(%d+)%s*(%S+)";
local SPELL_CACHE               = {};

local SpellMixin		        = {};


function SpellMixin:Init(slot, bookType)
    self.slot = slot;
    self.bookType = bookType;
    self.texture = GetSpellTexture(slot, bookType);
    self.name, self.rank = GetSpellName(slot, bookType);

    if(self.name ~= nil) then
        self.fullname = (self.rank == nil or self.rank == "") and self.name or self.name .. "(" .. self.rank .. ")";
    end
end

function SpellMixin:GetCooldown()
    return GetSpellCooldown(self.slot, self.bookType);
end

function SpellMixin:GetCost()
    MacroTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");
    MacroTooltip:ClearLines();
    MacroTooltip:SetSpell(self.slot, self.bookType);

    local textLeft2 = MacroTooltipTextLeft2 and MacroTooltipTextLeft2:IsShown() and MacroTooltipTextLeft2:GetText() or nil;

    if(textLeft2 ~= nil) then
        local _, _, cost, powerTypeString = string.find(textLeft2, SPELL_COST_PATTERN);

        return cost, powerTypeString;
    end
end

local function GetPlayerSpellCahce()
    local bookType = BOOKTYPE_SPELL;

    if(SPELL_CACHE[bookType] == nil) then
        SPELL_CACHE[bookType] = {};

        for tabIndex = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tabIndex);

            for slot = offset + 1, offset + numSpells do
                local spell = CreateAndInitFromMixin1(SpellMixin, slot, bookType);

                if(spell.name ~= nil) then
                    SPELL_CACHE[bookType][spell.name] = spell;
                    SPELL_CACHE[bookType][spell.fullname] = spell;
                end
            end
        end
    end

    return SPELL_CACHE[bookType];
end

local function GetPetSpellCahce()
    local bookType = BOOKTYPE_PET;

    if(SPELL_CACHE[bookType] == nil) then
        SPELL_CACHE[bookType] = {};

        local slot, spell = 0, nil;

        repeat
            slot = slot + 1;
            spell = CreateAndInitFromMixin1(SpellMixin, slot, bookType);

            if(spell.name ~= nil) then
                SPELL_CACHE[bookType][spell.name] = spell;
                SPELL_CACHE[bookType][spell.fullname] = spell;
            end
        until(spell.name == nil)
    end

    return SPELL_CACHE[bookType];
end

function GetSpell111(spellName, bookType)
    if(bookType == nil) then
        return GetPlayerSpellCahce()[spellName] or GetPetSpellCahce()[spellName];
    elseif(bookType == BOOKTYPE_SPELL) then
        return GetPlayerSpellCahce()[spellName];
    elseif(bookType == BOOKTYPE_PET) then
        return GetPetSpellCahce()[spellName];
    end
end


local function ON_LEARNED_SPELL_IN_TAB()
    SPELL_CACHE[BOOKTYPE_SPELL] = nil;
end

local function ON_PLAYER_PET_CHANGED()
    SPELL_CACHE[BOOKTYPE_PET] = nil;
end

local function ON_UNIT_PET()
    if(arg1 == "player") then
        SPELL_CACHE[BOOKTYPE_PET] = nil;
    end
end

MacroEventRegistry:RegisterFrameEventAndCallback("LEARNED_SPELL_IN_TAB", ON_LEARNED_SPELL_IN_TAB);
MacroEventRegistry:RegisterFrameEventAndCallback("PLAYER_PET_CHANGED", ON_PLAYER_PET_CHANGED);
MacroEventRegistry:RegisterFrameEventAndCallback("UNIT_PET", ON_UNIT_PET);