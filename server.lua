local resourceName = GetCurrentResourceName()
local recentClaims = {}
local lastVerifyAt = {}

local function getSettings()
    return Config.UpServeur or Config.TopServeur or {}
end

local function log(message, payload)
    if not Config.Debug then
        return
    end

    if payload then
        print(("[UpServeur LBPhone] %s %s"):format(message, json.encode(payload)))
    else
        print(("[UpServeur LBPhone] %s"):format(message))
    end
end

local function getFrameworkContext()
    local qbState = GetResourceState("qb-core")
    if qbState == "started" then
        return "qbcore", exports["qb-core"]:GetCoreObject()
    end

    local esxState = GetResourceState("es_extended")
    if esxState == "started" then
        return "esx", exports["es_extended"]:getSharedObject()
    end

    return nil, nil
end

local function getPrimaryIdentifier(source, prefix)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return nil
end

local function getPlayerContext(source)
    local framework, object = getFrameworkContext()
    local context = {
        source = source,
        playerIdentifier = nil,
        discordId = getPrimaryIdentifier(source, "discord:"),
        license = getPrimaryIdentifier(source, "license:"),
        citizenid = nil
    }

    if framework == "qbcore" and object then
        local player = object.Functions.GetPlayer(source)
        if player and player.PlayerData then
            context.citizenid = player.PlayerData.citizenid
            context.playerIdentifier = player.PlayerData.citizenid or context.license or tostring(source)
        end
    elseif framework == "esx" and object then
        local player = object.GetPlayerFromId(source)
        if player then
            context.playerIdentifier = player.identifier or context.license or tostring(source)
        end
    end

    context.playerIdentifier = context.playerIdentifier or context.license or context.discordId or tostring(source)
    return context
end

local function applyReward(source)
    local reward = (getSettings().Reward) or {}
    local command = reward.Command
    if command and command ~= "" then
        ExecuteCommand(command:gsub("{source}", tostring(source)))
        return true, "command"
    end

    local framework, object = getFrameworkContext()
    if reward.Type == "money" and reward.Amount then
        if framework == "qbcore" and object then
            local player = object.Functions.GetPlayer(source)
            if player then
                player.Functions.AddMoney("bank", reward.Amount, "upserveur-vote")
                return true, "qbcore"
            end
        elseif framework == "esx" and object then
            local player = object.GetPlayerFromId(source)
            if player then
                player.addAccountMoney("bank", reward.Amount)
                return true, "esx"
            end
        end
    end

    return false, "no_handler"
end

local function performApiRequest(path, body, callback)
    local settings = getSettings()
    PerformHttpRequest(
        ("%s%s"):format(settings.ApiBaseUrl or "https://upserveur.fr", path),
        function(statusCode, responseBody)
            local payload = nil
            if responseBody and responseBody ~= "" then
                payload = json.decode(responseBody)
            end

            callback(statusCode, payload)
        end,
        "POST",
        json.encode(body),
        {
            ["Content-Type"] = "application/json",
            ["Authorization"] = ("Bearer %s"):format(settings.ApiToken or "")
        }
    )
end

local function tooSoon(source)
    local now = GetGameTimer()
    local last = lastVerifyAt[source]
    if last and now - last < (Config.VerifyCooldownMs or 5000) then
        return true
    end

    lastVerifyAt[source] = now
    return false
end

local function verifyVoteInternal(source, callback)
    if tooSoon(source) then
        callback(false, { message = "Veuillez patienter avant une nouvelle vérification." })
        return
    end

    local context = getPlayerContext(source)
    local settings = getSettings()
    performApiRequest("/api/integrations/fivem/lb-phone/verify-vote", {
        serverId = settings.ServerId,
        playerIdentifier = context.playerIdentifier,
        discordId = context.discordId or "",
        license = context.license or ""
    }, function(statusCode, payload)
        log("verify response", { statusCode = statusCode, payload = payload, source = source })

        if statusCode ~= 200 or not payload or not payload.success then
            callback(false, payload or { message = "Impossible de vérifier le vote." })
            return
        end

        callback(true, payload)
    end)
end

local function claimRewardInternal(source, voteId, callback)
    local context = getPlayerContext(source)
    local settings = getSettings()
    local claimKey = ("%s:%s"):format(context.playerIdentifier, voteId)
    if recentClaims[claimKey] then
        callback(false, { message = "Récompense déjà en cours de traitement." })
        return
    end

    recentClaims[claimKey] = true

    performApiRequest("/api/integrations/fivem/lb-phone/claim-reward", {
        serverId = settings.ServerId,
        playerIdentifier = context.playerIdentifier,
        voteId = voteId
    }, function(statusCode, payload)
        log("claim response", { statusCode = statusCode, payload = payload, source = source })

        if statusCode ~= 200 or not payload or not payload.success then
            recentClaims[claimKey] = nil
            callback(false, payload or { message = "Impossible de réclamer la récompense." })
            return
        end

        local applied, mode = applyReward(source)
        if not applied then
            recentClaims[claimKey] = nil
            callback(false, { message = ("Récompense claimée mais non distribuée (%s)."):format(mode) })
            return
        end

        callback(true, payload)
    end)
end

exports("VerifyPlayerVote", function(source, callback)
    verifyVoteInternal(source, callback)
end)

exports("ClaimPlayerVote", function(source, voteId, callback)
    claimRewardInternal(source, voteId, callback)
end)

RegisterNetEvent("upserveur_lbphone:verifyVote", function()
    local source = source
    verifyVoteInternal(source, function(success, payload)
        TriggerClientEvent("upserveur_lbphone:verifyVoteResult", source, success, payload)
    end)
end)

RegisterNetEvent("upserveur_lbphone:claimReward", function(voteId)
    local source = source
    claimRewardInternal(source, voteId, function(success, payload)
        TriggerClientEvent("upserveur_lbphone:claimRewardResult", source, success, payload)
    end)
end)

AddEventHandler("playerDropped", function()
    local source = source
    lastVerifyAt[source] = nil
end)

CreateThread(function()
    local settings = getSettings()
    log("resource started", {
        resource = resourceName,
        apiBaseUrl = settings.ApiBaseUrl,
        serverId = settings.ServerId
    })
end)
