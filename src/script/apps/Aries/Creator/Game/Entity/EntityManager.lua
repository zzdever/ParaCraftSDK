--[[
Title: Entity Manager in block world
Author(s): LiXizhi
Date: 2013/1/23
Desc: It manages character object with AI in the block world. 
use the lib:
------------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityManager.lua");
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
EntityManager.FrameMove();
EntityManager.AddObject(obj)
local entities = EntityManager.GetEntitiesInBlock(bx, by, bz)
if(entities) then
	for entity, _ in pairs(entities) do
	end
end
EntityManager.HasEntityInBlock(bx, by, bz)
-------------------------------------------------------
]]
NPL.load("(gl)script/ide/STL.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/Entity.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Items/ItemClient.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/BlockContainer.lua")
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/RegionContainer.lua");
NPL.load("(gl)script/ide/math/bit.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Common/ChunkLocation.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityPool.lua");
local EntityPool = commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityPool");
local ChunkLocation = commonlib.gettable("MyCompany.Aries.Game.Common.ChunkLocation");
local RegionContainer = commonlib.gettable("MyCompany.Aries.Game.EntityManager.RegionContainer");
local BlockContainer = commonlib.gettable("MyCompany.Aries.Game.EntityManager.BlockContainer");
local EntityPlayer = commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityPlayer")
local EntityMob = commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityMob")
local EntityNPC = commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityNPC")
local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
local EntityCollectable = commonlib.gettable("MyCompany.Aries.Game.EntityManager.EntityCollectable")
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local TaskManager = commonlib.gettable("MyCompany.Aries.Game.TaskManager")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")

local rshift = mathlib.bit.rshift;
local lshift = mathlib.bit.lshift;
local band = mathlib.bit.band;
local bor = mathlib.bit.bor;
local math_floor = math.floor;

local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
commonlib.add_interface(EntityManager, commonlib.gettable("System.Core.AttributeObject"))

local default_filename = "entity.xml";

-- all active dynamic world object
local dynamic_objects = commonlib.UnorderedArray:new();
local static_objects = {};
-- 512*512 region entities
local regions = {};
-- mapping from block index to entity object. 
local block_cache = {};
-- containers
local block_containers = {};
-- mapping from packed chunk column pos to array of block entities. 
local chunk_column_entities = {};

-- mapping from scene object id to entity object. 
local obj_id_maps = {};
-- mapping from entity name to entity object. 
local obj_name_maps = {};
-- entity ids
local entity_id_maps = {};

-- mapping from entity to true. 
local senstient_list = {};

-- temp framemove list
local framemove_queue_size = 0;
local framemove_queue = {};


local entity_count_stats = {};

local cur_player;
local cur_focus;
local players = {};
local frame_count = 0;

EntityManager.entity_classes = {};

function EntityManager.RegisterEntities()
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityCollectable.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityMob.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityNPC.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityPlayer.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntitySign.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityImage.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityItemFrame.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityChest.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityCommandBlock.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityItem.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityMusicBox.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityNote.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityCmdTextureReplacer.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityCollisionSensor.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityHomePoint.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityBlockDynamic.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityDesktop.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityMovieClip.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityCamera.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityWeatherEffect.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityRainEffect.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntitySnowEffect.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityRailcar.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityPlayerMP.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityPlayerMPOther.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityPlayerMPClient.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityBlockModel.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntitySky.lua");
	NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityBlockBone.lua");
end

-- register a new entity class
function EntityManager.RegisterEntityClass(name, entity)
	EntityManager.entity_classes[name or entity.class_name] = entity;
end

-- get entity class
function EntityManager.GetEntityClass(class_name)
	return EntityManager.entity_classes[class_name or ""];
end

---------------------------------
-- attribute interface
---------------------------------
-- get child attribute object. this can be regarded as an intrusive data model of a given object. 
-- once you get an attribute object, you can use this model class to access all data in the hierarchy.
function EntityManager:GetChild(sName)
	return EntityManager.GetEntity(name);
end

-- @param nColumnIndex: nil to default to 0;
function EntityManager:GetChildAt(nRowIndex, nColumnIndex)
	if(nRowIndex == 0) then
		return System.Core.TableAttribute:create(obj_name_maps, "all_entities");
	elseif(nRowIndex == 1) then
		return System.Core.TableAttribute:create(senstient_list, "senstient_list");
	elseif(nRowIndex == 2) then
		return System.Core.TableAttribute:create(regions, "regions");
	end
end

-- @param nColumnIndex: if nil, default to 0. 
function EntityManager:GetChildCount(nColumnIndex)
	nColumnIndex = nColumnIndex or 0;
	if(nColumnIndex == 0) then
		return 3;
	end
	return 0;
end


function EntityManager.Clear()
	dynamic_objects:clear();
	static_objects = {};
	block_cache = {};
	block_containers = {};
	chunk_column_entities = {};
	obj_id_maps = {};
	obj_name_maps = {};
	entity_id_maps = {};
	regions = {};
	cur_player = nil;
	cur_focus = nil;
	players = {};
	senstient_list = {};
	framemove_queue = {};

	last_trigger_entity = nil;
	EntityPool:ClearAllPools();
end

-- whether the given block is blocked. 
-- TODO: cache the query result for a single framemove. this function may be called many times in a single frame. 
function EntityManager.IsBlocked(bx, by, bz)
	local block_id = ParaTerrain.GetBlockTemplateByIdx(bx, by, bz);	
	return block_id~=0;
end

-- add entity. 
function EntityManager.AddObject(entity)
	if(not entity) then
		LOG.std(nil, "warn", "EntityManager", "calling AddObject with invalid entity");
		return;
	end
	if(entity.is_dynamic) then
		dynamic_objects:push_back(entity)
	else
		static_objects[entity] = true;
	end
	if(entity.obj_id) then
		EntityManager.SetEntityByObjectID(entity.obj_id, entity);
	end
	if(entity.name) then
		obj_name_maps[entity.name] = entity;
	end
	if(entity.entityId) then
		entity_id_maps[entity.entityId] = entity;
	end
	EntityManager.AddEntityCount(entity.item_id, 1);
	if(entity.isServerEntity) then
		GameLogic.GetWorld():OnEntityAdded(entity);
	end
end

function EntityManager.AddEntityCount(item_id, delta_count)
	if(item_id) then
		entity_count_stats[item_id] = (entity_count_stats[item_id] or 0) + delta_count;
	end
end

-- remove entity from manager. 
function EntityManager.RemoveObject(entity)
	if(entity.isServerEntity) then
		GameLogic.GetWorld():OnEntityRemoved(entity);
	end
	static_objects[entity] = nil;
	if(entity.obj_id) then
		EntityManager.SetEntityByObjectID(entity.obj_id, nil);
		entity.obj_id = nil;
	end
	local name = entity.name;
	if(name and name == obj_name_maps[name]) then
		obj_name_maps[name] = nil;
	end
	if(entity.entityId and entity_id_maps[entity.entityId] == entity) then
		entity_id_maps[entity.entityId] = nil;
	end
	EntityManager.AddEntityCount(entity.item_id, -1);
end

function EntityManager.GetAllEntities()
	return entity_id_maps;
end

-- get item count by block_id
function EntityManager.GetItemCount(item_id)
	return entity_count_stats[item_id] or 0;
end

-- Load all entity data from a given XML file. 
-- @param filename: if nil, it search the "[currentworld]/entity.xml"
-- @return true if there is local NPC file. or nil if not. 
function EntityManager.LoadFromFile(filename)
	entity_count_stats = {};

	EntityManager.RegisterEntities();
	EntityManager.InitPlayers();
	
	if(not filename) then
		local test_filename = format("%s%s", ParaWorld.GetWorldDirectory(), default_filename);
		if(ParaIO.DoesAssetFileExist(test_filename, true))then
			filename = test_filename;
		end
	end

	if(not filename) then
		return;
	end

	-- load using a temporary global region container
	RegionContainer:new():init(-1,-1, filename):LoadFromFile();
end

-- init player. Set and load current player. 
function EntityManager.InitPlayers()
	if(not cur_player) then
		NPL.load("(gl)script/apps/Aries/Creator/Game/Entity/EntityPlayer.lua");
		local entity = EntityManager.LoadPlayer(GameLogic.options:GetPlayerName());
		if(not entity.displayName) then
			entity:SetDisplayName(tostring(System.User.nid) or "");	
		end
		entity:BindToScenePlayer(ParaScene.GetPlayer());
		entity:UpdateBlockContainer();
		entity:SetFocus();
		EntityManager.SetMainPlayer(entity);
	end
end

function EntityManager.GetPlayerFileName(name)
end

-- Returns true if there are no solid, live entities in the specified location, excluding the given entity
-- @param excludingEntity: usually the current player. 
function EntityManager.CheckNoEntityCollision(x,y,z, excludingEntity)
	local entities = EntityManager.GetEntitiesInBlock(x,y,z);
	if(entities) then
		for entity, _ in pairs(entities) do
			if(not entity.isDead and (not excludingEntity or entity~=excludingEntity)) then
				return false;
			end
		end
	end
	return true;
end

-- the lastest trigger entity, such as the one that pressed a button or step on a pressure plat, etc.  
function EntityManager.GetLastTriggerEntity()
	return last_trigger_entity;
end

-- set lastest trigger entity. 
function EntityManager.SetLastTriggerEntity(entity)
	last_trigger_entity = entity;
end

-- get or load or create a player of the given name. 
function EntityManager.LoadPlayer(name)
	local player = EntityManager.GetPlayer(name);
	if(not player) then
		local save_handler = GameLogic.GetSaveHandler();
		local world = GameLogic.GetWorld();
		if(save_handler and world) then
			player = EntityPlayer:new({username = name});
			save_handler:GetPlayerSaveHandler():ReadPlayerData(player);
			player:init(world);
			player:Attach();
			players[name] = player;
		end
	end
	return player;
end

-- set the main player that is being controlled. After this call, EntityManager.GetPlayer() will return the given player. 
-- the main player is always the player being controlled by the PlayerController.  
-- @param playerEntity: this could be EntityPlayerMP for server player, or EntityPlayer for standalone player, or EntityPlayerMPClient for client side main player
-- @return: the previous player if any. 
function EntityManager.SetMainPlayer(playerEntity)
	if(cur_player~=playerEntity) then
		local last_player = cur_player;
		cur_player = playerEntity;
		GameLogic.events:DispatchEvent({type = "OnPlayerReplaced" , });
		return last_player;
	else
		return cur_player;
	end
end

function EntityManager.SaveAllPlayers()
	local save_handler = GameLogic.GetSaveHandler();
	local world = GameLogic.GetWorld();
	if(save_handler and world) then
		for name, player in pairs(players) do
			save_handler:GetPlayerSaveHandler():WritePlayerData(player);
		end
	end
end


-- get player
-- @param name: if nil or "player", the current player is returned. 
function EntityManager.GetPlayer(name)
	if(not name) then
		return cur_player;
	else
		return players[name];
	end
end

-- get entity
function EntityManager.GetEntityByObjectID(obj_id)
	return obj_id_maps[obj_id];
end

-- get by name. 
function EntityManager.GetEntity(name)
	if(name) then
		return obj_name_maps[name];
	end
end

-- get by id. 
function EntityManager.GetEntityById(entityId)
	if(entityId) then
		return entity_id_maps[entityId];
	end
end

-- rename a given entity in the manager. 
function EntityManager.RenameEntity(entity, old_name, new_name)
	if(old_name) then
		if(obj_name_maps[old_name] == entity) then
			obj_name_maps[old_name] = nil;
		end
	end
	if(new_name) then
		obj_name_maps[new_name] = entity;
	end
end


-- get all entities by block id. 
-- @return nil or array of entities. 
function EntityManager.GetEntitiesByItemID(item_id)
	local entities;
	for _, entity in pairs(obj_name_maps) do
		if(entity.item_id == item_id) then
			entities = entities or {};
			entities[#entities+1] = entity;
		end
	end
	return entities;
end

function EntityManager.SetEntityByObjectID(obj_id, entity)
	obj_id_maps[obj_id] = entity;
end


-- return true if there is at least one entity at the blocok position. 
function EntityManager.HasEntityInBlock(bx, by, bz)
	local entities = EntityManager.GetEntitiesInBlock(bx, by, bz);
	if(entities) then
		local entity = next(entities);
		if(entity) then
			return true;
		end
	end
end

-- has non-player entity
function EntityManager.HasNonPlayerEntityInBlock(bx, by, bz)
	local entities = EntityManager.GetEntitiesInBlock(bx, by, bz);
	if(entities) then
		for entity,_ in pairs(entities) do
			if(entity:GetType() ~= "Player") then
				return true;
			end
		end
	end
end

-- get all entities in block. 
function EntityManager.GetEntitiesInBlock(bx, by, bz)
	local sparse_index = by*30000*30000+bx*30000+bz;
	local block_container = block_containers[sparse_index];
	if(block_container) then
		return block_container:GetEntities();
	end
end

-- get the block entity excluding other entity
function EntityManager.GetBlockEntity(bx, by, bz)
	local block = BlockEngine:GetBlock(bx, by, bz);
	if(block) then
		return block:GetBlockEntity(bx, by, bz);
	end
end

-- get the first entity that matches the class_name
function EntityManager.GetEntityInBlock(bx, by, bz, class_name)
	local entities = EntityManager.GetEntitiesInBlock(bx, by, bz);
	if(entities) then
		for entity,_ in pairs(entities) do
			if(entity:GetType() == class_name) then
				return entity;
			end
		end
	end
end

-- @param entity_class: nil to match any entity. 
function EntityManager.GetEntitiesByAABBOfType(entity_class, aabb)
	local output;
	local min_x, min_y, min_z = aabb:GetMinValues();
	local max_x, max_y, max_z = aabb:GetMaxValues();
	
	min_x, min_y, min_z = BlockEngine:block(min_x, min_y, min_z);
	max_x, max_y, max_z = BlockEngine:block(max_x, max_y, max_z);

	for x = min_x, max_x do
		for y = min_y, max_y do
			for z = min_z, max_z do
				local entities = EntityManager.GetEntitiesInBlock(x, y, z);
				if(entities) then
					for entity,_ in pairs(entities) do
						if((not entity_class or entity:isa(entity_class)) and aabb:Intersect(entity:GetCollisionAABB())) then
							output = output or {};
							output[#output+1] = entity;
						end
					end
				end
			end
		end
	end
	return output;
end

-- Will get all entities within the specified AABB excluding the one passed into it. Args: entityToExclude, aabb
-- @return array of entities
function EntityManager.GetEntitiesByAABBExcept(aabb, excludingEntity)
	local output;
	local min_x, min_y, min_z = aabb:GetMinValues();
	local max_x, max_y, max_z = aabb:GetMaxValues();
	
	min_x, min_y, min_z = BlockEngine:block(min_x, min_y, min_z);
	max_x, max_y, max_z = BlockEngine:block(max_x, max_y, max_z);

	for x = min_x, max_x do
		for y = min_y, max_y do
			for z = min_z, max_z do
				
				local entities = EntityManager.GetEntitiesInBlock(x, y, z);
				if(entities) then
					for entity,_ in pairs(entities) do
						if(entity ~= excludingEntity) then
							output = output or {};
							output[#output+1] = entity;
						end
					end
				end
			end
		end
	end
	return output;
end

-- remove entity by its class_name at the given block position. 
-- all matching entities will be removed. 
function EntityManager.RemoveBlockEntity(bx, by, bz, class_name)
	local entities = EntityManager.GetEntitiesInBlock(bx, by, bz);
	if(entities) then
		local first_match, matches;
		for entity,_ in pairs(entities) do
			if(entity:GetType() == class_name) then
				if(not first_match) then
					first_match = entity;
				else
					matches = matches or {};
					matches[#matches+1] = entity;
				end
			end
		end
		if(first_match) then
			first_match:Destroy();
			if(matches) then
				for _, entity in ipairs(matches) do
					entity:Destroy();	
				end
			end
		end
		return;
	end
end

-- private: 
function EntityManager.GetBlockContainer(bx,by,bz)
	local sparse_index = by*30000*30000+bx*30000+bz;
	local block_container = block_containers[sparse_index];
	if(block_container) then
		return block_container;
	else
		block_container = BlockContainer:new({x=bx,y=by,z=bz})
		block_containers[sparse_index] = block_container;
		return block_container;
	end
end

function EntityManager.SetBlockContainer(bx,by,bz, block_container)
	local sparse_index = by*30000*30000+bx*30000+bz;
	block_containers[sparse_index] = block_container; 
end

-- return array of all entities in a given chunk column
function EntityManager.GetEntitiesInChunkColumn(cx, cz, bCreateIfNotExist)
	local packedChunkPos = ChunkLocation.FromChunkToPackedChunk(cx, cz);
	local chunk_column = chunk_column_entities[packedChunkPos];
	if(not chunk_column and bCreateIfNotExist) then
		chunk_column = commonlib.UnorderedArraySet:new();
		chunk_column_entities[packedChunkPos] = chunk_column;
	end
	return chunk_column;
end

-- get region object
function EntityManager.GetRegionContainer(bx,bz)
	local x = rshift(bx, 9);
	local z = rshift(bz, 9);

	local region = regions[x*128+z];
	if(region) then
		return region;
	else
		region = RegionContainer:new():init(x,z);
		regions[x*128+z] = region;
		region:LoadFromFile();		
		return region;
	end
end

function EntityManager.SaveToFile(bSaveToLastSaveFolder)
	local filename = format("%s%s", ParaWorld.GetWorldDirectory(), default_filename);
	
	local file = ParaIO.open(filename, "w");
	if(file:IsValid()) then
		local root = {name='entities', attr={file_version="0.1"} }
		local entity;
		for entity in pairs(static_objects) do 
			if( entity:IsPersistent() and not entity:IsRegional() and not entity:IsDead()) then
				local node = {name='entity', attr={}};
				entity:SaveToXMLNode(node);
				if(node) then
					root[#root+1] = node;
				end
			end
		end
		if(root) then
			file:WriteString(commonlib.Lua2XmlString(root,true) or "");
		end
		file:close();
	end
		
	for _, region in pairs(regions) do
		if(region:IsModified()) then
			region:SaveToFile();
		end
	end

	EntityManager.SaveAllPlayers();
end

-- set an entity so that its framemove function should always be called regardless of player position
function EntityManager.AddToSentientList(entity)
	if(entity) then
		senstient_list[entity] = true;
	end
end

-- remove an entity so that its framemove function should not be called unless it falls into player sensible range.
function EntityManager.RemoveFromSentientList(entity)
	if(entity) then
		senstient_list[entity] = nil;
	end
end

-- add to framemove entity list. 
-- framemove queue is necessary to prevent crash when adding or removing entity inside framemove function it self. 
local function AddEntityToFrameMoveQueue(entity)
	framemove_queue_size = framemove_queue_size + 1;
	framemove_queue[framemove_queue_size] = entity;
end

local destroy_list = commonlib.vector:new();

function EntityManager:GetDeltaTime()
	return self.deltaTime;
end

-- called every frame to simulate objects 
function EntityManager.FrameMove(deltaTime)
	local self = EntityManager;
	deltaTime = deltaTime/1000;
	self.deltaTime = deltaTime;

	local cur_time = commonlib.TimerManager.GetCurrentTime()/1000;
	local player = EntityManager.GetPlayer();
	if(not player) then
		return;
	end
	commonlib.npl_profiler.perf_begin("EntityManager.FrameMove");

	player:UpdatePosition();

	frame_count = frame_count + 1;
	
	destroy_list:clear();
	
	-- dynamic entities
	EntityManager.FrameMoveDynamicObjects(deltaTime, cur_time, destroy_list);

	-- for always sentient objects, like CommandEntity with timed event
	EntityManager.FrameMoveSentientList(deltaTime, cur_time, destroy_list)

	-- only frame move objects near the current player
	EntityManager.FrameMoveChunksByPlayer(player, 8, deltaTime, cur_time, destroy_list);


	-- frame move entities in pending queues in this frame. 
	EntityManager.FrameMoveQueueThisFrame(deltaTime, cur_time, destroy_list);

	if(#destroy_list>0) then
		for i = 1, #destroy_list do
			destroy_list[i]:Destroy();
		end
		destroy_list:clear();
	end
	commonlib.npl_profiler.perf_end("EntityManager.FrameMove");
end

-- pending list to framemove
function EntityManager.FrameMoveQueueThisFrame(deltaTime, cur_time, destroy_list)
	for i=1, framemove_queue_size do
		local entity = framemove_queue[i];
		entity:CheckFrameMove(deltaTime, cur_time, true);
	end
	framemove_queue_size = 0;
end

-- set focus to the given entity. 
-- The entity class's SetFocus() function should always call this fuction before it return true. 
function EntityManager.SetFocus(entity)
	if(cur_focus~=entity) then
		if(cur_focus) then
			cur_focus:OnFocusOut();
		end
		if(entity) then
			cur_focus = entity;
			entity:OnFocusIn();
		end
	end
end

-- get current focus
function EntityManager.GetFocus()
	return cur_focus;
end

-- dynamic object is always framemoved until they are dead. 
function EntityManager.FrameMoveDynamicObjects(deltaTime, cur_time, destroy_list)
	-- dynamic objects
	commonlib.npl_profiler.perf_begin("EntityManager.FrameMoveDynamicObjects");
	local i = 1;
	while i<=#dynamic_objects do
		local obj = dynamic_objects[i]
		obj:FrameMove(deltaTime);
		if(obj:IsDead()) then
			destroy_list[#destroy_list+1] = obj;
			dynamic_objects:remove(i);
		else
			i=i+1;
		end
	end
	commonlib.npl_profiler.perf_end("EntityManager.FrameMoveDynamicObjects");
end

-- all entities in the radius of the given player is framemoved. 
-- @param grid_radius: default to 8 chunks near player position. 
function EntityManager.FrameMoveChunksByPlayer(playerEntity, grid_radius, deltaTime, cur_time, destroy_list)
	local blockX, blockY, blockZ = playerEntity:GetBlockPos(); 
	local cx, cz = ChunkLocation:GetChunkPosFromWorldPos(blockX, blockZ);
	grid_radius = grid_radius or 8; -- so the actual radius is 8*16 = 128 meters. 
	for i = -grid_radius, grid_radius do
		for j = -grid_radius, grid_radius do
			local entities = EntityManager.GetEntitiesInChunkColumn(cx+i, cz+j);
			if(entities) then
				EntityManager.FrameMoveEntities(entities, deltaTime, cur_time, destroy_list);
			end
		end
	end
end

-- all entities in the list is framemoved. 
function EntityManager.FrameMoveEntities(entities, deltaTime, cur_time, destroy_list)
	-- static object may also has framemove
	for i=1, #entities do 
		local entity = entities[i];
		-- skip sentient object since we will framemove sentient object in another list. 
		if(entity and not senstient_list[entity]) then
			if(entity:IsDead()) then
				destroy_list[#destroy_list+1] = entity;
			else
				if( entity:CheckFrameMove(deltaTime, cur_time) ) then
					AddEntityToFrameMoveQueue(entity);
				end
			end
		end
	end
end

-- for always sentient objects, like CommandEntity with timed event
-- @param deltaTime: in seconds
-- @param cur_time: in seconds
function EntityManager.FrameMoveSentientList(deltaTime, cur_time, destroy_list)
	for entity,_ in pairs(senstient_list) do 
		if(entity:IsDead()) then
			destroy_list[#destroy_list+1] = entity;
		else
			if( entity:CheckFrameMove(deltaTime, cur_time) ) then
				AddEntityToFrameMoveQueue(entity);
			end
		end
	end
end