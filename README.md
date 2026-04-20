# DarkRP.xyz s&box Server Egg

---

## 🇺🇸 English Version

Professional Pelican and Pterodactyl eggs specifically designed for hosting **DarkRP.xyz** (mydriss.darkrp) on s&box. This egg is dedicated to the DarkRP.xyz framework and is optimized for both Cloud and Local file management.

### 🚀 Features
- **Dedicated for mydriss.darkrp**: Hardcoded for the best possible integration.
- **Built-in Wine & .NET**: Run your server without installing host dependencies.
- **Cloud Sync Ready**: Native support for `darkrp.xyz` synchronization.
- **Performance Tuning**: Custom `TICKRATE` and `MAX_PLAYERS` support.
- **Auto-Update**: Integrated SteamCMD logic keeps your server updated on every boot.
- **Smart Loading Logic**: Automatically detects local files in `/home/container/projects/`.

### 🛠️ Configuration Fields
The Egg is organized in a clear 2-column layout. Here is what you should put in each field:
- **Server Identity**: 
  - `Server Key`: Get your key at [darkrp.xyz/dashboard](https://darkrp.xyz/dashboard). It links your server to the cloud.
  - `Server ID`: Your unique server numeric ID (from the dashboard).
  - `Owner SteamID`: Your Steam64 ID. This grants you **automatic SuperAdmin** rights in-game.
- **Gameplay**: 
  - `Max Players`: Total slots (e.g., 32, 64, 128).
  - `Map`: The map identifier (e.g., `facepunch.flatgrass`). Leave blank for default.
  - `Tickrate`: Simulation speed. **60** is recommended for stability, **100** for high-performance physics.
- **Steam**: 
  - `Steam Game Token`: GSLT token from [Steam Dev Management](https://steamcommunity.com/dev/managegameservers) (AppID **590830**) to list your server publicly.

### 📂 Using Local Files (Direct Upload)
Modify the server behavior by uploading project files **directly** into the projects folder:
1.  Upload your folders (`Code`, `Assets`, etc.) and your `.sbproj` file directly into `/home/container/projects/`.
2.  The server will automatically detect your files and use `/home/container/projects/` as the local root.

### 🕒 Scheduled Restart (Schedules)
Unlike GMod, s&box is very stable. We recommend only **one restart every 24 hours**:
- **Why?** To apply s&box engine updates and refresh memory.
- **When?** Around **04:00 or 05:00 AM** when player count is lowest.
- **Setup**: In your panel, go to **Schedules** -> Create New -> Set Hour to `5` -> Add Task "Power Action" with payload `Restart`.

---

## 🇫🇷 Version Française

Egg professionnel pour **Pelican** et **Pterodactyl** spécifiquement conçu pour héberger **DarkRP.xyz** (mydriss.darkrp) sur s&box.

### 🚀 Fonctionnalités
- **Dédié à mydriss.darkrp** : Configuration verrouillée pour une stabilité maximale.
- **Wine & .NET Intégrés** : Aucune dépendance requise sur la machine hôte.
- **Synchronisation Cloud native** : Support intégré pour `darkrp.xyz`.
- **Réglages Performance** : Support du `TICKRATE` et `MAX_PLAYERS` configurable.
- **Mise à jour automatique** : Votre serveur reste à jour via SteamCMD à chaque boot.

### 🛠️ Champs de Configuration
L'Egg est organisé en deux colonnes. Voici comment remplir les champs :
- **Identité Serveur** : 
  - `Server Key` : Votre clé sur [darkrp.xyz/dashboard](https://darkrp.xyz/dashboard). Relie le serveur au site.
  - `Server ID` : L'ID numérique de votre serveur (depuis le dashboard).
  - `Owner SteamID` : Votre ID Steam64. Vous donne **automatiquement les droits SuperAdmin**.
- **Gameplay** : 
  - `Max Players` : Nombre total de slots (ex: 32, 64, 128).
  - `Map` : L'identifiant de la map (ex : `facepunch.flatgrass`). Laissez vide pour la map par défaut.
  - `Tickrate` : Fréquence de simulation. **60** est recommandé, **100** pour une physique ultra-réactive.
- **Steam** : 
  - `Steam Game Token` : Votre GSLT depuis [Steam Dev](https://steamcommunity.com/dev/managegameservers) (AppID **590830**) pour apparaître dans la liste des serveurs.

### 📂 Utilisation des Fichiers Locaux
Modifiez le comportement du serveur en déposant vos fichiers **directement** dans le dossier projects :
1.  Déposez vos dossiers (`Code`, `Assets`, etc.) et votre fichier `.sbproj` dans `/home/container/projects/`.
2.  Le serveur détectera automatiquement vos fichiers et utilisera cet emplacement comme racine.

### 🕒 Redémarrage Programmé (Schedules)
s&box est très stable. Nous recommandons **un seul redémarrage toutes les 24 heures** :
- **Pourquoi ?** Pour appliquer les mises à jour s&box et vider la mémoire.
- **Quand ?** Vers **04:00 ou 05:00 du matin** quand il y a peu de joueurs.
- **Configuration** : Dans votre panel, allez dans **Schedules** -> Nouveau -> Heure: `5` -> Tâche "Power Action" -> `Restart`.

---

## 🐳 Docker Image
Image stockée sur : `ghcr.io/mydrissjlv/sbox-darkrp.xyz-server-egg:latest`

## 📄 License

This project is proprietary. © 2026 Mydriss. All rights reserved.
Redistribution, modification, or re-uploading of this project is strictly prohibited without explicit permission.

---
*Created by Mydriss - © 2026*