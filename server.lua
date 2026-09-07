local rentals, busy, stationLocks, cooldowns = {}, {}, {}, {}

local function reply(src, ok, message, netId)
    TriggerClientEvent('figma_bikerental:result', src, ok, message, netId)
end

local function account(src)
    if GetResourceState('es_extended') == 'started' then
        local player = exports['es_extended']:getSharedObject().GetPlayerFromId(src)
        if not player then return nil end
        local bank = Config.PaymentAccount == 'bank'
        return {
            balance = function()
                if bank then
                    local value = player.getAccount('bank')
                    return value and value.money or 0
                end
                return player.getMoney()
            end,
            charge = function(amount)
                if bank then player.removeAccountMoney('bank', amount, 'Fahrradverleih')
                else player.removeMoney(amount, 'Fahrradverleih') end
                return true
            end
        }
    end
    return nil
end

local function locationFor(src, index)
    if type(index) ~= 'number' or index % 1 ~= 0 then return nil end
    local location = Config.Locations[index]
    local ped = GetPlayerPed(src)
    if not location or ped == 0 or GetEntityHealth(ped) <= 0 then return nil end
    if #(GetEntityCoords(ped) - location.coords) > Config.ServerDistance then return nil end
    return location, ped
end

local function throttled(src)
    local now = os.time()
    if busy[src] or (cooldowns[src] and now - cooldowns[src] < Config.RequestCooldown) then return true end
    cooldowns[src] = now
    return false
end

RegisterNetEvent('figma_bikerental:rent', function(index, bikeId)
    local src = source
    if throttled(src) then reply(src, false, 'Bitte kurz warten.'); return end
    local location, ped = locationFor(src, index)
    if not location then reply(src, false, 'Du bist nicht am Fahrradverleih.'); return end
    if GetVehiclePedIsIn(ped, false) ~= 0 then reply(src, false, 'Bitte zuerst aussteigen.'); return end
    if rentals[src] and DoesEntityExist(rentals[src]) then
        reply(src, false, 'Gib zuerst dein aktuelles Fahrrad mit G am Verleih zurück.'); return
    end
    rentals[src] = nil
    local bike
    for _, item in ipairs(Config.Bikes) do if item.id == bikeId then bike = item; break end end
    if not bike or type(bike.price) ~= 'number' or bike.price < 0 or bike.price % 1 ~= 0 then
        reply(src, false, 'Ungültiges Fahrrad oder Preis.'); return
    end
    local bucket = GetPlayerRoutingBucket(src)
    local lockKey = tostring(index) .. ':' .. tostring(bucket)
    if stationLocks[lockKey] then reply(src, false, 'Die Ausgabe ist gerade belegt.'); return end
    local token = {}
    busy[src], stationLocks[lockKey] = token, token
    local created, committed = nil, false
    local ok, err = xpcall(function()
        local wallet = account(src)
        if not wallet then reply(src, false, 'ESX oder deine Spielerdaten sind noch nicht verfügbar.'); return end
        if wallet.balance() < bike.price then reply(src, false, 'Nicht genug Geld.'); return end
        local spawn = location.spawn
        local position = vector3(spawn.x, spawn.y, spawn.z)
        for _, vehicle in ipairs(GetAllVehicles()) do
            if GetEntityRoutingBucket(vehicle) == bucket and
                #(GetEntityCoords(vehicle) - position) < Config.SpawnClearRadius then
                reply(src, false, 'Der Fahrrad-Ausgabepunkt ist blockiert.'); return
            end
        end
        created = CreateVehicleServerSetter(GetHashKey(bike.model), 'bike', spawn.x, spawn.y, spawn.z, spawn.w)
        if not created or created == 0 then reply(src, false, 'Fahrrad konnte nicht erstellt werden. Es wurde nichts abgebucht.'); return end
        local deadline = GetGameTimer() + 3000
        while not DoesEntityExist(created) and GetGameTimer() < deadline do Wait(50) end
        if not DoesEntityExist(created) then reply(src, false, 'Fahrrad konnte nicht erstellt werden. Es wurde nichts abgebucht.'); return end
        SetEntityRoutingBucket(created, bucket)
        local netId = NetworkGetNetworkIdFromEntity(created)
        if netId == 0 then reply(src, false, 'Netzwerkfehler bei der Ausgabe. Es wurde nichts abgebucht.'); return end
        -- Nach möglichem Wait Sitzung, Standort und Kontostand erneut prüfen.
        if busy[src] ~= token or not GetPlayerName(src) then return end
        local currentLocation, currentPed = locationFor(src, index)
        if not currentLocation or GetPlayerRoutingBucket(src) ~= bucket or GetVehiclePedIsIn(currentPed, false) ~= 0 then
            reply(src, false, 'Ausleihe abgebrochen: Du hast den Ausgabebereich verlassen.'); return
        end
        wallet = account(src)
        if not wallet or wallet.balance() < bike.price or not wallet.charge(bike.price) then
            reply(src, false, 'Bezahlung fehlgeschlagen.'); return
        end
        -- Ab hier kein Wait: Zahlung und Zuordnung bleiben zusammen.
        committed = true
        rentals[src] = created
        reply(src, true, bike.name .. ' für $' .. bike.price .. ' gemietet.', netId)
    end, debug.traceback)
    if not committed and created and created ~= 0 and DoesEntityExist(created) then DeleteEntity(created) end
    if busy[src] == token then busy[src] = nil end
    if stationLocks[lockKey] == token then stationLocks[lockKey] = nil end
    if not ok then
        print(('[figma_bikerental] Spieler %s: %s'):format(src, err))
        reply(src, false, 'Die Ausleihe ist fehlgeschlagen. Bitte informiere das Serverteam.')
    end
end)

RegisterNetEvent('figma_bikerental:return', function(index)
    local src = source
    if throttled(src) then reply(src, false, 'Bitte kurz warten.'); return end
    local location = locationFor(src, index)
    if not location then reply(src, false, 'Du bist nicht am Fahrradverleih.'); return end
    local vehicle = rentals[src]
    if not vehicle or not DoesEntityExist(vehicle) then
        rentals[src] = nil
        reply(src, false, 'Du hast kein aktives Mietfahrrad.'); return
    end
    if GetEntityRoutingBucket(vehicle) ~= GetPlayerRoutingBucket(src) or
        #(GetEntityCoords(vehicle) - location.coords) > 10.0 then
        reply(src, false, 'Bring dein Mietfahrrad zum Verleih zurück.'); return
    end
    local rider = GetPedInVehicleSeat(vehicle, -1)
    if rider ~= 0 and rider ~= GetPlayerPed(src) then
        reply(src, false, 'Es sitzt noch jemand auf deinem Fahrrad.'); return
    end
    DeleteEntity(vehicle)
    rentals[src] = nil
    reply(src, true, 'Fahrrad zurückgegeben. Vielen Dank!')
end)

AddEventHandler('playerDropped', function()
    local src = source
    if rentals[src] and DoesEntityExist(rentals[src]) then DeleteEntity(rentals[src]) end
    rentals[src], busy[src], cooldowns[src] = nil, nil, nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, vehicle in pairs(rentals) do
        if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
    end
end)
