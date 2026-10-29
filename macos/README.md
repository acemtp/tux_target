# Compilation du serveur sur macOS Apple Silicon

Cette adaptation concerne uniquement `tux_target_new`. Le dossier voisin `tux_target` reste la référence et n'est jamais utilisé comme répertoire de sortie.

Validation du 29 octobre 2026 : compilation native arm64 réussie avec AppleClang 21 ; essai de démarrage en mode LAN atteignant `SERVICE: Service ready`, processus vivant pendant quatre secondes puis arrêté. Aucun client connecté, aucune manche jouée dans ce test.

## Reconstruire

Depuis `tux_target_new` :

```sh
./script/build_server_macos.sh
```

Résultat : `build-macos-server/tux-target-srv`, exécutable macOS natif arm64.

Le premier passage télécharge et compile les dépendances dans `.deps/`. Les passages suivants réutilisent les sources et les fichiers déjà compilés. Aucun paquet système n'est installé par le script.

Outils nécessaires : Xcode avec son SDK macOS, CMake, Ninja, Git, curl, make et Python 3. Le script s'appuie sur les bibliothèques Homebrew déjà disponibles dans `/opt/homebrew` : zlib, curl, libpng, jpeg-turbo, giflib et freetype. L'exécutable dépend de plusieurs de ces bibliothèques dynamiques ; ce n'est pas encore une distribution autonome pour d'autres Macs.

## Démarrer / vérifier

```sh
./script/build_and_run.sh
./script/build_and_run.sh --verify
```

La première commande reconstruit puis démarre au premier plan. La seconde vérifie que le processus reste vivant quatre secondes, puis arrête l'instance de test. `--debug` lance le serveur sous LLDB. Le bouton Run de la configuration Codex de ce projet utilise le même script.

La configuration et les journaux sont créés dans `runtime-macos/`. Le répertoire de données y est un lien vers `server/data` du présent dépôt. Le mode LAN (`ShardId = 0`) évite le service central de connexion et MySQL. Les bots automatiques sont désactivés dans cette configuration de démarrage ; leurs ressources de replay ne sont pas disponibles. Le serveur utilise le port TCP 51574 ; LAN ne signifie pas une liaison limitée à l'adresse localhost.

Les scripts ne remplacent pas une configuration de fonctionnement déjà présente dans `runtime-macos/`. Aucun service n'est installé en arrière-plan.

## Dépendances figées pour cet essai

- NeL / Ryzom Core, révision `b64a06e76b13a4d1adc12977edfdd744999ce5d4` du dépôt `https://github.com/ryzom/ryzomcore.git`.
- Lua 5.0.3, téléchargé depuis lua.org, conservant l'ancienne API Lua du jeu.
- ODE 0.16.6, compilation en simple précision (`ODE_DOUBLE_PRECISION=OFF`).

Les archives Lua et ODE sont vérifiées par SHA-256 dans le script. Le correctif NeL est conservé dans `macos/nel-apple-silicon.patch` et appliqué automatiquement à la révision figée.

## Modifications de compatibilité

- Nouveau CMake dédié au serveur macOS : évite les options Linux anciennes (`-lrt`, `-lstdc++`) et la détection obsolète des dépendances du CMake historique.
- Deux espaces ajoutés autour de macros de formats dans `server/src/entity_manager.cpp` pour la syntaxe C++ moderne.
- Identifiant de thread obtenu avec `pthread_mach_thread_np` sur macOS dans `server/src/main.cpp` : l'ancien cast de pointeur vers entier ne compile pas en 64 bits.
- NeL : nom d'architecture Apple `arm64`, retrait de Thumb pour ARM64 et retrait d'une option GCC non adaptée à Clang.
- NeL : tolérance des mesures de profilage nulles lorsque deux lectures consécutives du compteur Apple Silicon tombent dans le même tick. Cela concerne le profilage, pas le pas de simulation du jeu.

Les règles Lua, les cartes et les formules de physique du jeu n'ont pas été modifiées. La boucle active de cette version appelle `updatePhysics()` depuis la boucle principale ; l'ancien lancement d'un thread physique distinct est commenté dans les sources.

## Limites

Une compilation et un démarrage ne prouvent pas que toutes les cartes, les connexions et les manches fonctionnent. Il faudra tester ces chemins avec un client ou un outil de protocole.

La version et les options exactes d'ODE utilisées par le jeu historique ne sont pas établies. ODE 0.16.6 permet cet essai de compilation ; la fidélité physique stricte doit être validée séparément avant de considérer cette version comme la référence de gameplay.

Les sources anciennes produisent encore des avertissements, notamment sur les formats de journalisation et certains chargements de replay. Cette adaptation ne constitue pas une revue complète pour une exposition publique sur Internet.

Journaux de construction : `.deps/lua-build.log`, `.deps/ode-build.log`, `.deps/nel-build.log`, `.deps/server-build.log`. Les erreurs de configuration sont dans les fichiers `*-configure.log` du même répertoire.
