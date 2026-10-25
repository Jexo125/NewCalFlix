# DOCUMENTATION TECHNIQUE ET ARCHITECTURALE - NEWCALFLIX

> **Projet** : NewCalFlix (ex-Fladder)  
> **Type d'application** : Client Jellyfin multi-plateforme haute performance (Android, Android TV, Desktop, Web)  
> **Version actuelle** : 0.11.1+1  
> **Framework** : Flutter 3.47.0 / Dart 3.13.0  
> **Cible principale** : Android (Mobile, Tablette, Android TV / Leanback)  

---

## TABLE DES MATIÈRES
1. [Vue d'Ensemble & Architecture Générale](#1-vue-densemble--architecture-générale)
2. [Organisation de la Structure des Fichiers](#2-organisation-de-la-structure-des-fichiers)
3. [Composants et Systèmes Clés](#3-composants-et-systèmes-clés)
4. [Analyse des Fonctionnalités Existantes](#4-analyse-des-fonctionnalités-existantes)
5. [Analyse des 10 Flux Techniques Majeurs](#5-analyse-des-10-flux-techniques-majeurs)
6. [Inventaire des Dépendances et Frameworks](#6-inventaire-des-dépendances-et-frameworks)
7. [Inventaire Exhaustif des Références Fladder](#7-inventaire-exhaustif-des-références-fladder)
8. [Matrice de Migration vers l'Identité NewCalFlix](#8-matrice-de-migration-vers-lidentité-newcalflix)
9. [Recommandations et Règles de Développement](#9-recommandations-et-règles-de-développement)

---

## 1. VUE D'ENSEMBLE & ARCHITECTURE GÉNÉRALE

NewCalFlix est un client alternatif pour les serveurs multimédias **Jellyfin**. Il offre une interface moderne, adaptative (mobile, tablette, ordinateur, TV) et prend en charge la lecture directe, le transcodage à la volée, le mode hors-ligne synchronisé, ainsi qu'une intégration avec **Overseerr/Jellyseerr**.

### Pattern Architectural
L'application adopte une architecture réactive en couches basée sur **Flutter Riverpod (2.6+)** et le pattern **Clean Architecture / MVI (Model-View-Intent)** :

```
[ Écran / Composants UI (Widget / ConsumerWidget) ]
                       │ (ref.watch / ref.read)
                       ▼
          [ Providers Riverpod (Notifier / StateNotifier) ]
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
[ Services & API Client ]   [ Stockage Local ]
  - Chopper / Swagger API     - SharedPreferences
  - MediaKit / Player         - Drift SQLite DB (Sync)
```

1. **Couche Présentation (`lib/screens/`, `lib/widgets/`)** : Déclarative, composée de `ConsumerWidget` ou `ConsumerStatefulWidget`. Utilise `AutoRoute` pour la navigation.
2. **Couche État & Logique Métier (`lib/providers/`)** : Gérée par des Notifiers Riverpod annotés (`@riverpod`).
3. **Couche Réseau & Accès Données (`lib/jellyfin/`, `lib/seerr/`, `lib/models/`)** : Client HTTP Chopper généré à partir des spécifications OpenAPI Jellyfin (Swagger) et convertisseurs de DTOs vers les modèles immutables du domaine (`Freezed` / `dart_mappable`).
4. **Couche Persistance (`lib/models/syncing/database_item.dart`)** : Base de données relationnelle locale **Drift (SQLite)** pour le mode hors-ligne et les téléchargements.
5. **Couche NDK / Interop Natif Android (`android/`, `lib/src/`)** : Pont de communication via **Pigeon** reliant Flutter au code Kotlin natif pour le lecteur vidéo ExoPlayer/Media3, la gestion de la batterie, le mode Picture-in-Picture (PiP) et les notifications.

---

## 2. ORGANISATION DE LA STRUCTURE DES FICHIERS

```
NewCalFlix/
├── android/                        # Projet Android natif Kotlin (Gradle, Manifestes, Compose UI, ExoPlayer)
│   └── app/src/main/kotlin/nl/jknaapen/fladder/   # Code source Kotlin natif (Pigeon, Activity, Composables)
├── assets/                         # Fontes (Rubik, OpenSans, MP-Font), icônes et configurations JSON
├── docs/                           # Documentation technique du projet (ce document)
├── config/                         # Configuration de déploiement (config.json)
├── icons/                          # Icônes d'application (développement / production)
├── l10n.yaml                       # Configuration du générateur Flutter L10n
├── pubspec.yaml                    # Spécification des dépendances et métadonnées du projet
├── lib/
│   ├── main.dart                   # Point d'entrée de l'application
│   ├── bootstrap/                  # Initialisation asynchrone multi-plateforme (app_bootstrap.dart)
│   ├── jellyfin/                   # Client OpenAPI Jellyfin généré (Swagger, DTOs, Enums)
│   ├── l10n/                       # Fichiers de traduction ARB et code généré AppLocalizations
│   ├── logic/                      # Logique métier spécifique (menu d'application, raccourcis)
│   ├── models/                     # Modèles du domaine (Immutables Freezed, DTOs Mappers)
│   │   ├── items/                  # Films, Séries, Saison, Épisodes, Musique, Chaînes, Programmes
│   │   ├── playback/               # Modèles de lecture (Direct, Transcode, Offline, QueueState)
│   │   ├── settings/               # Modèles de configuration (Client, Lecteur, Raccourcis)
│   │   └── syncing/                # Entités de la base de données Drift (Téléchargements hors-ligne)
│   ├── providers/                  # Providers Riverpod (API, Utilisateur, Bibliothèque, Sync, Settings)
│   ├── routes/                     # Configuration AutoRoute (auto_router.dart, gardes d'accès)
│   ├── screens/                    # Pages de l'application classées par domaine
│   │   ├── collections/            # Collections et listes personnalisées
│   │   ├── control_panel/          # Panneau d'administration du serveur Jellyfin
│   │   ├── details/                # Fiches détaillées des médias
│   │   ├── downloads/              # Écran de gestion des téléchargements
│   │   ├── home/                   # Écran principal / Tableau de bord
│   │   ├── library/                # Exploration des bibliothèques de médias
│   │   ├── live_tv/                # Télévision en direct et Guide EPG
│   │   ├── login/                  # Connexion serveur, sélection de compte, écran de verrouillage
│   │   ├── music/                  # Section musique et lecteur audio
│   │   ├── seerr/                  # Intégration Overseerr/Jellyseerr (Recherche & Demandes)
│   │   ├── settings/               # Paramètres (Apparence, Lecteur, Réseau, Téléchargements)
│   │   └── video_player/           # Interface du lecteur vidéo et de ses contrôles
│   ├── seerr/                      # Client Chopper et modèles pour Overseerr/Jellyseerr
│   ├── src/                        # Interfaces d'interopérabilité Pigeon générées (Dart -> Kotlin)
│   ├── util/                       # Extensions, utilitaires, calculatrices de débit, thèmes, helpers
│   └── widgets/                    # Composants UI réutilisables (Boutons, Cartes, Dialogues, Sliders)
```

---

## 3. COMPOSANTS ET SYSTÈMES CLÉS

### Point d'Entrée & Initialisation (`lib/main.dart` & `lib/bootstrap/app_bootstrap.dart`)
1. `main(List<String> args)` initialise les bindings Flutter (`WidgetsFlutterBinding.ensureInitialized()`).
2. Exécute `bootstrapApplication(args)` qui charge les préférences partagées (`SharedPreferences`), pré-cache les icônes SVG (`SvgUtils.preCacheSVGs()`), vérifie le mode TV (Leanback) et configure la journalisation des erreurs (`CrashLogNotifier`).
3. Enveloppe l'application dans un `ProviderScope` Riverpod avec surcharges d'instances (`sharedPreferencesProvider`, `applicationInfoProvider`, `syncProvider`).
4. Lance `MaterialApp.router` configuré avec le routeur `AutoRouter` et les délégués de localisation `FladderLocalizations`.

### Système de Gestion d'État (Riverpod 2.6+)
* Préfère les Notifiers annotés (`@riverpod`).
* Utilise le `select` pour limiter les re-builds de widgets inutiles : `ref.watch(clientSettingsProvider.select((v) => v.themeMode))`.
* Utilise `ref.listen` pour réagir aux événements secondaires (snackbars, redirections).

### Navigation (`AutoRoute 10.x`)
* Déclarée dans [`lib/routes/auto_router.dart`](file:///C:/Users/jeremie/Documents/GitHub/NewCalFlix/lib/routes/auto_router.dart).
* Protégée par `AuthGuard` : si aucun utilisateur n'est authentifié, l'application redirige automatiquement vers `LoginRoute`.
* Prend en charge les sous-routes imbriquées (Dynamic Tabs, Settings Section, Navigation Drawer/Rail).

### Communication Serveur Jellyfin (`Chopper` & `Jellyfin OpenAPI`)
* Le client Swagger généré (`lib/jellyfin/jellyfin_open_api.swagger.dart`) fournit toutes les méthodes de l'API REST Jellyfin.
* Authentification gérée par les en-têtes HTTP `X-Emby-Authorization` contenant l'ID client, la version de l'application, l'ID de l'appareil et le jeton d'accès (`X-Emby-Token`).
* Expose un provider centralisé `jellyApiProvider` dans `lib/providers/api_provider.dart`.

### Moteur de Lecture Vidéo & Audio (`media_kit` & Native Kotlin Activity)
* Sur Desktop et Web : Utilise le moteur `media_kit` (basé sur `libmpv`).
* Sur Android : Utilise une combinaison de `media_kit` et d'une activité native dédiée Kotlin (`VideoPlayerActivity.kt`) intégrant **ExoPlayer / Media3** pour une accélération matérielle optimale, la gestion du HDR, le passthrough audio et le Picture-in-Picture natif.
* La communication entre Flutter et `VideoPlayerActivity.kt` est assurée par des canaux IPC **Pigeon** ([`lib/src/video_player_helper.g.dart`](file:///C:/Users/jeremie/Documents/GitHub/NewCalFlix/lib/src/video_player_helper.g.dart)).

---

## 4. ANALYSE DES FONCTIONNALITÉS EXISTANTES

| Domaine Fonctionnel | État dans le Code | Fichiers & Composants Clés |
| :--- | :---: | :--- |
| **Authentification & Multi-comptes** | **Présent** | `lib/providers/user_provider.dart`, `models/credentials_model.dart`, `screens/login/` |
| **Gestion Multi-Serveurs** | **Présent** | `lib/providers/discovery_provider.dart`, `screens/login/login_screen.dart` |
| **Bibliothèques Films & Séries** | **Présent** | `lib/screens/library/`, `models/items/movie_model.dart`, `series_model.dart` |
| **Épisodes & Next Up** | **Présent** | `lib/models/items/episode_model.dart`, `widgets/next_up_overlay.dart` |
| **Musique & Audio** | **Présent** | `lib/screens/music/`, `models/items/album_model.dart`, `audio_player_queue_dialog.dart` |
| **Live TV & EPG Guide** | **Présent** | `lib/screens/live_tv/`, `providers/live_tv_provider.dart`, `channel_program.dart` |
| **Recherche Globale** | **Présent** | `lib/models/search_model.dart`, `providers/seerr_search_provider.dart` |
| **Favoris & Watchlists** | **Présent** | `lib/models/favourites_model.dart`, `providers/user_provider.dart` |
| **Historique & Reprise** | **Présent** | `lib/models/playback/playback_model.dart` (`positionTicks`) |
| **Téléchargements Hors-ligne** | **Présent** | `lib/models/syncing/database_item.dart`, `providers/sync/background_download_provider.dart` |
| **Sous-titres & Pistes Audio** | **Présent** | `lib/util/streams_selection.dart`, `composables/dialogs/SubtitlePicker.kt` |
| **Intégration Overseerr/Jellyseerr**| **Présent** | `lib/seerr/`, `providers/seerr_api_provider.dart`, `screens/seerr/` |
| **Panneau d'Administration** | **Présent** | `lib/screens/control_panel/`, `providers/control_panel/` |
| **Mode TV / Télécommande** | **Présent** | `lib/util/focus_provider.dart`, `util/input_handler.dart`, Leanback Checkers |

---

## 5. ANALYSE DES 10 FLUX TECHNIQUES MAJEURS

### Flux 1 : Démarrage de l'Application
```
main() ──► bootstrapApplication() ──► SharedPreferences / SVGs / Options TV
  │
  └──► runApp(ProviderScope) ──► MaterialApp.router (AutoRouter + L10n)
```

### Flux 2 : Authentification et Connexion au Serveur
1. L'utilisateur saisit l'URL du serveur Jellyfin.
2. `DiscoveryNotifier` teste l'URL via `/System/Info/Public`.
3. L'utilisateur entre ses identifiants -> appel de `usersAuthenticateByNamePost`.
4. Les jetons d'accès et l'ID du serveur sont sauvegardés dans `SharedPreferences` de manière sécurisée.
5. L'instance `UserNotifier` est mise à jour, déclenchant l'activation de `AuthGuard`.

### Flux 3 : Récupération des Bibliothèques
1. `UserNotifier` charge le profil utilisateur courant (`Users/Me`).
2. `jellyApiProvider` interroge `/Users/{userId}/Views` pour lister les bibliothèques (Films, Séries, Musique, TV).
3. `controlLibrariesProvider` alimente les grilles et menus de navigation.

### Flux 4 : Affichage des Fiches Médias
1. Sélection d'un média -> `AutoRouter.push(DetailsRoute(id: item.id))`.
2. `detailsProvider(id)` appelle `Users/{userId}/Items/{id}` pour récupérer la description, le casting, la note, les métadonnées vidéo/audio et le statut Vu/Non-vu.

### Flux 5 : Lancement d'une Lecture Vidéo
```
Bouton Play ──► PlaybackModel.create()
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
Direct Play ?               Transcode Required ?
  └─ DirectPlaybackModel      └─ TranscodePlaybackModel (/Items/{id}/master.m3u8)
        │                           │
        └─────────────┬─────────────┘
                      ▼
        Lancement MediaKit / VideoPlayerActivity (Android Natif)
```

### Flux 6 : Suivi de la Progression de Lecture
1. Le lecteur émet une mise à jour de position toutes les X secondes.
2. `playbackModel.updatePlaybackPosition(position, isPlaying)` envoie une requête POST vers `/Sessions/Playing/Progress` avec la position en `Ticks` (1 seconde = 10 000 000 ticks).
3. À l'arrêt, `/Sessions/Playing/Stopped` est appelé pour enregistrer le statut de reprise.

### Flux 7 : Téléchargement et Mode Hors-ligne
1. L'utilisateur clique sur "Télécharger".
2. `SyncNotifier` calcule le profil de transcodage local si nécessaire.
3. L'entité est insérée dans la base SQLite locale **Drift** (`database_item.dart`).
4. `background_downloader` effectue la récupération du fichier en arrière-plan.
5. En mode hors-ligne, `OfflinePlaybackModel` lit la source directement depuis le stockage local sans solliciter le réseau.

### Flux 8 : Navigation entre Pages
`AutoRouter` intercepte chaque changement de route. Le `AuthGuard` s'assure que l'état d'authentification dans Riverpod est valide (`ref.read(userProvider) != null`). Si la session expire, redirection automatique vers `LoginRoute`.

### Flux 9 : Communication Interop Native Android (Pigeon)
L'application Flutter communique avec l'activité Android `VideoPlayerActivity.kt` via des méthodes typées générées par Pigeon :
- `VideoPlayerHelper` : Contrôle de la lecture, saut de chapitre, changement de piste.
- `PlayerSettingsHelper` : Réglage de la luminosité, orientation, décodage matériel.
- `TranslationsPigeon` : Envoi des chaînes traduites vers l'interface Compose native Android.

### Flux 10 : Gestion des Erreurs Réseau
`ConnectivityProvider` surveille l'état du réseau (`connectivity_plus`). En cas d'interruption réseau lors d'une requête Chopper, l'application affiche un bandeau adaptatif et bascule automatiquement les requêtes vers le cache local ou le mode hors-ligne.

---

## 6. INVENTAIRE DES DÉPENDANCES ET FRAMEWORKS

### Frameworks de Base
* `flutter` / `flutter_localizations` : SDK Flutter.
* `flutter_riverpod` (`2.6.1`) / `riverpod_annotation` : Gestion d'état.
* `auto_route` (`10.1.2`) / `auto_route_generator` : Navigation par routeur déclaratif.

### Réseau & Données
* `chopper` (`8.3.0`) : Client HTTP réactif.
* `drift` (`2.28.1`) / `drift_flutter` : ORM SQLite persistant.
* `shared_preferences` (`2.5.3`) : Stockage de clé-valeur.
* `json_annotation` / `freezed_annotation` : Sérialisation immutable.

### Média & Lecteur
* `media_kit` (`1.2.2` override Git) : Moteur de lecteur multimédia basé sur `libmpv`.
* `media_kit_video` / `media_kit_libs_android_video` : Rendu vidéo et binaires NDK.
* `audio_service` / `audio_service_mpris` : Contrôles audio système et notifications.
* `fvp` / `video_player` : Lecteur vidéo de secours.

### UI & Utilitaires
* `dynamic_color` / `chinese_font_library` : Système de thèmes adaptatifs Material 3.
* `flutter_svg` / `cached_network_image` / `extended_image` : Gestion des images.
* `font_awesome_flutter` (`11.0.0`) / `iconsax_plus` : Jeux d'icônes.
* `package_info_plus` / `wakelock_plus` / `permission_handler` : Intégrations système.

---

## 7. INVENTAIRE EXHAUSTIF DES RÉFÉRENCES FLADDER

Afin de préparer le changement d'identité vers **NewCalFlix**, voici la catégorisation complète de toutes les occurrences de `Fladder`, `fladder` et `FLADDER` trouvées dans le projet :

### Catégorie A : Identité Visible par l'Utilisateur (Interface & Textes)
* **Textes d'interface (Localisation ARB)** : `lib/l10n/app_*.arb` (ex: `exitFladderTitle`, `exitFladderDesc`, `settingsClientTitle`, `sponsorMessage`, `pasteFladderAuthLink`).
* **Titre de la fenêtre / Application** : [`lib/main.dart`](file:///C:/Users/jeremie/Documents/GitHub/NewCalFlix/lib/main.dart), [`lib/util/application_info.dart`](file:///C:/Users/jeremie/Documents/GitHub/NewCalFlix/lib/util/application_info.dart).
* **Écran "À propos"** : [`lib/screens/settings/about_settings_page.dart`](file:///C:/Users/jeremie/Documents/GitHub/NewCalFlix/lib/screens/settings/about_settings_page.dart) (Legalese "DonutWare", liens sociaux).

### Catégorie B : Application ID / Package Name Android & iOS
* **Android Application ID** : `nl.jknaapen.fladder` (Production) et `nl.jknaapen.fladder.dev` (Développement) dans [`android/app/build.gradle`](file:///C:/Users/jeremie/Documents/GitHub/NewCalFlix/android/app/build.gradle) et Manifestes Android.
* **iOS Bundle Identifier** : `nl.jknaapen.fladder` dans `ios/Runner.xcodeproj/project.pbxproj`.
* **Deep Linking Scheme** : `fladder://` dans `AndroidManifest.xml`, `Info.plist` et `deep_link_helper.dart`.

### Catégorie C : Identifiants Techniques & Noms de Classes Dart / Kotlin
* **Classes Dart** : `_FladderApp`, `FladderConfig`, `FladderScrollBehavior`, `FladderLocalizations`, `FladderLogo`, `FladderIcon`, `FladderImage`, `FladderCacheManager`.
* **Paquets Kotlin Natifs** : `nl.jknaapen.fladder` dans `MainActivity.kt`, `VideoPlayerActivity.kt`, `Theme.kt`.

### Catégorie D : Imports et Références Internes Dart
* All imports starting with `import 'package:fladder/...'` across ~150 files in `lib/`.

### Catégorie E : Noms de Fichiers & Chemins sur Disque
* `icons/production/fladder_icon.png`, `fladder_adaptive_icon.png`, `fladder_store_icon.png`.
* Repérages de dossier Kotlin : `android/app/src/main/kotlin/nl/jknaapen/fladder/`.

### Catégorie F : Projets et Dépendances Externes (Repos Git)
* Repositories Git : `https://github.com/DonutWare/Fladder`
* Widgets Weblate : `https://hosted.weblate.org/engage/fladder/`
* Image Docker : `ghcr.io/donutware/fladder:latest`

### Catégorie G : Métadonnées et Documentation
* `pubspec.yaml` (`name: fladder`, `description: A simple cross-platform Jellyfin client.`)
* `README.md`, `INSTALL.md`, `DEVELOPEMENT.md`, `Dockerfile`, `AppImageBuilder.yml`, `altstore.json`.

---

## 8. MATRICE DE MIGRATION VERS L'IDENTITÉ NEWCALFLIX

Lors de la future phase de migration vers **NewCalFlix**, la règle d'or est de différencier les éléments cosmétiques des identifiants système :

| Élément à Modifier | Risque | Action Recommandée pour Preserver la Stabilité |
| :--- | :---: | :--- |
| **Nom affiché dans l'UI (Textes, L10n)** | **NUL** | Remplacement direct dans les fichiers `.arb` et libellés UI par "NewCalFlix". |
| **Icônes et Logos (`assets/`, `icons/`)** | **NUL** | Remplacement des fichiers PNG/SVG par la nouvelle charte graphique NewCalFlix. |
| **`pubspec.yaml` (`name: newcalflix`)** | **FAIBLE** | Mettre à jour `name: newcalflix` puis exécuter `flutter pub get` et mettre à jour les déclarations `package:newcalflix/...`. |
| **Classes Dart (`FladderApp` -> `NewCalFlixApp`)** | **FAIBLE** | Refactorisation automatique IDE des symboles Dart. |
| **Android Application ID (`nl.jknaapen.fladder`)** | **MODÉRÉ** | *Attention* : Modifier `applicationId` vers `com.newcalflix.app` changera le dossier de stockage des données sur les appareils existants. Prévoir une routine de migration si nécessaire. |
| **Deep Link Scheme (`fladder://`)** | **FAIBLE** | Ajouter la prise en charge de `newcalflix://` tout en conservant `fladder://` comme alias rétrocompatible. |

---

## 9. RECOMMANDATIONS ET RÈGLES DE DÉVELOPPEMENT

1. **Règle d'Immutabilité des Modèles** :
   Toute modification apportée aux modèles dans `lib/models/` doit préserver la sérialisation JSON avec `Freezed` / `dart_mappable`. Toujours réexécuter `dart run build_runner build --delete-conflicting-outputs` après modification d'un modèle.

2. **Respect des Insets & Edge-to-Edge** :
   Conserver les composants de mise en page adaptative (`AdaptiveLayoutBuilder`) pour garantir le rendu sur mobile, tablette et Android TV.

3. **Interventions sur le Lecteur Vidéo Natif** :
   Toute modification du protocole de communication avec `VideoPlayerActivity.kt` doit être déclarée dans le fichier Pigeon d'origine avant de régénérer le code interop.

4. **Conservation des Overrides Git (`media_kit`)** :
   Ne pas supprimer les `dependency_overrides` du fichier `pubspec.yaml` sans avoir préalablement vérifié la compatibilité du composant vidéo NDK.

---
*Ce document sert de référence technique officielle pour le projet **NewCalFlix**.*
