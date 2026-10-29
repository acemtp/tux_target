# Client natif macOS Apple Silicon

Validation du 29 octobre 2026 : **compilation arm64 et démarrage réussis**. La fenêtre du client affiche le menu MTP Target avec les boutons « How To Play », « Play Online », « Play on lan » et « Exit ». Le rendu a été vérifié visuellement. Les journaux confirment l'initialisation d'OpenGL et d'OpenAL Soft.

Aucune connexion à un serveur et aucune manche n'ont été testées à cette étape. Le dossier `tux_target` n'a pas été modifié.

## Construire et ouvrir

Depuis `tux_target_new` :

```sh
./script/build_client_macos.sh
./script/build_and_run_client.sh
```

La première commande compile et prépare `dist/Tux Target.app`. La seconde reconstruit puis ouvre cette application. On peut également ouvrir directement `dist/Tux Target.app` dans le Finder une fois la construction terminée.

Le script de lancement propose `--debug` (LLDB) et `--verify` (vérification de présence du processus après cinq secondes, sans validation du rendu ni du gameplay). La configuration Codex possède une action « Run client » ; l'action serveur existante est conservée.

## Organisation

- `build-macos-client/` : objets et exécutable du client.
- `.deps/build-nel-client/` : construction NeL distincte de celle du serveur, avec les pilotes graphiques et audio liés statiquement.
- `.deps/install-openal/` : OpenAL Soft 1.24.3, construit localement sans installation système ; archive vérifiée par SHA-256.
- `dist/Tux Target.app/` : application locale avec son fichier Info.plist.
- `runtime-macos-client/` : configuration, cache, replays et journaux. Le dossier Resources de l'application pointe vers ce répertoire.

La configuration initiale provient de `client/tux-target.cfg.in`. Elle utilise une fenêtre et cherche les ressources dans `client/data` et `server/data` du présent dépôt. La capture de souris d'origine est conservée pendant le jeu ; dans les menus, le curseur reste disponible. Le script de préparation conserve une configuration déjà créée. Les chemins XDG utilisés par le lanceur restent également dans le présent dépôt.

L'application n'est pas encore un paquet distribuable : elle dépend de bibliothèques Homebrew présentes sur ce Mac et de chemins locaux vers les ressources. Elle n'est ni notarialisée ni préparée pour d'autres machines.

## Adaptations du code client

- Qualification explicite du type `NLMISC::CHashKey` dans deux en-têtes.
- Désactivation conditionnelle de deux appels supprimés du NeL actuel : ancien réglage des fragment programs et ancien callback d'envoi de rapport par courriel. Les anciens appels restent disponibles hors compilation `TUX_MODERN_NEL`.
- Remplacement de `random_shuffle`, supprimé de C++17, pour mélanger la playlist ; cela ne concerne pas les règles du jeu.
- Adaptation de `getSongTitle` à la signature audio actuelle.
- Correction du répertoire de travail macOS : le client utilise l'URL Resources sans dépendre de `CFBundleGetVersionNumber`, qui retournait zéro pour cette version. Conversion du chemin dans un tampon et libération de l'URL CoreFoundation.

Les cartes et les règles Lua n'ont pas été modifiées. Les sources du serveur restent dans l'état de la précédente compilation.

## Correction des commandes sur Apple Silicon

Le compteur Mach utilise sur ce Mac un rapport différent de 1:1. La conversion `CTime::ticksToSecond` du NeL retenu inverse ce rapport : les durées du client deviennent beaucoup trop petites, ce qui réduit fortement la réponse des commandes et de la caméra. `CTimeTask` utilise désormais `std::chrono::steady_clock` sur macOS. La simulation du serveur n'est pas modifiée.

Le premier essai de paquet avait également désactivé `CaptureMouse`, ce qui ne convient pas au branchement historique de l'écouteur de caméra. La configuration de test et les nouveaux paquets gardent maintenant `CaptureMouse = 1`. Le réglage historique `AllowMouse = 2` demande de maintenir le bouton gauche pour tourner la caméra.

Enfin, Cocoa transmet les touches modificatrices par `NSFlagsChanged`, que NeL ignorait. `macos/nel-client-input.patch` traduit désormais Ctrl, Maj et Option vers les événements de touches NeL. Ce correctif, appliqué automatiquement par le script client, permet notamment la commande Ctrl d'ouverture/fermeture.

Test de régression de l'horloge :

```sh
cmake --build build-macos-client --target tux-target-clock-check
./build-macos-client/tux-target-clock-check
```

Le test vérifie qu'une attente réelle de 150 ms avance l'horloge du client d'environ 150 ms, et que sa réinitialisation remet le delta à zéro. Il a réussi après correction. La réponse complète des commandes reste à confirmer en partie par le joueur.

### Touches bloquées après plusieurs appuis / manches

Un test indépendant du jeu reproduisait un relâchement de flèche non transmis au premier écouteur clavier lorsque trois écouteurs étaient enregistrés (clavier, interface et souris). La réception native macOS des relâchements était pourtant correcte.

La cause est dans `CEventServer` : l'ancien code commence son parcours d'une `std::multimap` avec `find`, qui peut désigner une occurrence au milieu des écouteurs d'un même événement. Les précédents sont alors ignorés. Avec la bibliothèque C++ de ce Mac, les appuis arrivaient au clavier mais certains relâchements le contournaient. Le remplacement par `lower_bound` garantit de commencer au premier écouteur, aussi bien pour distribuer un événement que pour retirer un écouteur.

Ce correctif fait partie de `macos/nel-client-input.patch`, avec la remise à zéro du clavier lors de la perte de focus de la fenêtre Cocoa. Le serveur déjà lancé et ses règles physiques ne sont pas modifiés par cette correction du client.

```sh
cmake --build build-macos-client --target tux-target-input-check
./build-macos-client/tux-target-input-check
```

Le test échouait avant correction (`Key stuck: 37`) et passe après correction. Il vérifie les quatre flèches et Ctrl, trois cycles successifs, l'ensemble des trois écouteurs, le retrait/réenregistrement d'un écouteur et la perte de focus.

La variable d'environnement facultative `TUX_INPUT_DIAGNOSTICS=1` active des journaux locaux des états des touches et des commandes. Elle est désactivée par défaut et n'envoie aucune donnée à un service externe.

### Caméra au trackpad sur macOS

La capture macOS utilise maintenant les déplacements relatifs natifs de Cocoa (`deltaX` / `deltaY`). Le recentrage historique à chaque événement ramenait les coordonnées au centre et créait des mouvements synthétiques, ce qui empêchait la caméra de réagir normalement. Le passage par l'ancien pont Carbon est également évité dans la boucle d'événements autonome afin de conserver les informations du mouvement natif.

Pendant la capture, le pointeur est dissocié des mouvements physiques ; il est rétabli dans les menus, à la perte de focus et à la destruction de la fenêtre. Le client ne réenregistre plus deux fois le même écouteur de souris.

Le réglage d'origine `AllowMouse = 2` est conservé : maintenir le clic gauche et déplacer un doigt sur le trackpad tourne la caméra ; relâcher ramène la vue derrière le personnage. Sans clic, la caméra reste en suivi automatique. Les autres modes de souris du jeu ne sont pas remplacés.

Vérification après correction : les journaux en partie montrent des coordonnées relatives non nulles, des angles de caméra modifiés pendant un déplacement avec clic maintenu et leur remise à zéro au relâchement. Les tests de régression du clavier et de l'horloge passent toujours. Le diagnostic facultatif inclut les positions, boutons, mode de souris, présence d'interface et angles dans `runtime-macos-client/mouse-test.log` pour la session de test.

## Musique et effets audio

La playlist configurée utilise maintenant `mtp-target.m3u`, qui référence `zik.ogg`, la musique présente dans le dépôt. La migration ne remplace pas une playlist personnalisée. Les volumes sont appliqués après l'initialisation du moteur audio ; le gestionnaire fonctionne aussi avec musique activée et effets désactivés.

Les WAV étaient présents sans les définitions NeL nécessaires. Le script de préparation génère dans `runtime-macos-client/audio` les définitions d'ouverture, fermeture, impact et compte à rebours ; il copie les schémas Georges depuis les exemples du NeL figé dans `.deps`. Au démarrage, le client construit et charge la banque d'échantillons `cache/audio/mtp_target.sample_bank` et les définitions compilées `sounds.packed_sheets`. L'impact utilise `impact.wav`, et non l'ancien identifiant `beep` absent.

`ready.wav` contient l'intégralité du décompte « 5, 4, 3, 2, 1, go ». L'unique source `ready` est lancée une fois lorsque tous les joueurs sont prêts ; l'affichage des chiffres et de « Go » ne redéclenche aucun son. Les anciens alias générés par chiffre sont supprimés par la préparation du paquet. Le fichier `splash.wav` manque : le son d'entrée dans l'eau reste indisponible, sans remplacement arbitraire.

```sh
cmake --build build-macos-client --target tux-target-audio-check
cd runtime-macos-client
../build-macos-client/tux-target-audio-check /chemin/absolu/vers/tux_target_new
```

Le test d'intégration vérifie sur la sortie OpenAL du Mac les quatre sources d'effets et la lecture OGG après plusieurs mises à jour. Il joue un court extrait à faible volume, puis s'arrête. Les journaux du client confirment aussi le chargement de la playlist et du fichier OGG.

Les avertissements sur les configurations optionnelles `default.mixer_config` et `user_var_binding.packed_sheets` peuvent subsister : le client emploie les paramètres de mixage par défaut et charge sa banque explicitement.

Des avertissements de compilation subsistent dans les sources historiques et NeL. Les fonctions réseau, l'éditeur et le rendu des niveaux restent à essayer. Le menu affiche la chaîne de version historique du client ; l'étiquette du paquet macOS ne constitue pas une nouvelle version du jeu.

## Journaux

- `.deps/openal-configure.log`, `.deps/openal-build.log`
- `.deps/nel-client-configure.log`, `.deps/nel-client-build.log`
- `.deps/client-configure.log`, `.deps/client-build.log`
- `.deps/audio-check-build.log`, `runtime-macos-client/audio-check.log`
- `runtime-macos-client/client-stdout.log`, `client-stderr.log`, `log.log`

OpenAL Soft : https://github.com/kcat/openal-soft/releases/tag/1.24.3
