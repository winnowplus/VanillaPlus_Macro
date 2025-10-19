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

