local appRegistered = false

local function getSettings()
    return Config.UpServeur or Config.TopServeur or {}
end

local function notify(message, type)
    if lib and lib.notify then
        lib.notify({
            title = "UpServeur",
            description = message,
            type = type or "inform"
        })
        return
    end

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function openVoteUrl()
    local url = getSettings().VoteUrl
    if not url or url == "" then
        notify("VoteUrl non configurée.", "error")
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openUrl",
        url = url
    })
    notify("Page de vote ouverte.", "success")
end

local function registerLbPhoneApp()
    if appRegistered or GetResourceState("lb-phone") ~= "started" then
        return
    end

    local appPayload = {
        identifier = Config.LBPhone.AppIdentifier,
        name = Config.LBPhone.AppName,
        icon = Config.LBPhone.AppIcon
    }

    local success = pcall(function()
        if exports["lb-phone"].AddCustomApp then
            exports["lb-phone"]:AddCustomApp(appPayload)
            return
        end

        if exports["lb-phone"].AddApp then
            exports["lb-phone"]:AddApp(appPayload)
            return
        end

        if exports["lb-phone"].CreateApp then
            exports["lb-phone"]:CreateApp(appPayload)
            return
        end
    end)

    appRegistered = success
end

RegisterCommand("upserveurvote", function()
    openVoteUrl()
end, false)

RegisterNUICallback("upserveur_vote_open", function(_, cb)
    openVoteUrl()
    cb({ ok = true })
end)

RegisterNUICallback("upserveur_vote_verify", function(_, cb)
    TriggerServerEvent("upserveur_lbphone:verifyVote")
    cb({ ok = true })
end)

RegisterNUICallback("upserveur_vote_claim", function(data, cb)
    if not data or not data.voteId then
        cb({ ok = false })
        return
    end

    TriggerServerEvent("upserveur_lbphone:claimReward", data.voteId)
    cb({ ok = true })
end)

RegisterNetEvent("upserveur_lbphone:verifyVoteResult", function(success, payload)
    if not success then
        notify(payload and payload.message or "Échec de vérification du vote.", "error")
        return
    end

    if payload.hasVoted and payload.canClaim then
        notify("Vote détecté, récompense disponible.", "success")
    elseif payload.hasVoted then
        notify("Vote déjà consommé ou déjà réclamé.", "inform")
    else
        notify("Aucun vote récent trouvé.", "inform")
    end
end)

RegisterNetEvent("upserveur_lbphone:claimRewardResult", function(success, payload)
    if not success then
        notify(payload and payload.message or "Impossible de réclamer la récompense.", "error")
        return
    end

    notify(payload and payload.message or "Récompense réclamée.", "success")
end)

CreateThread(function()
    Wait(1500)
    registerLbPhoneApp()
end)
