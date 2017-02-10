-- This module handles the go_to_theater script for the quests.
-- It spawns a theater and a set of mobiles in the world and keeps track of them.
-- Parameters:
--  - minimumDistance  		- the minimum distance from the player that the theater should be spawned.
--  - maximumDistance  		- the maximum distance from the player that the theater should be spawned.
--  - theater  	 			- the script to use for the theater.
--  - waypointDescription 	- description for the waypoint that is shown for the player.
--  - mobileList 			- a list of mobiles to spawn around the theater. The list follows the format of the spawn_mobiles module.
--  - despawnTime 			- the time in milliseconds that the theater will remain in the world before being despawned.
--  - onFailedSpawn 		- function that is called if the spawn of the theater or any element creation fails.

local ObjectManager = require("managers.object.object_manager")
local SpawnMobiles = require("utils.spawn_mobiles")

GoToTheater = Task:new {
	-- Task properties
	taskName = "",
	-- GoToTheater properties
	minimumDistance = 0,
	maximumDistance = 0,
	theater = {},
	waypointDescription = "",
	createWaypoint = true,
	mobileList = {},
	mobileListWithLoc = {},
	despawnTime = 0,
	activeAreaRadius = 0,
	onFailedSpawn = nil,
	onTheaterCreated = nil,
	onObjectsSpawned = nil,
	onEnteredActiveArea = nil,
	onTheaterDespawn = nil
}

function GoToTheater:taskStart(pPlayer)
	local zoneName = SceneObject(pPlayer):getZoneName()
	local spawnPoint = getSpawnArea(zoneName, SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionY(), self.minimumDistance, self.maximumDistance, 20, 10, true)
	local playerID = SceneObject(pPlayer):getObjectID()

	if (spawnPoint == nil) then
		printLuaError("GoToTheater:taskStart() for task " .. self.taskName .. ", spawnPoint is nil.")
		self:callFunctionIfNotNil(self.onFailedSpawn, nil, pPlayer)
		self:finish(pPlayer)
		return false
	end

	local pTheater = spawnSceneObject(zoneName, "object/static/structure/nobuild/nobuild_32.iff", spawnPoint[1], spawnPoint[2], spawnPoint[3], 0, 0)

	if (pTheater == nil) then
		return false
	end

	writeData(playerID .. self.taskName .. "theaterID", SceneObject(pTheater):getObjectID())

	local pActiveArea = spawnActiveArea(zoneName, "object/active_area.iff", spawnPoint[1], 0, spawnPoint[3], 250, 0)

	if (pActiveArea == nil) then
		return false
	end

	writeData(playerID .. self.taskName .. "spawnEnterAreaId", SceneObject(pActiveArea):getObjectID())
	createObserver(ENTEREDAREA, self.taskName, "enteredTheaterSpawnArea", pActiveArea)

	pActiveArea = spawnActiveArea(zoneName, "object/active_area.iff", spawnPoint[1], 0, spawnPoint[3], 300, 0)

	if (pActiveArea == nil) then
		return false
	end

	writeData(playerID .. self.taskName .. "spawnExitAreaId", SceneObject(pActiveArea):getObjectID())
	createObserver(EXITEDAREA, self.taskName, "exitedTheaterSpawnArea", pActiveArea)

	if (self.createWaypoint) then
		local pGhost = CreatureObject(pPlayer):getPlayerObject()

		if (pGhost ~= nil) then
			PlayerObject(pGhost):addWaypoint(zoneName, self.waypointDescription, "", spawnPoint[1], spawnPoint[3], WAYPOINTYELLOW, true, true, WAYPOINTQUESTTASK)
		end
	end

	self:callFunctionIfNotNil(self.onTheaterCreated, nil, pPlayer)

	return true
end

function GoToTheater:enteredTheaterSpawnArea(pActiveArea, pPlayer)
	if not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	local storedActiveAreaId = readData(SceneObject(pPlayer):getObjectID() .. self.taskName .. "spawnEnterAreaId")

	if (storedActiveAreaId == SceneObject(pActiveArea):getObjectID()) then
		self:spawnTheaterObjects(pPlayer)
	end

	return 0
end

function GoToTheater:exitedTheaterSpawnArea(pActiveArea, pPlayer)
	if not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	local storedActiveAreaId = readData(SceneObject(pPlayer):getObjectID() .. self.taskName .. "spawnExitAreaId")

	if (storedActiveAreaId == SceneObject(pActiveArea):getObjectID()) then
		self:despawnTheaterObjects(pPlayer)
	end

	return 0
end

function GoToTheater:spawnTheaterObjects(pPlayer)
	local pTheater = self:getTheaterObject(pPlayer)

	if (pTheater == nil) then
		printLuaError("GoToTheater:spawnTheaterObjects for " .. self.taskName .. ", theater object null.")
		self:finish(pPlayer)
		return
	end

	if (self:areTheaterObjectsSpawned(pPlayer)) then
		return
	end

	local zoneName = SceneObject(pTheater):getZoneName()

	local spawnPoint = { SceneObject(pTheater):getWorldPositionX(), SceneObject(pTheater):getWorldPositionZ(), SceneObject(pTheater):getWorldPositionY() }

	local playerID = SceneObject(pPlayer):getObjectID()

	for i = 1, #self.theater, 1 do
		local objectData = self.theater[i]
		local xLoc = spawnPoint[1] + objectData.xDiff
		local yLoc = spawnPoint[3] + objectData.yDiff
		local zLoc = getTerrainHeight(pPlayer, xLoc, yLoc) + objectData.zDiff
		local pObject = spawnSceneObject(zoneName, objectData.template, xLoc, zLoc, yLoc, 0, objectData.heading)

		if (pObject ~= nil) then
			writeData(playerID .. self.taskName .. "theaterObject" .. i, SceneObject(pObject):getObjectID())
		end
	end

	local spawnedMobilesList

	if (self.mobileList ~= nil and #self.mobileList > 0) then
		spawnedMobilesList = SpawnMobiles.spawnMobiles(pTheater, self.taskName, self.mobileList, true)
	elseif (self.mobileListWithLoc ~= nil and #self.mobileListWithLoc > 0) then
		spawnedMobilesList = SpawnMobiles.spawnMobilesWithLoc(pTheater, self.taskName, self.mobileListWithLoc)
	end

	if not self:setupActiveArea(pPlayer, spawnPoint) then
		self:finish(pPlayer)
	else
		self:callFunctionIfNotNil(self.onObjectsSpawned, nil, pPlayer, spawnedMobilesList)
	end
end

function GoToTheater:despawnTheaterObjects(pPlayer)
	if (not self:areTheaterObjectsSpawned(pPlayer)) then
		return
	end

	local playerID = SceneObject(pPlayer):getObjectID()

	local activeAreaId = readData(playerID .. self.taskName .. "activeAreaId")
	local pArea = getSceneObject(activeAreaId)

	if (pArea ~= nil) then
		SceneObject(pArea):destroyObjectFromWorld()
	end

	for i = 1, #self.theater, 1 do
		local objectID = readData(playerID .. self.taskName .. "theaterObject" .. i)
		local pObject = getSceneObject(objectID)
		if (pObject ~= nil) then
			SceneObject(pObject):destroyObjectFromWorld()
			deleteData(playerID .. self.taskName .. "theaterObject" .. i)
		end
	end

	local pTheater = self:getTheaterObject(pPlayer)

	if (pTheater ~= nil) then
		SpawnMobiles.despawnMobiles(pTheater, self.taskName)
		self:callFunctionIfNotNil(self.onTheaterDespawn, nil, pPlayer)
	end
end

function GoToTheater:setupActiveArea(pPlayer, spawnPoint)
	local pActiveArea = spawnActiveArea(CreatureObject(pPlayer):getZoneName(), "object/active_area.iff", spawnPoint[1], 0, spawnPoint[3], self.activeAreaRadius, 0)

	if (pActiveArea ~= nil) then
		writeData(SceneObject(pPlayer):getObjectID() .. self.taskName .. "activeAreaId", SceneObject(pActiveArea):getObjectID())
		createEvent(5000, self.taskName, "createAreaObserver", pActiveArea, "")
		return true
	end

	return false
end

function GoToTheater:createAreaObserver(pActiveArea)
	if (pActiveArea == nil) then
		return
	end

	createObserver(ENTEREDAREA, self.taskName, "handleEnteredAreaEvent", pActiveArea)
end

function GoToTheater:handleEnteredAreaEvent(pActiveArea, pPlayer, nothing)
	if not SceneObject(pPlayer):isPlayerCreature() then
		return 0
	end

	local storedActiveAreaId = readData(SceneObject(pPlayer):getObjectID() .. self.taskName .. "activeAreaId")
	if storedActiveAreaId == SceneObject(pActiveArea):getObjectID() then
		local spawnedObjects = self:getSpawnedMobileList(pPlayer)
		self:callFunctionIfNotNil(self.onEnteredActiveArea, nil, pPlayer, spawnedObjects)

		return 1
	end

	return 0
end

function GoToTheater:areTheaterObjectsSpawned(pPlayer)
	local playerID = SceneObject(pPlayer):getObjectID()

	for i = 1, #self.theater, 1 do
		local objectID = readData(playerID .. self.taskName .. "theaterObject" .. i)
		local pObject = getSceneObject(objectID)

		if (pObject ~= nil) then
			return true
		end
	end

	return false
end

function GoToTheater:taskFinish(pPlayer)
	local playerID = SceneObject(pPlayer):getObjectID()

	self:removeTheaterWaypoint(pPlayer)
	self:despawnTheaterObjects(pPlayer)

	local activeAreaId = readData(playerID .. self.taskName .. "spawnEnterAreaId")
	local pArea = getSceneObject(activeAreaId)

	if (pArea ~= nil) then
		SceneObject(pArea):destroyObjectFromWorld()
	end

	deleteData(playerID .. self.taskName .. "spawnEnterAreaId")

	activeAreaId = readData(playerID .. self.taskName .. "spawnExitAreaId")
	pArea = getSceneObject(activeAreaId)

	if (pArea ~= nil) then
		SceneObject(pArea):destroyObjectFromWorld()
	end

	deleteData(playerID .. self.taskName .. "spawnExitAreaId")

	local pTheater = self:getTheaterObject(pPlayer)

	if (pTheater ~= nil) then
		SceneObject(pTheater):destroyObjectFromWorld()
	end

	deleteData(playerID .. self.taskName .. "theaterID")

	return true
end

function GoToTheater:removeTheaterWaypoint(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()

	if (pGhost == nil) then
		return
	end

	PlayerObject(pGhost):removeWaypointBySpecialType(WAYPOINTQUESTTASK)
end

function GoToTheater:getSpawnedMobileList(pPlayer)
	local pTheater = self:getTheaterObject(pPlayer)

	if pTheater == nil then
		return nil
	end

	return SpawnMobiles.getSpawnedMobiles(pTheater, self.taskName)
end

function GoToTheater:getTheaterObject(pPlayer)
	local theaterId = readData(SceneObject(pPlayer):getObjectID() .. self.taskName .. "theaterID")
	local pTheater = getSceneObject(theaterId)

	return pTheater
end

return GoToTheater
