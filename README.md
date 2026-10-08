## 🇫🇷 Présentation

Poursuivi ? Glisse-toi sous une voiture et disparais.
Approche un véhicule garé, cache-toi dessous, observe au ras du sol… puis ressors en toute discrétion.

### ✨ Fonctionnalités

- Interaction **ox_target** sur les véhicules : « Se cacher dessous »
- Animation d'entrée et de sortie, allongé sur le dos
- Caméra basse sous le châssis, orientable à la souris
- Vérifie la garde au sol : impossible sous les voitures trop basses
- Moteur coupé et véhicule à l'arrêt obligatoires
- Si la voiture démarre et roule : tu es éjecté
- Un seul joueur caché par véhicule (synchronisé serveur)
- Sortie du côté le plus libre, touche **E**
- Motos, vélos, bateaux, hélicos, avions et trains exclus
- Langues **FR / EN**
- Tout est réglable dans `config.lua`

### 📦 Dépendances

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)

### 📥 Installation

1. Télécharge le script (bouton **Code → Download ZIP**)
2. Place le dossier `kx_souscaisse` dans `resources/`
3. Dans ton `server.cfg`, après ox_lib et ox_target :
   ```
   ensure ox_lib
   ensure ox_target
   ensure kx_souscaisse
   ```
4. Redémarre ton serveur

### ⚙️ Configuration

Dans `config.lua` :

| Option | Rôle |
|---|---|
| `Config.Locale` | `'fr'` ou `'en'` |
| `Config.MinClearance` | Garde au sol minimale (m) |
| `Config.RequireEngineOff` | Moteur coupé obligatoire |
| `Config.BlacklistedClasses` | Classes de véhicules interdites |
| `Config.Camera` | Hauteur, FOV, sensibilité de la caméra |
| `Config.ExitKey` | Touche de sortie (38 = E) |
| `Config.EjectDamage` | Dégâts si éjecté |

### 🔌 Export (serveur)

```lua
local hidden, netId = exports.kx_souscaisse:IsHidden(source)
```

---

## 🇬🇧 Overview

Being chased? Slide under a car and vanish.
Walk up to a parked vehicle, hide underneath, watch from ground level… then sneak back out.

### ✨ Features

- **ox_target** interaction on vehicles: "Hide underneath"
- Enter and exit animations, lying on your back
- Low under-chassis camera with mouse look
- Ground clearance check: cars that are too low are blocked
- Engine off and vehicle stopped required
- If the car starts driving: you get ejected
- One hidden player per vehicle (server-synced)
- Exits on the freest side, **E** key
- Bikes, motorcycles, boats, helis, planes and trains excluded
- **FR / EN** languages
- Everything configurable in `config.lua`

### 📦 Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)

### 📥 Installation

1. Download the script (**Code → Download ZIP**)
2. Put the `kx_souscaisse` folder in `resources/`
3. In your `server.cfg`, after ox_lib and ox_target:
   ```
   ensure ox_lib
   ensure ox_target
   ensure kx_souscaisse
   ```
4. Restart your server

### ⚙️ Configuration

See `config.lua` (language, clearance, engine rule, blacklisted classes, camera, exit key, eject damage).

### 🔌 Export (server)

```lua
local hidden, netId = exports.kx_souscaisse:IsHidden(source)
```

---

<p align="center">Made by <b>KAIRROXX</b> • Bug or idea? Open an issue 💬</p>
