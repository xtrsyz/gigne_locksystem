----------------------
-- Author : Deediezi
-- Version 4.5
--
-- Contributors : No contributors at the moment.
--
-- Github link : https://github.com/Deediezi/FiveM_LockSystem
-- You can contribute to the project. All the information is on Github.

--  Server side

owners = {} -- owners[plate] = identifier
secondOwners = {} -- secondOwners[plate] = {identifier, identifier, ...}
MySQL.ready(function ()
    MySQL.Async.fetchAll("SELECT `plate`, `owner` FROM owned_vehicles",{}, function(data)
        for _,v in pairs(data) do
            local plate = string.lower(v.plate)
            owners[plate] = v.owner
        end
    end)
end)

function GetIDFromSource(ID) --(Thanks To WolfKnight [forum.FiveM.net])
    -- return GetPlayerIdentifiers(ID)[1]
    local IDs = GetPlayerIdentifiers(ID)
    for k, CurrentID in pairs(IDs) do
        local ID = stringsplit(CurrentID, ':')
        if (ID[1]:lower() == Config.PlayerIdentifier) then
            return ID[2]:lower()
        end
    end
    return nil
end

function stringsplit(input, seperator)
	if seperator == nil then
		seperator = '%s'
	end
	
	local t={} ; i=1
	
	for str in string.gmatch(input, '([^'..seperator..']+)') do
		t[i] = str
		i = i + 1
	end
	
	return t
end

RegisterServerEvent("ls:retrieveVehiclesOnconnect")
AddEventHandler("ls:retrieveVehiclesOnconnect", function()
    local src = source
    local srcIdentifier = GetIDFromSource(src)
    local data = MySQL.Sync.fetchAll("SELECT `plate`, `owner` FROM owned_vehicles",{})
    for _,v in pairs(data) do
        local plate = string.lower(v.plate)
        owners[plate] = v.owner
    end
    for plate, plyIdentifier in pairs(owners) do
        if(plyIdentifier == srcIdentifier)then
            local _plate = plate
            TriggerClientEvent("ls:newVehicle", src, _plate, nil, nil)
        end
    end

    for plate, identifiers in pairs(secondOwners) do
        for _, plyIdentifier in ipairs(identifiers) do
            if(plyIdentifier == srcIdentifier)then
                TriggerClientEvent("ls:newVehicle", src, plate, nil, nil)
            end
        end
    end
end)

RegisterServerEvent("ls:addOwner")
AddEventHandler("ls:addOwner", function(plate)
    local src = source
    local identifier = GetIDFromSource(src)
    local plate = string.lower(plate)

    owners[plate] = identifier
end)
RegisterServerEvent("ls:addOwnerWithIdentifier")
AddEventHandler("ls:addOwnerWithIdentifier", function(targetIdentifier, plate)
    local plate = string.lower(plate)

    owners[plate] = targetIdentifier
end)
RegisterServerEvent("ls:addSecondOwner")
AddEventHandler("ls:addSecondOwner", function(targetIdentifier, plate)
    local plate = string.lower(plate)

    if(secondOwners[plate])then
        table.insert(secondOwners[plate], targetIdentifier)
    else
        secondOwners[plate] = {targetIdentifier}
    end
end)

RegisterNetEvent("ls:checkOwner")
AddEventHandler("ls:checkOwner", function(localVehId, plate, lockStatus)
    local plate = string.lower(plate)
    local src = source
    local hasOwner = false
    local identifier = GetIDFromSource(src)
    if(not owners[plate])then
        TriggerClientEvent("ls:getHasOwner", src, nil, localVehId, plate, lockStatus)
    else
        if(owners[plate] == "locked")then
            TriggerClientEvent("ls:notify", src, _U('keys_not_inside'))
        else
            if(identifier == owners[plate]) then
                TriggerClientEvent("ls:getHasOwner", src, nil, localVehId, plate, lockStatus)
            else
                TriggerClientEvent("ls:getHasOwner", src, true, localVehId, plate, lockStatus)
            end
        end
    end
end)

RegisterServerEvent("ls:lockTheVehicle")
AddEventHandler("ls:lockTheVehicle", function(plate)
    owners[plate] = "locked"
end)

RegisterServerEvent("ls:haveKeys")
AddEventHandler("ls:haveKeys", function(target, vehPlate, cb)
    targetIdentifier = GetPlayerIdentifiers(target)[1]
    hasKey = false

    for plate, identifier in pairs(owners) do
        if(plate == vehPlate and identifier == targetIdentifier)then
            hasKey = true
            break
        end
    end
    for plate, identifiers in pairs(secondOwners) do
        if(plate == vehPlate)then
            for _, plyIdentifier in ipairs(identifiers) do
                if(plyIdentifier == targetIdentifier)then
                    hasKey = true
                    break
                end
            end
        end
    end

    if(hasKey)then
        cb(true)
    else
        cb(false)
    end
end)

RegisterServerEvent("ls:updateServerVehiclePlate")
AddEventHandler("ls:updateServerVehiclePlate", function(oldPlate, newPlate)
    local oldPlate = string.lower(oldPlate)
    local newPlate = string.lower(newPlate)

    if(owners[oldPlate] and not owners[newPlate])then
        owners[newPlate] = owners[oldPlate]
        owners[oldPlate] = nil
    end
    if(secondOwners[oldPlate] and not secondOwners[newPlate])then
        secondOwners[newPlate] = secondOwners[oldPlate]
        secondOwners[oldPlate] = nil
    end
end)

-- Piece of code from Scott's InteractSound script : https://forum.fivem.net/t/release-play-custom-sounds-for-interactions/8282
RegisterServerEvent('ls:PlayWithinDistance')
AddEventHandler('ls:PlayWithinDistance', function(maxDistance, soundFile, soundVolume)
    TriggerClientEvent('ls:PlayWithinDistance', -1, source, maxDistance, soundFile, soundVolume)
end)

if Config.versionChecker then
    PerformHttpRequest("https://raw.githubusercontent.com/xtrsyz/gigne_locksystem/master/VERSION", function(err, rText, headers)
		if rText then
			if tonumber(rText) > tonumber(_VERSION) then
				print("\n---------------------------------------------------")
				print("LockSystem : An update is available !")
				print("---------------------------------------------------")
				print("Current : " .. _VERSION)
				print("Latest  : " .. rText .. "\n")
			end
		else
			print("\n---------------------------------------------------")
			print("Unable to find the version.")
			print("---------------------------------------------------\n")
		end
	end, "GET", "", {what = 'this'})
end



RegisterServerEvent("esx_vehicleshop:setVehicleOwned")
AddEventHandler("esx_vehicleshop:setVehicleOwned", function(vehicleProps, vehicleModel)
    local src = source
    local srcIdentifier = GetIDFromSource(src)
    local plate = string.gsub(string.lower(vehicleProps.plate), '^%s*(.-)%s*$', '%1')
    owners[plate] = srcIdentifier
    TriggerClientEvent("ls:newVehicle", src, plate, nil, nil)
end)

RegisterServerEvent("ls:setKeyOwned")
AddEventHandler("ls:setKeyOwned", function(vehiclePlate)
    local src = source
    local srcIdentifier = GetIDFromSource(src)
    local plate = string.gsub(string.lower(vehiclePlate), '^%s*(.-)%s*$', '%1')
    owners[plate] = srcIdentifier
    TriggerClientEvent("ls:newVehicle", src, plate, nil, nil)
end)