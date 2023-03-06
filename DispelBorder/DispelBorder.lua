


-- this is where I can easily add localization for Enrage tooltip reading
-- thanks norya for German translation
local ENRAGE_STRING
if (GetLocale() == "enUS") then
	ENRAGE_STRING = "Enrage"
elseif (GetLocale() == "deDE") then 
	ENRAGE_STRING = "Wut"
else
	ENRAGE_STRING = "Enrage"
end


-- our main frame
DispelBorder = LibStub("AceAddon-3.0"):NewAddon("DispelBorder", "AceEvent-3.0")
DispelBorder.version = "1.6.0"
DispelBorder.date = "2011-02-11"


-- our tooltip frame so we can look for enrage buffs
local DBT = CreateFrame("GameTooltip","DispelBorderTooltip", nil, "GameTooltipTemplate")
-- helper function to prep the tooltip for use
local function ResetTooltip()
	DBT:Hide()
	DBT:SetOwner(WorldFrame, "ANCHOR_NONE")
	DBT:ClearLines()
end


-- class name storage
local _, eclass = UnitClass("player")


-- store original versions of API calls
local old_UnitBuff = UnitBuff
local old_UnitAura = UnitAura


-- AceConfig options tree
local options = {
	order = 1,
	name = "DispelBorder",
	type = "group",

	args = {
		General = {
			order = 1,
			type = "group",
			name = "General Settings",
			desc = "General Settings",
			args = {
				desc = {
					type = "description",
					order = 1,
					name = "Version " .. DispelBorder.version,
				},
				desc2 = {
					type = "description",
					order = 2,
					name = "Addon that shows the same border around dispellable buffs that appears around spellstealable buffs.",
				},
				hdr1 = {
					type = "header",
					name = "Target Frame",
					order = 3,
				},
				enabletarget = {
					type = "toggle",
					order = 4,
					width = "double",
					name = "Enabled",
					desc = "Enables/disables border around dispellable buffs",
					get = function() return DispelBorderDB.enabletarget end,
					set = function() DispelBorderDB.enabletarget = not DispelBorderDB.enabletarget end,
				},
				enlargetarget = {
					type = "toggle",
					order = 5,
					width = "double",
					name = "Enlarge Dispellable Enemy Buffs",
					desc = "Shows the dispellable buff as enlarged, as if you had casted it. Will work similarly with any unitframe addon that distinguishes buffs you casted.",
					get = function() return DispelBorderDB.enlargetarget end,
					set = function() DispelBorderDB.enlargetarget = not DispelBorderDB.enlargetarget end,
				},
				enlargesstarget = {
					type = "toggle",
					order = 6,
					width = "double",
					name = "Enlarge Spellstealable Buffs",
					desc = "Enlarges buffs that are actually spellstealable for a mage (mage only)",
					get = function() return DispelBorderDB.enlargesstarget end,
					set = function() DispelBorderDB.enlargesstarget = not DispelBorderDB.enlargesstarget end,
				},
				hdr2 = {
					type = "header",
					name = "Focus Frame",
					order = 7,
				},
				enablefocus = {
					type = "toggle",
					order = 8,
					width = "double",
					name = "Enabled",
					desc = "Enables/disables border around dispellable buffs",
					get = function() return DispelBorderDB.enablefocus end,
					set = function() DispelBorderDB.enablefocus = not DispelBorderDB.enablefocus end,
				},
				enlargefocus = {
					type = "toggle",
					order = 9,
					width = "double",
					name = "Enlarge Dispellable Enemy Buffs",
					desc = "Shows the dispellable buff as enlarged, as if you had casted it. Will work similarly with any unitframe addon that distinguishes buffs you casted.",
					get = function() return DispelBorderDB.enlargefocus end,
					set = function() DispelBorderDB.enlargefocus = not DispelBorderDB.enlargefocus end,
				},
				enlargessfocus = {
					type = "toggle",
					order = 10,
					width = "double",
					name = "Enlarge Spellstealable Buffs",
					desc = "Enlarges buffs that are actually spellstealable for a mage (mage only)",
					get = function() return DispelBorderDB.enlargessfocus end,
					set = function() DispelBorderDB.enlargessfocus = not DispelBorderDB.enlargessfocus end,
				},
				hdr3 = {
					type = "header",
					name = "Technical Options",
					order = 11,
				},
				hdr3desc = {
					type = "description",
					name = "These are fairly technical options. Details are available in the tooltips for each option. It is best to leave these alone if you do not understand them.",
					order = 12,
				},
				hookunitaura = {
					type = "toggle",
					width = "double",
					order = 13,
					name = "Hook UnitAura",
					desc = "Hooks the UnitAura API function. Allows for better support with custom buff frame addons, but impairs right-click-to-cancel support in combat. Since custom buff frame addons generally do not allow this anyway, it is recommended that you only enable this with custom buff frame addons.\n\nDefault unchecked. Requires reload.",
					get = function() return DispelBorderDB.hookunitaura end,
					set = function() DispelBorderDB.hookunitaura = not DispelBorderDB.hookunitaura end,
				},
			}, -- args
		}, -- General
	}, -- args
} -- options


-- we are loaded!
function DispelBorder:OnInitialize()
	-- set defaults if first-time load (or first-time upgrade to 1.6+)
	if not DispelBorderDB or DispelBorderDB.profiles then
		DispelBorderDB = {}
		DispelBorderDB.enabletarget = true
		DispelBorderDB.enlargetarget = false
		DispelBorderDB.enlargesstarget = false
		DispelBorderDB.enablefocus = true
		DispelBorderDB.enlargefocus = false
		DispelBorderDB.enlargessfocus = false
		DispelBorderDB.hookunitaura = false
	end

	-- only hook UnitAura if the option is enabled
	if DispelBorderDB.hookunitaura then
		UnitAura = DispelBorder_UnitAura
	end

	-- installs option panel
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("DispelBorder", options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DispelBorder", nil, nil, "General")

	-- if we are a warlock, we only want to highlight if the fel hunter is out, so register this event to help track
	if (eclass == "WARLOCK") then
		self:RegisterEvent("PET_BAR_UPDATE", "PET_BAR_UPDATE")
	end
end


-- current method hooks UnitAura and UnitBuff, this does the work for both function hooks
-- * returns a modified isStealable flag directly to the UI
-- * also optionally modifies the "unitCaster" return value to make stealable/dispellable buffs appear larger
-- * potentially modifies debuffType (set to "Enrage" if the buff is actually an enrage buff, instead of blank string)
function DispelBorder_CheckBuff(name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, ...)
	-- this is the only one we need specifically, but all may be needed by Enrage-checking code below
	local uid = select(1,...)
	
	-- if unitbuff/unitaura is being called on a unit that isn't target or focus, ignore it and return default data
	if (uid ~= "target" and uid ~= "focus") then
		return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff
	end

	-- if buff is actually stealable (we are a mage) and we should enlarge it
	if (isStealable and ((uid == "target" and DispelBorderDB.enlargesstarget) or (uid == "focus" and DispelBorderDB.enlargessfocus))) then
		unitCaster = "player"

	-- if we have borders enabled for this unit type, this class can dispel enemy buffs in general, and the unit is an enemy
	elseif (((uid == "target" and DispelBorderDB.enabletarget) or (uid == "focus" and DispelBorderDB.enablefocus)) and DispelBorder_CanDispelEnemy() and (UnitIsEnemy("player", uid) or UnitCanAttack("player", uid))) then
		-- check for valid dispellable buff
		
		-- check for Enrage buffs (but only if there is no "known" debuffType and the player can even dispel them)
		-- if it is, change the "debuffType" so 1: our type-checking code is simpler and 2: other addons could potentially get this info (?)
		if (debuffType == "" and DispelBorder_CanDispelEnemyType("Enrage")) then
			ResetTooltip()
			DBT:SetUnitBuff(...) -- pass exact UnitBuff/UnitAura parameters to SetUnitBuff to make things easier
			if (DispelBorderTooltipTextRight1:GetText() == ENRAGE_STRING) then
				debuffType = "Enrage"
			end
		end

		-- if we can dispel it
		if (DispelBorder_CanDispelEnemyType(debuffType)) or spellID == 74396 then
			-- give it a border
			isStealable = 1
			
			-- should we enlarge it?
			if ((uid == "target" and DispelBorderDB.enlargetarget) or (uid == "focus" and DispelBorderDB.enlargefocus)) then
				unitCaster = "player"
			end
		end
	end

	-- return all parameters (debuffType, unitCaster, and isStealable are potentially modified)
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff
end

-- API hook
-- modified in 1.3.9 to work with (unit, spellname, spellrank, filter) in addition to (unit, index, filter)
function DispelBorder_UnitBuff(...)
	-- get default stuff
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff  = old_UnitBuff(...)

	-- if unitbuff is being called on a unit that isn't target or focus, ignore it and return default data
	local uid = select(1,...)
	if (uid ~= "target" and uid ~= "focus") then
		return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff
	end

	-- check actual buff info and return potentially modified info based on if we can dispel or not
	return DispelBorder_CheckBuff(name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, ...)
end

-- API hook
-- modified in 1.3.9 to work with (unit, spellname, spellrank, filter) in addition to (unit, index, filter)
function DispelBorder_UnitAura(...)
	local name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff = old_UnitAura(...)
	
	-- if unitaura is being called on a unit that isn't target or focus, ignore it and return default data
	local uid = select(1,...)
	if (uid ~= "target" and uid ~= "focus") then
		return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff
	end
	
	-- get filter from the vararg list (can be 3 or 4 or non-existant) to see if we want buffs or debuffs
	local filter = nil
	local argc = select('#',...)
	-- if there are 3 args and 2nd is a number (unit, index, filter)
	if (argc == 3 and type(select(2,...)) == "number") then
		filter = select(3,...)
	-- if there are 4 args (unit, name, rank, filter)
	elseif (argc == 4) then
		filter = select(4,...)
	end
	
	-- are we looking for a debuff?
	if (filter and filter:upper():find("HARMFUL")) then
		-- removed debuff check, but the if-block logic we have now works fine so this is still here
		return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff
	-- or a buff? (UnitAura defaults to a "HELPFUL" filter)
	else
		-- check actual buff info and return potentially modified info based on if we can dispel or not
		return DispelBorder_CheckBuff(name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff, ...)
	end
	
	-- should never get here but better safe than sorry
	return name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff
end

-- hook API functions
UnitBuff = DispelBorder_UnitBuff
-- UnitAura hooking has been moved to DispelBorder:OnInitialize()



-- just some helper functions to check dispel type logic

-- monitor warlock pet changes to see if he has a felhunter out or not
local HasDispelPet = false
function DispelBorder:PET_BAR_UPDATE()
	HasDispelPet = false
	if (eclass == "WARLOCK") then
		local num = HasPetSpells()
		if (num) then
			local skillType = GetSpellBookItemInfo("Devour Magic")
			if (skillType) then
				HasDispelPet = true
			end
		end
	end
end

-- can this class dispel enemy buffs at all?
function DispelBorder_CanDispelEnemy()
	-- technically mages can also dispel enemy buffs, but only spellstealable ones and they get the border by default so ignore them
	-- if we include them, they would incorrectly get borders around all magic buffs, even ones they cannot actually spellsteal
	
	-- only true for warriors if prot, and for warlocks if fel hunter is out
	if (eclass == "HUNTER" or eclass == "MAGE" or eclass == "PRIEST" or eclass == "SHAMAN" or eclass == "ROGUE" or eclass == "DRUID" or (eclass == "WARLOCK" and HasDispelPet) or (eclass == "WARRIOR" and GetPrimaryTalentTree() == 3)) then
		return true
	end
	
	return false
end

-- can this class dispel specific enemy buffs (of type t)?
function DispelBorder_CanDispelEnemyType(t)
	if (t == "Magic") then
		-- once again ignoring mages
		
		-- only show for warriors if prot, and for warlock if fel hunter is out
		if (eclass == "HUNTER" or eclass == "PRIEST" or eclass == "SHAMAN" or (eclass == "WARLOCK" and HasDispelPet) or (eclass == "WARRIOR" and GetPrimaryTalentTree() == 3)) then
			return true
		end
	elseif (t == "Enrage") then
		if (eclass == "HUNTER" or eclass == "ROGUE" or eclass == "DRUID") then
			return true
		end
	end
	
	return false
end
