package.loaded.Constants = nil; require("Constants");

function OMAE:StartActivity()

	self.Phase = 0; -- 0 = buy phase, 1 = play phase;
	self.playersActive = 0; -- for tracking players and their buying
	self.boughtActors = {};

    self.CPUTechName = rte.TechList[math.ceil(math.random() * #rte.TechList)];

	self.ESpawnTimer = Timer()
	self.LZ = SceneMan.Scene:GetArea("LZ Team 1")
	self.EnemyLZ = SceneMan.Scene:GetArea("LZ All")

	if self.Difficulty <= GameActivity.CAKEDIFFICULTY then
		self.TimeLimit = 60000+5000
		self.timeDisplay = "one minute"
		self.BaseSpawnTime = 6000
		self.RandomSpawnTime = 8000
	elseif self.Difficulty <= GameActivity.EASYDIFFICULTY then
		self.TimeLimit = 1.5*60000+5000
		self.timeDisplay = "one minute and thirty seconds"
		self.BaseSpawnTime = 5500
		self.RandomSpawnTime = 7000
	elseif self.Difficulty <= GameActivity.MEDIUMDIFFICULTY then
		self.TimeLimit = 2*60000+5000
		self.timeDisplay = "two minutes"
		self.BaseSpawnTime = 5000
		self.RandomSpawnTime = 6000
	elseif self.Difficulty <= GameActivity.HARDDIFFICULTY then
		self.TimeLimit = 3*60000+5000
		self.timeDisplay = "three minutes"
		self.BaseSpawnTime = 4500
		self.RandomSpawnTime = 5000
	elseif self.Difficulty <= GameActivity.NUTSDIFFICULTY then
		self.TimeLimit = 5*60000+5000
		self.timeDisplay = "five minutes"
		self.BaseSpawnTime = 4000
		self.RandomSpawnTime = 4500
	elseif self.Difficulty <= GameActivity.MAXDIFFICULTY then
		self.TimeLimit = 10*60000+5000
		self.timeDisplay = "ten minutes"
		self.BaseSpawnTime = 3500
		self.RandomSpawnTime = 4000
	end

	ActivityMan:GetActivity():SetTeamFunds(1000,Activity.TEAM_1)
	ActivityMan:GetActivity():SetTeamFunds(1000,Activity.TEAM_2)
	ActivityMan:GetActivity():SetTeamFunds(1000,Activity.TEAM_3)
	ActivityMan:GetActivity():SetTeamFunds(1000,Activity.TEAM_4)

	self.TimeLeft = self.BaseSpawnTime + math.random(self.RandomSpawnTime)

	for player = Activity.PLAYER_1, Activity.MAXPLAYERCOUNT - 1 do
		if self:PlayerActive(player) and self:PlayerHuman(player) then
			local buyer = CreateACrab("Crab");
			buyer.Pos = SceneMan:MovePointToGround(Vector(math.random(0, SceneMan.SceneWidth), 0), 0, 0) + Vector(0, -50);
			buyer.Team = self:GetTeamOfPlayer(player);
			MovableMan:AddActor(buyer);
			self.playersActive = self.playersActive + 1;
			
			if self.Difficulty <= GameActivity.CAKEDIFFICULTY then
				ActivityMan:GetActivity():SetTeamFunds(5000,buyer.Team);
			elseif self.Difficulty <= GameActivity.EASYDIFFICULTY then
				ActivityMan:GetActivity():SetTeamFunds(4000,buyer.Team);
			elseif self.Difficulty <= GameActivity.MEDIUMDIFFICULTY then
				ActivityMan:GetActivity():SetTeamFunds(3000,buyer.Team);
			elseif self.Difficulty <= GameActivity.HARDDIFFICULTY then
				ActivityMan:GetActivity():SetTeamFunds(2000,buyer.Team);
			elseif self.Difficulty <= GameActivity.NUTSDIFFICULTY then
				ActivityMan:GetActivity():SetTeamFunds(1500,buyer.Team);
			elseif self.Difficulty <= GameActivity.MAXDIFFICULTY then
				ActivityMan:GetActivity():SetTeamFunds(1000,buyer.Team);
			end
		end
	end
end

local boughtNum = 0;

function OMAE:UpdateActivity()
	if self.ActivityState ~= Activity.OVER then
		if self.Phase == 0 then -- BUY PHASE
			-- Check if we already have a brain assigned
			for player = Activity.PLAYER_1, Activity.MAXPLAYERCOUNT - 1 do
				FrameMan:SetScreenText("Buy your soldier!", player, 333, 100, true)
				if self:PlayerActive(player) and self:PlayerHuman(player) then
					if self:GetControlledActor(player).ClassName == "AHuman" then
						-- you are special, my little actor!
						if self.boughtActors[player] == nil then
							boughtNum = boughtNum + 1;
							self.boughtActors[player] = self:GetControlledActor(player);
							self:SetPlayerBrain(self:GetControlledActor(player), player);
						end
					end
				end
			end

			if boughtNum == self.playersActive then
				-- Start playing!
				self.Phase = 1;
				self.StartTimer = Timer();

				-- Get rid of crafts and such
				for actor in MovableMan.Actors do
					if not actor:IsPlayerControlled() then
						actor.ToDelete = true;
					end
				end
			end

		else -- PLAY PHASE
			ActivityMan:GetActivity():SetTeamFunds(0,0)
			for player = Activity.PLAYER_1, Activity.MAXPLAYERCOUNT - 1 do
				if self:PlayerActive(player) and self:PlayerHuman(player) then
					--Display messages.
					if self.StartTimer:IsPastSimMS(3000) then
						FrameMan:SetScreenText(math.floor(self.SurvivalTimer:LeftTillSimMS(self.TimeLimit) / 1000) .. " seconds left", player, 0, 1000, false)
					else
						self.SurvivalTimer = Timer();
						FrameMan:SetScreenText("Survive for " .. self.timeDisplay .. "!", player, 333, 5000, true)
					end

					-- The current player's team
					local team = self:GetTeamOfPlayer(player)
					-- Check if any player's brain is dead
					if not MovableMan:IsActor(self.boughtActors[player]) then
						self:SetPlayerBrain(nil, player)
						self:ResetMessageTimer(player)
						FrameMan:ClearScreenText(player)
						FrameMan:SetScreenText("Your have been defeated!", player, 333, -1, false)
						ActivityMan:EndActivity()
					else
						self.HuntPlayer = player
					end

					--Check if the player has won.
					if self.SurvivalTimer:IsPastSimMS(self.TimeLimit) then
						self:ResetMessageTimer(player)
						FrameMan:ClearScreenText(player)
						FrameMan:SetScreenText("You survived!", player, 333, -1, false)

						self.WinnerTeam = team

						--Kill all enemies.
						for actor in MovableMan.Actors do
							if actor.Team ~= self.WinnerTeam then
								actor.Health = 0
							end
						end

						ActivityMan:EndActivity()
					end
				end
			end

			--Spawn the AI.
			if self.HuntPlayer ~= nil and self.ESpawnTimer:LeftTillSimMS(self.TimeLeft) <= 0 and MovableMan:GetMOIDCount() <= 210 then
				local actor = {}
				for x = 0, math.ceil(math.random(3)) do

	                if math.random() >= 0.2 then
						actor[x] = RandomAHuman("Any", self.CPUTechName);
					else
						actor[x] = RandomACrab("Any", self.CPUTechName);
					end
					
					if IsAHuman(actor[x]) then
						actor[x]:AddInventoryItem(RandomHDFirearm("Primary Weapons", self.CPUTechName));
						actor[x]:AddInventoryItem(RandomHDFirearm("Secondary Weapons", self.CPUTechName));
						if PosRand() < 0.5 then
							actor[x]:AddInventoryItem(RandomHDFirearm("Diggers", self.CPUTechName));
						end
					end
					-- Set AI mode and team so it knows who and what to fight for!
					actor[x].AIMode = Actor.AIMODE_BRAINHUNT;
					actor[x].Team = self.CPUTeam;

				end
				local ship = nil
				local z = math.random()

				if z > 0.1 then
					ship = RandomACDropShip("Any", self.CPUTechName);
				else
					ship = RandomACRocket("Any", self.CPUTechName);
				end

				for n = 0, #actor do
					ship:AddInventoryItem(actor[n])
				end
				ship.Team = 1
				local w = math.random()
				if w > 0.5 then
					ship.Pos = Vector(self.EnemyLZ:GetRandomPoint().X,-50)
				else
					ship.Pos = Vector(self.LZ:GetRandomPoint().X,-50)
				end
				MovableMan:AddActor(ship)
				self.ESpawnTimer:Reset()
				self.TimeLeft = self.BaseSpawnTime + math.random(self.RandomSpawnTime)
			end
		end
	end
end
