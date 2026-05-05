Config = {}

Config.UpServeur = {
    ServerId = "YOUR_SERVER_ID",
    ApiBaseUrl = "https://upserveur.fr",
    ApiToken = "YOUR_API_TOKEN",
    VoteUrl = "https://upserveur.fr/server/YOUR_SERVER_SLUG/vote",
    Reward = {
        Type = "money",
        Amount = 5000,
        Command = "giveaccountmoney {source} bank 5000"
    }
}

Config.LBPhone = {
    AppIdentifier = "upserveur_vote",
    AppName = "UpServeur",
    AppIcon = "https://upserveur.fr/logo.png"
}

Config.Debug = true
Config.VerifyCooldownMs = 5000

-- Temporary compatibility bridge for older installs using Config.TopServeur.
Config.TopServeur = Config.TopServeur or Config.UpServeur
