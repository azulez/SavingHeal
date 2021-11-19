-- SavingHeal

local L_ANY = 0
local L_DEBUG = 1
local MODE = "off"

-- Saving Heal Internals
local announce_delay = 5  -- Target must survive this long to announce
local minFilter = 0  -- Heal must be at least this size
local staleFilter = 20  -- Damage must come with X settings of last heal to be recorded
local groupFilter = true  -- Only watch your group


local last_heal_table
local savingHealCount
local lowHPRecord

function SH_ClearData()
	last_heal_table = {}
	savingHealCount = {}
	lowHPRecord = {500, "None", "None"}
end

SH_ClearData()


SLASH_SAVINGHEAL1 = '/savingheal'
SLASH_SAVINGHEAL2 = '/sh'

SlashCmdList["SAVINGHEAL"] = function(msg)
    if msg == 'test' then
	    -- Call some function to test it out.
		SH_TEST()
		do return end
	end
	if msg == 'report' then
		DoReport(3)
		do return end
	end

	MODE = msg
	if msg == nil then
		print("Available modes: off, self, say, party, raid")
	end
	print(string.format("SavingHeal mode set to: %s", MODE))
end

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", function(self, event)
	self:OnEvent(event, CombatLogGetCurrentEventInfo())
end)

function SavingHealRoutine(event, ...)
	local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
	
	if not destName then
		do return end
	end
	if groupFilter and not (UnitInParty(destName) or UnitInRaid(destName)) then
		sh_msg(L_DEBUG, "Event skipped due to groupFilter")
		do return end  -- Skip NPCs
	end

	local target_health = UnitHealth(destName)  -- Do this as quickly as possible?
	-- Possible filled-out values
	local spellId, spellName, spellSchool
	local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand
	
	--  Different subevents populate different values!
	if subevent == "SPELL_HEAL" then
		spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(12, ...)
		--  Add heal to table
		last_heal_table[destName] = { amount - overhealing, sourceName, spellName, timestamp }
		sh_msg(L_DEBUG, string.format("Added heal [%s] - (%s, %s) [%s, %s]", destName, amount, sourceName, spellName, timestamp))
		do return end
	elseif subevent == "SWING_DAMAGE" then
		amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = select(12, ...)
		sh_msg(L_DEBUG, string.format("Swing damage: %s on %s from %s", amount, destName, sourceName))
	elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
		spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = select(12, ...)
		sh_msg(L_DEBUG, string.format("Spell damage: %s on %s from %s", amount, destName, sourceName))
	else
		do return end
	end

	--  Ignore event if there were no prior heals
	if last_heal_table[destName] == nil then
		sh_msg(L_DEBUG, string.format("No healing information for %s", destName))
		do return end
	end
	
	-- If we get here, it was a swing or spell
	if overkill > 0 then
		do return end -- RIP
	end
	
	-- NEXT SECTION
	
	-- Assign variables so the code looks better.
	local hitAmount = amount
	local lastHealAmount, lastHealer, lastHealSpell, lastHealTime
	lastHealAmount, lastHealer, lastHealSpell, lastHealTime = unpack(last_heal_table[destName])
	local healAge = timestamp - lastHealTime
	local former_hp = target_health - lastHealAmount
	
	sh_msg(L_DEBUG, "Secondary assignment done")
	
	
	
	
	--  Debug info
	sh_msg(L_DEBUG, string.format("Hit: %s", hitAmount))
	sh_msg(L_DEBUG, string.format("Heal info: %s %s %s %s", lastHealAmount, lastHealer, lastHealSpell, lastHealTime))
	sh_msg(L_DEBUG, string.format("Calculated values: %s %s", former_hp, healAge))
	
	if former_hp - amount < 1 then
		
		-- Filter out weird heals
		if timestamp - lastHealTime > staleFilter then
			sh_msg(L_DEBUG, string.format("Stale heal..  Last was %s s ago", healAge))
			do return end
		end

		if former_hp < 1 then
			sh_msg(L_DEBUG, "Negative former_hp detected...")
			do return end
		end
		
		if lastHealAmount < minFilter then
			sh_msg(L_DEBUG, string.format("Heal was too small. (%s)", lastHealAmount))
			do return end
		end
		
		sh_msg(L_DEBUG, "Clutch heal detected!")
			
		--  We got through filters.. queue message!
		C_Timer.After(announce_delay, function() DelayedSavingHealAnnounce(destName, former_hp, hitAmount,
			lastHealer, lastHealSpell, lastHealAmount) end)
	end
	
	-- We got a hit, and no saving heal so remove heal.
	last_heal_table[destName] = nil
end

function DelayedSavingHealAnnounce(...)
	local destName, former_hp, hitAmount, lastHealer, lastHealSpell, lastHealAmount = ...
	
	if UnitHealth(destName) < 1 then
		sh_msg(L_DEBUG, string.format("%s was saved by %s but then died anyways.", destName, lastHealer))
		do return end
	end
	
	--  They're still alive!  Record and print message!
	RecordSavingHeal(lastHealer)
	local savingHealString = "**SHOUT OUT** %s for having a Saving [%s(+%s)] on %s! [%s (pre-heal hp) - %s (hit)]"
	sh_msg(L_ANY, string.format(savingHealString,
		lastHealer, lastHealSpell, lastHealAmount, destName, former_hp, hitAmount))

end

function SH_TEST()
	MODE = "debug"
	SH_TEST_LoadFakeData()
	DoReport(10)
	RecordSavingHeal('foo')
	RecordSavingHeal('drizzt')
	DoReport(10)
end

function RecordSavingHeal(name)
	savingHealCount[name] = (savingHealCount[name] or 0) + 1
end

function SH_TEST_LoadFakeData()
	savingHealCount['asdf'] = 1
	savingHealCount['jkl'] = 2
	savingHealCount['derp'] = 5
	savingHealCount['foo'] = 3
	savingHealCount['bar'] = 3
	
	lowHPRecord = {123, "Healer", "Patient"}
end


function DoReport(length)
	length = length or 3
	local report = {}
	
    for name,saves in pairs(savingHealCount) do table.insert(report, {name, saves}) end
    table.sort(report, function(a, b) return a[2] > b[2] end)
	
	sh_msg(L_ANY, '-- Top Saving Heal Shout-Outs! --')
	for i=1, math.min(table.getn(report), length) do
		sh_msg(L_ANY, string.format("%s. %s: %s",
			i, report[i][1], report[i][2])) 
	end
	sh_msg(L_ANY, string.format("Low HP Heal Record:  %s -> %shp [%s]",
		lowHPRecord[2], lowHPRecord[1], lowHPRecord[3]
	)) 
end

function TightHealRoutine(event, ...)
	local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
	
	if not destName then
		do return end
	end
	if groupFilter and not (UnitInParty(destName) or UnitInRaid(destName)) then
		sh_msg(L_DEBUG, "Event skipped due to groupFilter")
		do return end  -- Skip NPCs
	end
	
	local target_health = UnitHealth(destName)  -- Do this as quickly as possible?
	local spellId, spellName, spellSchool
	local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand
	
	if subevent == "SPELL_HEAL" then
		spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(12, ...)
		
		if InCombatLockdown() and target_health > 0 and target_health < lowHPRecord[1] then
			local lowHealString = "**New Record** %s beat %s(%shp) by landing a heal on %s(%shp)"
			
			--print(string.format(lowHealString,
			sh_msg(L_ANY, string.format(lowHealString,
				sourceName, lowHPRecord[2], lowHPRecord[1], destName, target_health))
			lowHPRecord = {target_health, sourceName, destName}
		end
	end
end

function f:OnEvent(event, ...)
	--local timestamp, subevent = ...
	SavingHealRoutine(event, CombatLogGetCurrentEventInfo())
	TightHealRoutine(event, CombatLogGetCurrentEventInfo())
end

function sh_msg(LEVEL, msg)
	if MODE == "off" then
		do return end
	elseif LEVEL == L_DEBUG and MODE == "debug" then
		print("SH: ", msg)
	elseif LEVEL == L_ANY then
		if MODE == "debug" or MODE == "self" then
			print(msg)
		elseif MODE == "say" then
			if IsInInstance() then
				SendChatMessage(msg, "SAY")
			else
				print(string.format("Say Disabled: %s", msg))
			end
		elseif MODE == "party" then
			SendChatMessage(msg, "PARTY")
		elseif MODE == "raid" then
			SendChatMessage(msg, "RAID")
		end
	end
end

print(string.format("SavingHeal Loaded!  (MODE is '%s')", MODE))
