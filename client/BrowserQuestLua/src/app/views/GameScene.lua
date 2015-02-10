
local Camera = import("..models.Camera")
local Types = import("..models.Types")
local Entity = import("..models.Entity")
local Orientation = import("..models.Orientation")
local Utilitys = import("..models.Utilitys")
local GameScene = class("GameScene", cc.load("mvc").ViewBase)
local Scheduler = cc.Director:getInstance():getScheduler()


function GameScene:onCreate()
	-- self:createUI()
	self:createMap()
end

function GameScene:createUI()
	local guiNode = display.newNode():addTo(self)
	guiNode:setLocalZOrder(100)

	local resPath = app:getResPath("border.png")
	local sp = ccui.Scale9Sprite:create(resPath)
		:align(display.CENTER, display.cx, display.cy)
		:addTo(guiNode)
		:setContentSize(display.width, display.height)

	local bottom = display.newNode():addTo(guiNode)
	local bottomBg = display.newSprite("#bar-container.png")
    	:align(display.LEFT_BOTTOM, 0, 0)
    	:addTo(bottom)
    local blood = display.newSprite("#healthbar.png")
    	:align(display.LEFT_BOTTOM, 3, 4)
    	:addTo(bottom)
end

function GameScene:createMap()
	local mapNode = display.newNode():addTo(self)
	mapNode:setLocalZOrder(10)

	-- register listener
    local listener = cc.EventListenerTouchOneByOne:create()
    listener:registerScriptHandler(handler(self, self.onTouchBegan), cc.Handler.EVENT_TOUCH_BEGAN)
    listener:registerScriptHandler(handler(self, self.onTouchMoved), cc.Handler.EVENT_TOUCH_MOVED)
    listener:registerScriptHandler(handler(self, self.onTouchEnded), cc.Handler.EVENT_TOUCH_ENDED)
    local eventDispatcher = cc.Director:getInstance():getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, mapNode)

    -- register keyboard listener
    listener = cc.EventListenerKeyboard:create()
    listener:registerScriptHandler(handler(self, self.onKeyPressed), cc.Handler.EVENT_KEYBOARD_PRESSED)
    listener:registerScriptHandler(handler(self, self.onKeyReleased), cc.Handler.EVENT_KEYBOARD_RELEASED)
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, mapNode)

	local map = cc.TMXTiledMap:create("maps/map.tmx"):addTo(mapNode)
	map:setScale(1)

	Game:setMap(map)

	self.map_ = map

	self.camera_ = Camera.new(map)
	-- create player
	local player = Game:createUser()
	self.camera_:look(player, 1)

	Game:onPlayerUIExit(handler(self, self.showRevive))

	Game:createEntitys()
	Game:createOnlinePlayers()

	-- local rat = require("app.models.MobRat").new()
	-- rat:setMapPos(cc.p(17, 288))
	-- Game:addMob(rat)

	-- local guard = require("app.models.NPCGuard").new()
	-- guard:setMapPos(cc.p(16, 292))
	-- Game:addNPC(guard)
	-- guard:talkSentence_()

	-- local entity = require("app.models.ItemAxe").new()
	-- entity:setMapPos(cc.p(16, 293))
	-- Game:addObject(entity)
end

function GameScene:showRevive()
	local bg = display.newSprite("#parchment.png")
	bg:setTag(201)
	bg:align(display.CENTER, display.cx, display.cy)
	bg:setScaleX(0.1)
	bg:setLocalZOrder(101)
	bg:addTo(self)
	bg:scaleTo({scaleX = 1, scaleY = 1, time = 1, onComplete = function()
		local bounding = bg:getBoundingBox()
		local ttfConfig = {
			fontFilePath = "fonts/arial.ttf",
			fontSize = 24
			}
		local label = cc.Label:createWithTTF(ttfConfig, "You Are Dead!", cc.VERTICAL_TEXT_ALIGNMENT_CENTER)
		label:align(display.CENTER, bounding.width/2, bounding.height/2 + 10)
		label:setTextColor(cc.c4b(0, 0, 0, 250))
		label:addTo(bg)

		ccui.Button:create("buttonRevive.png", "buttonRevive.png", "buttonRevive.png", ccui.TextureResType.plistType)
		    :align(display.CENTER, bounding.width/2, bounding.height/2 - 30)
		    :addTo(bg)
		    :onTouch(function(event)
		        if "ended" == event.name then
		            local playerData = Game:getPlayerData()
		            local player = Game:getUser()
		            playerData.imageName = player.imageName_
		            playerData.weaponName = player.weaponName_
		            playerData.nickName = player.name_
		            playerData.pos = player.curPos_
		            playerData.id = player.id
		            Game:sendCmd("user.reborn", playerData)
		        end
		    end)
		end})
end


function GameScene:onTouchBegan(touch, event)
	return true
end

function GameScene:onTouchMoved(touch, event)
	local diff = touch:getDelta()

	local dis = diff.x * diff.x + diff.y * diff.y
	if dis > 50 then
		self.isMoving = true
		self.camera_:move(diff.x, diff.y)
	end
end

function GameScene:onTouchEnded(touch, event)
	if self.isMoving then
		self.isMoving = false
		return
	end

	local pos = touch:getLocation()
	local mapPospx = Game:getMap():convertToNodeSpace(pos)
	local mapPos = Utilitys.px2pos(mapPospx)

	local entitys = Game:findEntityByPos(mapPos)
	local entity = entitys[1]

	if entity then
		local entityType = entity:getType()
		if entity.TYPE_MOBS_BEGIN < entityType and entityType < entity.TYPE_MOBS_END then
			Game:getUser():attack(entity)
		elseif entity.TYPE_NPCS_BEGIN < entityType and entityType < entity.TYPE_NPCS_END then
			Game:getUser():talk(entity)
		elseif (entity.TYPE_ARMORS_BEGIN < entityType and entityType < entity.TYPE_ARMORS_END)
			or (entity.TYPE_WEAPONS_BEGIN < entityType and entityType < entity.TYPE_WEAPONS_END) then
			Game:getUser():loot(entity)
			-- Game:getUser():changeWeapon("axe.png")
		end
	else
		Game:getUser():walk(mapPos)
		-- local drawNode = Utilitys.genPathNode(path)
		-- Game:getMap():removeChildByTag(111)
		-- Game:getMap():addChild(drawNode, 100, 111)
	end
end

function GameScene:onKeyPressed(keyCode, event)
	-- scheduleScriptFunc(unsigned int handler, float interval, bool paused)
	local player = Game.getInstance():getUser()
	if cc.KeyCode.KEY_LEFT_ARROW == keyCode then
		player:walkStep(Orientation.LEFT)
	elseif cc.KeyCode.KEY_RIGHT_ARROW == keyCode then
		player:walkStep(Orientation.RIGHT)
	elseif cc.KeyCode.KEY_UP_ARROW == keyCode then
		player:walkStep(Orientation.UP)
	elseif cc.KeyCode.KEY_DOWN_ARROW == keyCode then
		player:walkStep(Orientation.DOWN)
	else
		print("keyCode:" .. keyCode)
	end
end

function GameScene:onKeyReleased(keyCode, event)
	if cc.KeyCode.KEY_LEFT_ARROW == keyCode then
	elseif cc.KeyCode.KEY_RIGHT_ARROW == keyCode then
	elseif cc.KeyCode.KEY_UP_ARROW == keyCode then
	elseif cc.KeyCode.KEY_DOWN_ARROW == keyCode then
	else
		print("keyCode:" .. keyCode)
	end
end


return GameScene
