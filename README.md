# appdev — conteneur dev unifié (Apache/PHP-FPM + Node + Python + SSH)

Remplace l'add-on `somel-apache2`. Tourne sur HAOS via **Portainer** (add-on, `docker.sock`
de l'hôte monté, mode protégé désactivé) plutôt que via le système d'add-on classique.

## Structure

```
appdev/
├── Dockerfile
├── docker-compose.yml
├── .env.example          → copier en .env, ne JAMAIS versionner publiquement (contient ROOT_PASSWORD)
├── config/
│   ├── apache/sites-available/000-default.conf
│   ├── php-fpm/www.conf
│   ├── ssh/authorized_keys   → coller ta clé publique ici
│   └── supervisor/supervisord.conf
└── README.md
```

## Récupérer sa clé publique SSH (celle à coller dans `authorized_keys`)

Sur la machine depuis laquelle tu te connectes (jamais le serveur — c'est ta clé **publique**,
celle qui ne pose aucun risque à copier/coller) :

- **macOS / Linux** : `cat ~/.ssh/id_ed25519.pub` (ou `id_rsa.pub` si c'est une paire plus ancienne)
- **Windows (PowerShell)** : `type $env:USERPROFILE\.ssh\id_ed25519.pub`
- **Pas de clé existante** : en générer une avec `ssh-keygen -t ed25519 -C "franck@kodlix"`
  (touches Entrée pour accepter l'emplacement par défaut, passphrase optionnelle), puis reprendre
  la commande `cat`/`type` ci-dessus.

Le fichier commence par `ssh-ed25519 AAAA...` (ou `ssh-rsa AAAA...`) suivi d'un commentaire —
c'est cette ligne entière qu'il faut coller dans `config/ssh/authorized_keys`.

## Installation sur HAOS

1. Copier tout ce dossier dans `/share/appdev/` (accessible depuis Portainer via le bind mount HAOS).
2. `cp .env.example .env` puis éditer `ROOT_PASSWORD`.
3. Coller ta clé publique dans `config/ssh/authorized_keys` (voir section ci-dessus).
4. Dans Portainer : **Stacks → Add stack**, coller le contenu de `docker-compose.yml`
   (ou pointer vers le repo Git si tu synchronises via GitHub), déployer.
5. `ssh root@<ip-haos> -p 2222` (ou mot de passe défini dans `.env`).

## Usage courant (tout en SSH, pas d'admin UI pour l'instant)

- Reload Apache après modif d'un vhost : `apachectl graceful`
- Reload PHP-FPM après modif d'un pool : `supervisorctl restart php-fpm`
- Lancer un test Node/Python sur un port libre (3001-3006) : `node app.js --port 3004`
- Chaque site PHP garde son propre `composer.json`/`vendor/` dans son dossier sous `/share/htdocs`.

## Multi-versions PHP (si besoin plus tard)

Le choix Apache + PHP-FPM (plutôt que mod_php) a été fait exactement pour ça :
1. Ajouter `php7.4-fpm` (ou la version voulue) dans le `Dockerfile` (le dépôt Sury est déjà configuré).
2. Créer un pool séparé dans `config/php-fpm/` avec un autre socket unix.
3. Ajouter un second `<FilesMatch>` dans le vhost (ou un vhost dédié) pointant vers ce socket.
4. Ajouter la ligne `[program:php-fpm-XX]` correspondante dans `supervisord.conf`.

## Backup / restauration

- **Ce qui doit être sauvegardé** (instantané simple, pas de versioning) : le dossier
  `/share/appdev/` en entier (ce dossier — compose, .env, config/). Un `tar`/`rsync` cron vers
  le disque USB déjà monté sur HA suffit.
- **Ce qui n'est PAS dans ce backup** : les données applicatives (`/share/htdocs`), déjà couvertes
  par les snapshots Supervisor HAOS existants.
- **Copie "publique" (GitHub/Joplin)** : retirer `.env` (mot de passe) et `config/ssh/authorized_keys`
  (clé perso) avant de pousser — garder uniquement `.env.example` avec des valeurs neutres.
- **Restauration après réinstall** : recréer `/share/appdev/` depuis le backup (ou re-cloner le
  repo + recopier `.env` et `authorized_keys` depuis Joplin), coller le `docker-compose.yml` dans
  Portainer, redéployer. Les chemins des bind mounts ne changent pas.
