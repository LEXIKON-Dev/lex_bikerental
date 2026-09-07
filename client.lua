local isOpen, selectedLocation, pending = false, nil, false
local requestSerial = 0
local ESX = exports['es_extended']:getSharedObject()

local function notify(message, notifyType)
    -- Use the server's ESX notification integration, without requiring
    -- a particular notification resource. Newer ESX versions can throw
    -- when their optional esx_notify resource is unavailable.
    if type(ESX.ShowNotification) == 'function' then
        local ok, result = pcall(ESX.ShowNotification, message, notifyType or 'info', 5000)
        if ok and result ~= false then return end
    end
    local color = notifyType == 'error' and '~r~' or notifyType == 'success' and '~g~' or '~b~'
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(color .. message .. '~s~')
    EndTextCommandThefeedPostTicker(false, false)
end

local function closeUI()
    isOpen, selectedLocation = false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openUI(index)
    if pending or IsPedInAnyVehicle(PlayerPedId(), false) then
        notify('Bitte steige zuerst ab und warte auf laufende Anfragen.', 'error')
        return
    end
    isOpen, selectedLocation = true, index
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', bikes = Config.Bikes })
end

RegisterNUICallback('ready', function(_, cb)
    SendNUIMessage({ action = isOpen and 'open' or 'close', bikes = Config.Bikes })
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({ ok = true })
end)

RegisterNUICallback('rent', function(data, cb)
    if not isOpen or not selectedLocation or pending or type(data.id) ~= 'string' then
        notify('Die Anfrage ist momentan nicht möglich.', 'error')
        cb({ ok = false, message = 'Die Anfrage ist momentan nicht möglich.' })
        return
    end
    pending = true
    requestSerial = requestSerial + 1
    local thisRequest = requestSerial
    TriggerServerEvent('lex_bikerental:rent', selectedLocation, data.id)
    cb({ ok = true })
    SetTimeout(15000, function()
        if pending and requestSerial == thisRequest then
            pending = false
            notify('Keine Serverantwort. Bitte erneut versuchen.', 'error')
            SendNUIMessage({ action = 'result', ok = false })
        end
    end)
end)

RegisterNetEvent('lex_bikerental:result', function(ok, message, netId)
    if source ~= 65535 then return end
    pending = false
    SendNUIMessage({ action = 'result', ok = ok })
    notify(message, ok and 'success' or 'error')
    if not ok then return end
    closeUI()
    if not netId then return end
    CreateThread(function()
        local deadline = GetGameTimer() + 8000
        while GetGameTimer() < deadline do
            if NetworkDoesEntityExistWithNetworkId(netId) then
                local vehicle = NetToVeh(netId)
                local ped = PlayerPedId()
                if vehicle ~= 0 and DoesEntityExist(vehicle) then
                    if not IsEntityDead(ped) and #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) < 15.0 then
                        SetVehicleOnGroundProperly(vehicle)
                        TaskWarpPedIntoVehicle(ped, vehicle, -1)
                    end
                    return
                end
            end
            Wait(100)
        end
        notify('Dein Fahrrad steht am Ausgabepunkt. Es konnte nicht automatisch bestiegen werden.')
    end)
end)

CreateThread(function()
    for _, location in ipairs(Config.Locations) do
        if location.blip then
            local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, 226)
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(location.label)
            EndTextCommandSetBlipName(blip)
        end
    end
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local helpLocation = nil
        for index, location in ipairs(Config.Locations) do
            local distance = #(coords - location.coords)
            if distance < Config.DrawDistance then
                sleep = 0
                DrawMarker(1, location.coords.x, location.coords.y, location.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.MarkerRadius * 2, Config.MarkerRadius * 2, 0.25,
                    50, 189, 0, 140, false, false, 2, false, nil, nil, false)
                local dx, dy = coords.x - location.coords.x, coords.y - location.coords.y
                local insideMarker = dx * dx + dy * dy <= Config.MarkerRadius * Config.MarkerRadius
                    and math.abs(coords.z - location.coords.z) <= Config.MarkerZTolerance
                if insideMarker and not isOpen and not IsEntityDead(ped) and not helpLocation then
                    helpLocation = index
                end
            end
        end
        if helpLocation then
            -- Nur diesen Frame anzeigen: außerhalb des Markers bleibt kein Hinweis stehen.
            AddTextEntry('lex_bikerental_HELP', '~INPUT_CONTEXT~ Fahrrad mieten | ~INPUT_DETONATE~ Fahrrad zurückgeben')
            DisplayHelpTextThisFrame('lex_bikerental_HELP', false)
            if IsControlJustReleased(0, 38) then openUI(helpLocation) end
            if IsControlJustReleased(0, 47) and not pending then
                TriggerServerEvent('lex_bikerental:return', helpLocation)
            end
        end
        if isOpen and (IsEntityDead(ped) or not selectedLocation or
            #(coords - Config.Locations[selectedLocation].coords) > Config.ServerDistance) then
            closeUI()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeUI() end
end)
