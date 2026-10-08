Config = {}

Config.Locale = 'fr' -- 'fr' | 'en'

-- Cible ox_target
Config.TargetLabel    = nil -- depuis locales (Locales[Config.Locale])
Config.TargetIcon     = 'fa-solid fa-car-side'
Config.TargetDistance = 2.0

-- Conditions
Config.MaxSpeed      = 0.3   -- m/s : au-dessus, la voiture "roule", impossible de se glisser
Config.EjectSpeed    = 0.8   -- m/s : si la voiture bouge plus vite que ça, on est éjecté
Config.MinClearance  = 0.20  -- m : garde au sol minimale (châssis -> sol) pour passer
Config.RequireEngineOff = true

-- Classes interdites (GetVehicleClass)
Config.BlacklistedClasses = {
    [8]  = true, -- motos
    [13] = true, -- vélos
    [14] = true, -- bateaux
    [15] = true, -- hélicos
    [16] = true, -- avions
    [21] = true, -- trains
}

-- Placement du personnage (repère local de la voiture, à ajuster selon le rendu)
Config.StandOffset     = 0.55  -- m depuis le flanc : où le joueur se tient/s'allonge avant de glisser
Config.HideDepth       = 0.60  -- m : position finale de l'origine du ped (bassin) depuis le centre, côté d'entrée ; plus petit = plus caché
Config.HideOffsetY     = 0.0   -- m : décalage avant/arrière sous le châssis
Config.PedGroundOffset = 1.0   -- m : hauteur de l'origine du ped au-dessus du sol (anim allongée)
Config.SlideInTime     = 1800  -- ms
Config.SlideOutTime    = 1400  -- ms
Config.ExitDistance    = 1.2   -- m de place libre demandée sur le flanc pour ressortir
Config.WatchInterval   = 150   -- ms

-- Animations (mécano allongé sur le dos)
Config.Anims = {
    -- entrée : assis puis allongé sur le dos, la tête part sous le châssis.
    dictEnter = 'amb@world_human_sunbathe@male@back@enter',
    enter     = 'enter',
    -- 0.0 si le perso se retourne une fois dessous
    BaseRotOffset = 180.0,
    dictBase  = 'amb@world_human_vehicle_mechanic@male@idle_a',
    base      = 'idle_a',
    dictExit  = 'amb@world_human_vehicle_mechanic@male@exit',
    exit      = 'exit',
}

-- Caméra basse
Config.Camera = {
    Height       = 0.20,  -- m au-dessus du sol
    SideFactor   = 0.10,  -- position latérale : 0 = pile au milieu sous la caisse, 1 = au ras de la portière
    Fov          = 65.0,
    Sensitivity  = 6.0,
    MaxYaw       = 160.0,
    MinPitch     = -8.0,
    MaxPitch     = 18.0,
    HideOwnPed   = true,  -- masque ton perso pour TOI seulement (les autres le voient)
}

Config.ExitKey = 38 -- E

-- Éjection
Config.EjectForce  = 5.0
Config.EjectRagdoll = 2500
Config.EjectDamage = 5

-- Notifications
Config.NotifyTitle    = nil -- depuis locales
Config.NotifyIcon     = 'car-side'
Config.NotifyPosition = 'top'
Config.TextUI         = nil -- depuis locales

Config.Messages = nil -- depuis locales (Locales[Config.Locale].Messages)

-- applique la locale (locales/fr.lua, locales/en.lua chargés avant ce fichier)
do
    local L = (Locales and (Locales[Config.Locale] or Locales['fr'])) or {}
    Config.TargetLabel  = L.TargetLabel  or 'Se cacher dessous'
    Config.NotifyTitle  = L.NotifyTitle  or 'Sous la caisse'
    Config.TextUI       = L.TextUI       or '[E] Sortir de sous la voiture'
    Config.Messages     = L.Messages     or {}
end