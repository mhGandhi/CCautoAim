--will need a sec to train on target after aquiring it, works better on further distances
--don't forget to give your engines FE
--be careful not to inhibit the proper functionality of the engines with your redstone lines (don't power the engines on accident)
--no, you don't need a command computer, an advanced one suffices (maybe even a normal one idk didn't try and don't know if it has all the apis I use)
--feel free to tweak the movementspeeds further below

--don't forget to set Spring pos

--only tested facing north and east btw

--vars
--side firesignal
fireSide = "front"
--side assemblesignal
assembleSide = "back"
--pos of the gun (part attached to mount)
springPos = {0,0,0}
--dimension the cannon is in
dimension = "minecraft:overworld"
--players not to target (playername)
whitelist = {"mahatmagandhrian","player2"}
--range to target
targetRange = (32*16) --32 chunks
--range to shoot
fireRange = (30*16) -- 30 chunks

--motor direction change cooldown, needed to avoid anti-lag breaking of transmission
DirChgCD = 0.35
--projectileSpeed in m/s
ProjectileSpeed = 167 --speed of flak round with barrel length 6 ~= 167

---some funcs
--convert degrees from -180 to 180, 90° off to directions corresponding with turret azimuth; whatever works, works
function toTurrAzi(pA)
    if(pA<0)then
        pA = pA +360
    end
    pA = pA - 90
    if(pA<0)then
        pA = pA +360
    end
    return pA
end
--hyp
function hyp(a,b)
    return math.sqrt(a*a+b*b)
end
--hyp3
function hyp3(a,b,c)
	return hyp(a,hyp(b,c))
end
--atan2, danke Internet
function atan2(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 then
        if y >= 0 then
            return math.atan(y / x) + math.pi
        else
            return math.atan(y / x) - math.pi
        end
    else
        if y > 0 then
            return math.pi / 2
        elseif y < 0 then
            return -math.pi / 2
        else
            return nil  -- Undefined when x = 0 and y = 0
        end
    end
end
--exit
function exit()
	fire(false)
	assemble(false)
    print("exiting...")
    exitDochffs(1)--need func hbibi finde keine exit funktion für CC amk also einfach exception
end
--switch firing
function fire(pFire)
    redstone.setOutput(fireSide,pFire)
end
--switch assemble
function assemble(pAssemble)
    redstone.setOutput(assembleSide,pAssemble)
end
--interpolation for motor speed
function interpolate(pRangeOut, pRangeIn, pIn)--range out, range in, in
	
	result = ((pIn)/pRangeIn)*pRangeOut
	
	--if pIn < 0 then
        --result = -result
    --end
	--nicht lineare interpolation iwie immer zu schnell und kekst sich nicht aus
	
	return result
end

--SETUP
local motors = {}
local i = 1
for _,name in ipairs(peripheral.getNames()) do--peripheral.find("electric_motor")) do
	if(
		peripheral.getType(name)=="electric_motor"
	)then
		motors[i] = name
		i = i+1
	end
	if(i == 3)then
		break
	end
end

if(motors[2] == nil)then
	print(" not enough motors")
	exit()
end

local mot1 = peripheral.wrap(motors[1])--peripheral.wrap(mot1side)--
local mot2 = peripheral.wrap(motors[2])--peripheral.wrap(mot2side)--

cmount = peripheral.find("blockReader")
sensor = peripheral.find("playerDetector")

yawDirMod = 1
elvDirMod = 1

--validating setup
if(
	cmount == nil or
	--not cmount.getType() == "blockReader" or
	not cmount.getBlockName()=="createbigcannons:cannon_mount")
then
    print("cannon mount not found")
    exit()
end
if(
    sensor == nil -- or 
    --not sensor.getType() == "playerDetector"
     ) 
then
    print("player sensor not found")
    exit()
end
--done validating
mot1.stop()
mot2.stop()
--calibrate
motAzi = nil
motElv = nil
 
function calibrateMot(pMot)
    print("calibrating...")
    fire(false)
	pMot.stop()
    assemble(false)
    assemble(true)
    local data0 = cmount.getBlockData()
    local pitch0 = data0["CannonPitch"]
	local yaw0 = data0["CannonYaw"]
    print("    before: " .. pitch0 .. " " .. yaw0)
    
	sleep(0.1)
    pMot.setSpeed(5)
    sleep(0.5)
    pMot.stop()
    
    local data1 = cmount.getBlockData()
    local pitch1 = data1["CannonPitch"]
	local yaw1 = data1["CannonYaw"]
    print("    after: " .. pitch1 .. " " ..  yaw1 )
    assemble(false)
    
    local pitchChg = pitch0~=pitch1
    local yawChg = (yaw0~=yaw1) --and (math.abs(yaw0-yaw1)~=180 and math.abs(yaw0-yaw1)~=90 and math.abs(yaw0-yaw1)~=270))
    
    if(pitchChg)then
    print("    pch")
    end
    if(yawChg)then
    print("    ych")
    end 
    
    if(pitchChg and (not yawChg))then
        motElv = pMot
        if(pitch1>pitch0)then
            elvDirMod = 1
        else
            elvDirMod = -1
        end
        print("    for Elevation, dirmod: " .. elvDirMod)
    end
    if(yawChg and (not pitchChg))then
        motAzi = pMot
        if((math.abs(yaw0-yaw1)>10)or yaw1>yaw0)then
            aziDirMod = 1
        else
            aziDirMod = -1
        end
        print("    for Azimuth, dirmod: " .. aziDirMod )
    end
end

--nur schauen dass die mount werte nicht dumm auf 0 sind
assemble(true)
mot1.setSpeed(5)
mot2.setSpeed(5)
sleep(0.5)
mot1.stop()
mot2.stop()
assemble(false)

calibrateMot(mot1)
--os.pullEvent("key")
calibrateMot(mot2)

--for temps //TODO einbinden in config
function calibrateManual()
    motAzi = mot1
    motElv = mot2
    
    aziDirMod = -1
    elvDirMod = 1
end
--calibrateManual()

if(motAzi == nil)then
    print("yaw motor faulty")
    exit()
end
if(motElv == nil)then
    print("elevation motor faulty")
    exit()
end
print("calibration complete")
--done calibrating


function cTS(pC)
    return ("[" .. pC[1] .. "|" .. pC[2] .. "|" .. pC[3] .. "]")
end

function elvSpd(pS)
    if(os.clock()-lastElvChg<DirChgCD)then
        return
    end
    
    local suc,res = pcall(
        function()
			motElv.setSpeed(pS*elvDirMod)
        end
    )
    if(suc)then
        lastElvChg = os.clock()
    end
end
function aziSpd(pS)
    if(os.clock()-lastAziChg<DirChgCD)then
        return
    end
    
    local suc,res = pcall(
        function()
			motAzi.setSpeed(pS*aziDirMod)
        end
    )
    if(suc)then
        lastAziChg = os.clock()
    end
end

--project pos of target at position @pTargetPos moving with @pTargetVelms for pTime seconds
function projectPos(pTargetPos, pTargetVelms, pTime)
	return {pTargetPos[1]+pTargetVelms[1]*pTime,pTargetPos[2]+pTargetVelms[2]*pTime,pTargetPos[3]+pTargetVelms[3]*pTime}
end

--returns whether player is whitelisted
function isWhitelisted(player)
		for j,whPl in ipairs(whitelist) do --check if player is whitelisted
			if(whPl == player)then
				print(" on whitelist")
				return true
				end
		end
		return false
end

--define whether position presents a valid target
function isValidTarget(pos)
		
		local pointOff = {pos[1]-springPos[1],pos[2]-springPos[2],pos[3]-springPos[3]}
		local dist = hyp3(pointOff[2],pointOff[1],pointOff[3])
		local elvPlRad = atan2(-pointOff[2],hyp(pointOff[1],pointOff[3]))
		if(elvPlRad == nil)then
			elvPlRad = 0
		end
		local elvPl = -1*math.deg(elvPlRad)
		
		
		if(dist<10 or dist > targetRange)then--if bad distance
			print(" in bad distance")
			return false
		end
		
		if(math.abs(elvPl)>45)then--if out of elev range
			print(" out of elv angle")
			return false
		end
	
	--print(" aquired")
	return true
end

--return List of pPlayers that match Valid Target criteria (same Order as Input)
function getValidTargets(pPlayers)
	
	local ret = {}
	
	for i, pl in ipairs(pPlayers) do
		pos = sensor.getPlayerPos(pl)
		if(
			pos["x"] ~= nil
			and pos["dimension"] == dimension
			)then --if pos emtpy
			term.write(pl)
			
			spot = {pos["x"],pos["y"],pos["z"]}
			if(
				isValidTarget(spot)
				and not isWhitelisted(pl)
				)then
				table.insert(ret,pl)
				print("")
			end
		end
	end
	
	--//TODO nach Distanz sortieren?
	
	return ret
end

lastElvChg = os.clock()
lastAziChg = os.clock()
	
while(true)do

	--TARGET SL
	validTargets = {}
	repeat
		print("scanning for targets...")
		local players = sensor.getPlayersInRange(fireRange+16)--radius from playerdetector -> +16
	
		validTargets = getValidTargets(players)
		if(validTargets[1] == nil)then
			print("no targets found")
			sleep(1)
		end
		
	until(validTargets[1] ~= nil)--until not empty

	--validTargets[1] = "mahatmagandhrian"
	selectedTarget = 1 --auswählen vtl
	
	pPos = sensor.getPlayerPos(validTargets[selectedTarget])
	

	pointOff = {0,0,0}
	if(pPos == nil)then--//TODO should check whether target exists
		print("target error")
		exit()
	end
	targetPos = {pPos["x"],pPos["y"],pPos["z"]}
	targetAquired = true
	
	lastCycle = os.clock()
	targetVelocity = {0,0,0}
	lastPos = {0,0,0}
	projectedPos = {0,0,0}

	mData = nil
	
	assemble(true)
	--loop ninja
	while(targetAquired)do
		mData = cmount.getBlockData()
		pPos = sensor.getPlayerPos(validTargets[selectedTarget])
		targetPos = {pPos["x"],pPos["y"],pPos["z"]}
		targetPos[2] = targetPos[2]+0.5
		---commands.exec("/particle minecraft:block_marker dirt " .. targetPos["x"] .. " " .. targetPos["y"]-1 .. " " .. targetPos["z"])
		
		--mov pred
		cycleduration = os.clock()-lastCycle
		
		targetVel = {targetPos[1]-lastPos[1],targetPos[2]-lastPos[2],targetPos[3]-lastPos[3]}
		velInMpS = {targetVel[1]*(1/cycleduration),targetVel[2]*(1/cycleduration),targetVel[3]*(1/cycleduration)}
		vel = hyp3(velInMpS[1],velInMpS[2],velInMpS[3])
		if(vel>0)then
			
			--commands.say("vel " .. vel)
			travelTime = hyp3(targetPos[2]-springPos[2],targetPos[1]-springPos[1],targetPos[3]-springPos[3])/ProjectileSpeed
			projectedPos = projectPos(targetPos, velInMpS, travelTime)
			--commands.exec("particle minecraft:block_marker barrier " .. projectedPos[1] .. " " .. projectedPos[2] .. " " .. projectedPos[3])
			pointOff = {projectedPos[1]-springPos[1],projectedPos[2]-springPos[2],projectedPos[3]-springPos[3]}
				--pointOff = {targetPos[1]-springPos[1],targetPos[2]-springPos[2],targetPos[3]-springPos[3]}--TMP
		else
			pointOff = {targetPos[1]-springPos[1],targetPos[2]-springPos[2],targetPos[3]-springPos[3]}
		end
		
		lastPos = {targetPos[1],targetPos[2],targetPos[3]}
		lastCycle = os.clock()
		
		---commands.say("proPos " .. projectedPos[1] .. " " .. projectedPos[2] .. " " .. projectedPos[3])
		
		--setting point to aim at
		--pointOff = {targetPos["x"]-springPos[1],targetPos["y"]-springPos[2],targetPos["z"]-springPos[3]}--
		
		--distance to point aimed at
		dist = hyp3(pointOff[2],pointOff[1],pointOff[3])
		--commands.say("dist " .. dist)
		--print("turret: " .. cTS(springPos))
		--print("target: " .. cTS(targetPos))
		--print("offset: " .. cTS(pointOff))
		--print("tarVel: " .. cTS(targetVel) .. "->" .. hyp(targetVel[2],hyp(targetVel[1],targetVel[3])) .. " in " .. cycleduration)
		
		
		--compute degree offset in Azimuth
		aziPlRad = atan2(pointOff[3],pointOff[1])
		if(aziPlRad == nil)then
			aziPlRad = 0
		end
		aziPl = toTurrAzi(math.deg(aziPlRad))
		aziOff = aziPl - mData["CannonYaw"]
		--print(aziPl .. "° azi c: " .. mData["CannonYaw"])
		
		--compute degree offset in Elevation
		elvPlRad = atan2(-pointOff[2],hyp(pointOff[1],pointOff[3]))
		if(elvPlRad == nil)then
			elvPlRad = 0
		end
		elvPl = -1*math.deg(elvPlRad)
		elvOff = elvPl - mData["CannonPitch"]
		--print(elvPl .. "° elv c: " .. mData["CannonPitch"])
		
		
		--print("azi diff " .. aziOff)
		--print("elv diff " .. elvOff)
		
		--ADJUST ELV SPEED
		if(math.abs(elvPl)>45 or math.abs(elvOff)<=0.5)then--tolerance
			if(motElv.getSpeed()~=0)then
				motElv.stop()
				lastElvChg = os.clock()
			end
		else
			elvSpd(interpolate(160,45,elvOff))
		end
		
		--ADJUST AZI SPEED
		--set azimuth offset in proper direction (max 180)
		if(math.abs(aziOff)>=180)then
			if(aziOff>0)then
				aziOff = aziOff -360
			else--if aziOff<0
				aziOff = aziOff +360
			end
		end
		if(math.abs(aziOff)<=0.5)then--tolerance
			if(motAzi.getSpeed()~=0)then
				motAzi.stop()
				lastAziChg = os.clock()
			end
		else
			if(aziOff>45)then
				aziSpd(128)
			elseif(aziOff<-45)then
				aziSpd(-128)
			else
				aziSpd(interpolate(100,45,aziOff))
			end
		end
		
		--FIRE
		if(--conditions for firing
			math.abs(aziOff)<6--within 6 degrees of target cone azi
			and math.abs(elvOff)<6--within 6 degrees of target cone elv
			and dist>16
			--and math.abs(elvPl)<=45--within 45 degrees of gun
			--and targetPos[2]>60--only antiair
			and dist<fireRange--30 chunks
			)
		then
			fire(true)
		else
			fire(false)
			--lose target
			if(not isValidTarget(targetPos))then
				targetAquired = false;
				assemble(false)
				if(motAzi.getSpeed()~=0)then
					motAzi.stop()
					lastAziChg = os.clock()
				end
				if(motElv.getSpeed()~=0)then
					motElv.stop()
					lastElvChg = os.clock()
				end
			end
		end
	end
end

--pfade predicten#
--parabelförmige wären krass
--distanz miteinberechnen#
--nahe gegner nicht anvisieren#
--konfigurierbare locked angles
--locked areas
--visiersystem
--exit func on termination
--config in file
--intercannon communication
--zielauswahl