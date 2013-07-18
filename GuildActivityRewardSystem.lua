GARS = LibStub("AceAddon-3.0"):NewAddon("GuildActivityRewardSystem", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function GARS:OnInitialize()
	self:RegisterChatCommand("gars", "ShowFrame")
	self:RegisterChatCommand("guildactivityrewardsystem", "ShowFrame")

	local defaults = {
		global = {
			guilds = {},
			packedGuilds = {}
		}
	}

	self.db = LibStub("AceDB-3.0"):New("GuildActivityRewardSystemDB", defaults)

	self.db.RegisterCallback(self, "OnDatabaseShutdown", "PackDB")

	GARS:UnpackDB()
end

function GARS:UnpackDB()
	local globaldb = self.db.global
	globaldb.guilds = {}
	for _,pg in pairs(globaldb.packedGuilds) do
		local g = GARS.Guild:New(pg.name, pg.packedSnapshots)
		table.insert(globaldb.guilds, g)
	end
	globaldb.packedGuilds = {}
end

function GARS:PackDB()
	local globaldb = self.db.global
	globaldb.packedGuilds = {}
	for _,g in pairs(globaldb.guilds) do
		local pg = {} -- packed guild
		pg.name = g.name
		pg.packedSnapshots = {}
		for _,s in pairs(g.snapshots) do
			setmetatable(s, GARS.Snapshot_mt)
			local ps = s:Pack()
			table.insert(pg.packedSnapshots, ps)
		end
		table.insert(globaldb.packedGuilds, pg)
	end
	globaldb.guilds = {}
end

function GARS:ShowFrame()
	GARS.frame = AceGUI:Create("Frame")
	GARS.frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	GARS.frame:SetTitle("GuildActivityRewardSystem")
	GARS.frame:SetLayout("List")
	local status = string.format(
		"%s-%s by %s",
		GARS:GetName(),
		GetAddOnMetadata( GARS:GetName(), "Version" ),
		GetAddOnMetadata( GARS:GetName(), "Author" )
	);
	GARS.frame:SetStatusText(status)

	GARS.frame.editbox = AceGUI:Create("MultiLineEditBox")
	GARS.frame.editbox:SetLabel("CSV export:")
	GARS.frame.editbox:DisableButton(true)
	GARS.frame.editbox:SetNumLines(24)
	GARS.frame.editbox:SetFullWidth(true)
	GARS.frame.editbox:SetText( GARS:ExportText() )
	GARS.frame:AddChild(GARS.frame.editbox)

	GARS.frame.button = AceGUI:Create("Button")
	GARS.frame.button:SetText("Save snapshot now")
	GARS.frame.button:SetCallback("OnClick", function()
		local guild = GARS:GetCurrentGuild()
		guild:TakeSnapshot()
		GARS.frame.editbox:SetText( GARS:ExportText() )
	end)
	GARS.frame:AddChild(GARS.frame.button)
end

function GARS:GetCurrentGuild()
	local globaldb = self.db.global
	local guildName, _, _ = GetGuildInfo("player")
	
	for _,g in pairs(globaldb.guilds) do
		if g.name == guildName then
			return g
		end
	end

	local g = GARS.Guild:New(guildName, {})
	table.insert(globaldb.guilds, g)
	return g
end

GARS.Guild = {}
GARS.Guild_mt = { __index = GARS.Guild }
function GARS.Guild:New(guildName, packedSnapshots)
	local g = {}
	setmetatable(g, GARS.Guild_mt)
	g.name = guildName
	g.snapshots = {}
	for _,ps in pairs(packedSnapshots) do
		local s = GARS.Snapshot:New(ps.time, g, ps.players)
		s:ProcessAlts()
		s:CalculateXPDiff()
		s:CombineXP()
	end
	return g
end

function GARS.Guild:TakeSnapshot()
	local time = time()
	local snapshot = GARS.Snapshot:New(time, self, {})

	snapshot:Populate()
	snapshot:CalculateXPDiff()
	snapshot:ProcessAlts()
	snapshot:CombineXP()	
end

local weakmt = { __mode = "v" }

GARS.Snapshot = {}
GARS.Snapshot_mt = { __index = GARS.Snapshot }
function GARS.Snapshot:New(time, guild, players)
	local s = {}
	setmetatable(s, GARS.Snapshot_mt)
	s.time = time
	s.players = {}
	for _,p in pairs(players) do
		table.insert(s.players, GARS.GuildMember:New(p.name, p.atresetXP, p.possibleMain) )
	end
	s.playersByName = {}
	setmetatable(s.playersByName, weakmt)
	for _,p in pairs(s.players) do
		s.playersByName[p.name] = p
	end

	table.insert(guild.snapshots, s)

	guild:SortSnapshots()

	return s
end

function GARS.Guild:SortSnapshots()
	--GARS:Printf("updating snapshot references for %s", self.name)
	self.latestSnapshot = nil
	table.sort(self.snapshots, function(a,b) return a.time < b.time end)
	for _,s in ipairs(self.snapshots) do
		--GARS:Printf("--- %d", s.time)
		if self.latestSnapshot then
			s.previousSnapshot = self.latestSnapshot
			self.latestSnapshot.nextSnapshot = s
		end
		self.latestSnapshot = s
	end
end

function GARS.Snapshot:Pack()
	local packedSnapshot = {}
	packedSnapshot.time = self.time
	packedSnapshot.players = {}
	for _,player in pairs(self.players) do
		local newplayer = {}
		newplayer.atresetXP = player.atresetXP
		newplayer.name = player.name
		if player.main then
			newplayer.possibleMain = player.main.name
		end
		table.insert(packedSnapshot.players, newplayer)
	end
	return packedSnapshot
end


function GARS.Snapshot:Populate()
	local totalMembers, _ = GetNumGuildMembers()
	local showOfflinePref = GetGuildRosterShowOffline()
	if not showOfflinePref == 1 then
		SetGuildRosterShowOffline(1)
	end
	for i=1, totalMembers do
		local weeklyXP, totalXP, _, _ = GetGuildRosterContribution(i)
		local name, _, _, _, _, _, note, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)

		local atresetXP = totalXP - weeklyXP

		local possibleMain = string.match(note, "^([^,]+)$") or string.match(note, "^([^,]+),")
		if possibleMain then
			possibleMain = string.upper(string.sub(possibleMain,1,1))..string.lower(string.sub(possibleMain,2))
		end
		
		local char = GARS.GuildMember:New(name, atresetXP, possibleMain)
		table.insert(self.players, char)
		self.playersByName[name] = char
	end
	SetGuildRosterShowOffline(showOfflinePref)
end

function GARS.Snapshot:CalculateXPDiff()
	local prev = self.previousSnapshot
	if not prev then
		GARS:Print("wtf")
	end
	for _,player in pairs(self.players) do
		local currentXP = player.atresetXP
		local oldXP = prev and prev.playersByName[player.name] and prev.playersByName[player.name].atresetXP or 0
		player.deltaXP = currentXP - oldXP
	end
end

function GARS.Snapshot:ProcessAlts()
	for _,char in pairs(self.players) do
		char:CheckPossibleMain(self)
	end
end

function GARS.Snapshot:CombineXP()
	for _,char in pairs(self.players) do
		local altXP = 0
		for _,alt in pairs(char.alts) do
			altXP = altXP + alt.deltaXP
		end
		char.combinedXP = char.deltaXP + altXP
	end
end


GARS.GuildMember = {}
GARS.GuildMember_mt = { __index = GARS.GuildMember }
function GARS.GuildMember:New(name, atresetXP, possibleMain)
	local o = setmetatable({}, GARS.GuildMember_mt)
	o.name = name
	o.atresetXP = atresetXP
	o.deltaXP = nil
	o.combinedXP = nil
	o.possibleMain = possibleMain
	o.main = nil
	o.alts = {}
	o.isMain = nil
	o.isAlt = nil
	o.currentlyChecking = false
	return o
end

function GARS.GuildMember:CheckPossibleMain(snapshot)
	if self.isMain or self.isAlt then
		return
	end
	
	self.currentlyChecking = true;

	local pm = snapshot.playersByName[self.possibleMain]
	if pm then
		if not pm.isMain then
			if pm.currentlyChecking then
				GARS:Printf("warning: alt cycle detected, ignoring: %s -> %s...", self.name, pm.name)
				self:SetAsMain()
				self.currentlyChecking = false
				return
			end
			pm:CheckPossibleMain(snapshot)
		end

		if pm.isMain then
			self:SetAsAltOf(pm, snapshot)
		else
			GARS:Printf("warning: alt chain detected, ignoring: %s -> %s -> %s...", self.name, pm.name, pm.main.name)
			self:SetAsMain()
		end
	else
		self:SetAsMain()
	end
	self.currentlyChecking = false
end


function GARS.GuildMember:SetAsAltOf(main, snapshot)
	--GARS:Printf("new alt relationship found: %s is the alt of %s", self.name, main.name) end
	self.isAlt = true;
	self.isMain = false;
	self.main = main;
	self.possibleMain = nil;
	table.insert(main.alts, self)
end

function GARS.GuildMember:SetAsMain()
	self.isAlt = false;
	self.isMain = true;
	self.main = nil;
	self.possibleMain = nil;
end


function GARS:ExportText()
	local guild = GARS:GetCurrentGuild()
	if not guild.latestSnapshot then
		return "no snapshot"
	end

	local players = guild.latestSnapshot.players
	
	table.sort(players, function(a,b) return a.combinedXP > b.combinedXP end)

	local output = ""
	for _,char in ipairs(players) do
		if char.isMain then
			output = output..string.format("name=%s combinedXP=%d",char.name,char.combinedXP)
			if #char.alts > 0 then
				table.sort(char.alts, function(a,b) return a.combinedXP > b.combinedXP end)
				local altsAsStrings = {}
				for _,alt in ipairs(char.alts) do
					table.insert(altsAsStrings, string.format("%s=%d",alt.name,alt.deltaXP))
				end
				output = output.." alts={"..table.concat(altsAsStrings,",").."}"
			end
			output = output.."\n"
		end
	end
	return output
end
