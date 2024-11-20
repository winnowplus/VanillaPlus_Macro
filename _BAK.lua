--是否在移动

local SEM = AceLibrary("SpecialEvents-Movement-2.0")

local function OnMoving()
	return SEM:PlayerMoving()
end


--是否返回上一个目标
if (turecmd == "mouseover" or turecmd == "mo") and target ~= "target" then
    TargetLastTarget()
elseif target == "targettarget" then
    TargetLastTarget()
end

--主副手临时附魔效果
if string.lower(unit) == "mainhand" then
    CM_ScanTip:ClearLines()
    CM_ScanTip:SetInventoryItem(unit,GetInventorySlotInfo("MainHandSlot"))
    for i = 1, CM_ScanTip:NumLines() do
        if string.find((_G["CM_ScanTipTextLeft"..i]:GetText() or ""), aura) then
            return true
        end
    end
end

if string.lower(unit) == "offhand" then
    CM_ScanTip:ClearLines()
    CM_ScanTip:SetInventoryItem(unit, GetInventorySlotInfo("SecondaryHandSlot"))
    for i=1, CM_ScanTip:NumLines() do
        if string.find((_G["CM_ScanTipTextLeft"..i]:GetText() or ""), aura) then
            return true
        end
    end
end