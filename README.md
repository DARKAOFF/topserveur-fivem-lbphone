# UpServeur LB Phone Vote App

Application FiveM pour permettre aux joueurs de voter depuis LB Phone, puis de réclamer automatiquement leur récompense via l'API UpServeur.

Plugin officiel UpServeur pour connecter un serveur de jeu au système de vote UpServeur.

## Installation

1. Copie le dossier de la ressource dans `resources/[upserveur]/upserveur_lbphone_vote` ou garde son nom actuel si tu préfères.
2. Vérifie que `lb-phone` et éventuellement `ox_lib` sont démarrés avant cette ressource.
3. Ajoute `ensure upserveur_lbphone_vote` dans ton `server.cfg`.
4. Renseigne `config.lua` avec :
   - `ServerId`
   - `ApiBaseUrl`
   - `ApiToken`
   - `VoteUrl`
5. Redémarre la ressource.

## Dépendances

- FiveM
- LB Phone
- UpServeur avec API vote active
- Optionnel : `ox_lib` pour les notifications
- Optionnel : `qb-core` ou `es_extended`

## Configuration

```lua
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
```

Compatibilité temporaire :

- la ressource accepte encore `Config.TopServeur` pour les anciennes installations
- le nom recommandé côté config est désormais `Config.UpServeur`

## Permissions et sécurité

- Le token API doit rester côté `server.lua`.
- N'expose jamais `ApiToken` à une interface web publique.
- La vérification passe par `Authorization: Bearer TOKEN`.
- Le claim marque le vote comme réclamé côté API pour éviter les doubles récompenses.

## Exemples ESX

Si `Reward.Command` n'est pas utilisé, le script tente :

```lua
player.addAccountMoney("bank", reward.Amount)
```

Tu peux aussi forcer une commande :

```lua
Command = "esx_addbankmoney {source} 5000"
```

## Exemples QBCore

Si `Reward.Command` n'est pas utilisé, le script tente :

```lua
        player.Functions.AddMoney("bank", reward.Amount, "upserveur-vote")
```

Ou une commande custom :

```lua
Command = "giveaccountmoney {source} bank 5000"
```

## Flow recommandé

1. Le joueur ouvre LB Phone.
2. Il lance l'app UpServeur.
3. Il ouvre la page de vote.
4. Il revient en jeu.
5. Le script appelle `verify-vote`.
6. Si un vote est trouvé, le script appelle `claim-reward`.
7. La récompense est exécutée une seule fois.

## Callbacks / exports

- `exports("VerifyPlayerVote", function(source, callback) ... end)`
- `exports("ClaimPlayerVote", function(source, voteId, callback) ... end)`

Événements réseau exposés :

- `upserveur_lbphone:verifyVote`
- `upserveur_lbphone:claimReward`

## Problèmes fréquents

### Aucun vote trouvé

- Vérifie `ServerId`
- Vérifie `ApiToken`
- Vérifie que le joueur a bien voté récemment
- Vérifie que l'identifiant utilisé correspond à celui enregistré côté vote

### Récompense non donnée

- Vérifie `Reward.Command`
- Vérifie que ton framework ESX/QBCore est bien lancé
- Vérifie la console serveur pour le mode de reward appliqué

### App LB Phone absente

- Certaines versions de LB Phone exposent des APIs différentes
- Adapte `client.lua` si ton export est `AddApp`, `CreateApp` ou un autre helper spécifique
- Le script garde un fallback commande `/upserveurvote`
