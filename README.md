# Server Maintainer

Server Maintainer est un projet Ansible destiné à préparer, sécuriser et
maintenir des serveurs Debian. Il configure SSH, le pare-feu, les paquets,
les mises à jour automatiques, la supervision, SELinux et les sauvegardes.

## Fonctionnalités

- installation des paquets définis pour chaque serveur ;
- installation d'une clé publique SSH ;
- désactivation de l'authentification SSH par mot de passe ;
- désactivation de la connexion SSH directe de `root` ;
- configuration d'iptables avec maintien du port SSH utilisé par Ansible ;
- mise à jour hebdomadaire du système avec cron ;
- collecte horaire des statistiques disque, mémoire et CPU ;
- installation et configuration facultatives de SELinux ;
- sauvegarde hebdomadaire des serveurs gérés avec `rsync`.

## Prérequis

La machine de contrôle doit disposer de :

- Python 3 et du module `venv` ;
- une clé publique SSH ;
- un accès réseau aux serveurs ;
- un utilisateur distant autorisé à employer `sudo`.

Le script `deploy` crée automatiquement l'environnement virtuel Python et
installe Ansible ainsi que les collections nécessaires.

Le projet cible actuellement Debian Trixie. Son utilisation sur une autre
distribution n'est pas garantie.

## Installation

Cloner le dépôt puis entrer dans son répertoire :

```bash
git clone git@github.com:LucasPokrywa/server-maintainer.git
cd server-maintainer
```

Créer le fichier local contenant le chemin de la clé publique :

```bash
cp .env.example .env
```

Compléter ensuite `.env` :

```dotenv
SSH_PUBLIC_KEY_PATH=/home/your_user/.ssh/id_ed25519.pub
```

Si une valeur contient des caractères interprétés par Bash, l'entourer de
guillemets simples. Le fichier `.env` est ignoré par Git et ne doit jamais
être ajouté au dépôt.

Créer ensuite le Vault contenant les identifiants :

```bash
mkdir -p group_vars/all
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
openssl rand -hex -out .vault-password 32
chmod 600 .vault-password group_vars/all/vault.yml
ansible-vault encrypt \
  --vault-password-file .vault-password \
  group_vars/all/vault.yml
```

Les fichiers `group_vars/all/vault.yml` et `.vault-password` sont ignorés par
Git. Le premier est chiffré, tandis que le second donne accès à tous les
secrets : conserver une copie de `.vault-password` dans un gestionnaire de
secrets sécurisé.

Modifier ultérieurement les identifiants :

```bash
ansible-vault edit \
  --vault-password-file .vault-password \
  group_vars/all/vault.yml
```

## Configuration

Les serveurs, adresses, paquets, ports et paramètres SELinux se configurent
dans `inventory.yaml`.

L'inventaire fourni contient deux groupes :

- `managed_servers` : serveurs administrés et sauvegardés ;
- `backup_servers` : serveurs recevant les sauvegardes.

Les alias des machines sont libres : les rôles utilisent les groupes et ne
dépendent d'aucun nom d'hôte particulier. Le groupe `backup_servers` doit
contenir exactement une machine.

Avant un déploiement, adapter au minimum :

- `ansible_host` pour chaque machine ;
- `SSH_PUBLIC_KEY_PATH` dans `.env`, avec le chemin de la clé publique locale ;
- `ports_firewall_rules` avec les ports réellement nécessaires ;
- `packages_list` avec les logiciels à installer.

Les principaux paramètres d'exploitation disposent de valeurs par défaut et
peuvent être surchargés dans `inventory.yaml` :

```yaml
all:
  vars:
    cron_automatic_reboot: false
    cron_update_minute: "0"
    cron_update_hour: "2"
    cron_update_weekday: "0"
    monitor_cron_minute: "15"
    backup_cron_minute: "0"
    backup_cron_hour: "0"
    backup_cron_weekday: "0"
    backup_retention_days: 30
    backup_min_free_gb: 10
    logrotate_retention: 8
```

Les scripts utilisent `flock` pour empêcher les exécutions simultanées. Les
échecs sont toujours envoyés au journal système avec `logger`. Une commande
d'alerte externe peut être configurée pour chaque fonction :

```yaml
all:
  vars:
    cron_alert_command: /usr/local/bin/send-alert
    monitor_alert_command: /usr/local/bin/send-alert
    backup_alert_command: /usr/local/bin/send-alert
```

La commande reçoit le message d'erreur comme premier argument. Elle peut par
exemple transmettre l'alerte à un service de messagerie ou de supervision.

Chaque règle de pare-feu doit déclarer un port valide, le protocole `tcp` ou
`udp`, ainsi qu'un commentaire. Le port SSH réellement employé par Ansible
est autorisé automatiquement avant l'application de la politique `DROP`.

## Utilisation

Le déploiement par défaut configure SSH, cron, le pare-feu et les paquets :

```bash
./deploy
```

Options disponibles :

```text
-s, --selinux     Configurer également SELinux
-m, --monitor     Configurer également la supervision
-a, --all         Ajouter SELinux et la supervision
-b, --backup      Configurer également les sauvegardes
-d, --debug N     Activer la verbosité Ansible, avec N entre 1 et 3
-h, --help        Afficher l'aide
```

Exemples :

```bash
./deploy --monitor
./deploy --backup --debug 2
./deploy --all --backup
```

Il est également possible d'exécuter directement le playbook après avoir
chargé les variables de `.env` et indiqué le mot de passe Vault :

```bash
set -a
source .env
set +a
ansible-playbook \
  --vault-password-file .vault-password \
  -i inventory.yaml playbook.yaml --tags monitor
```

## Rôles

| Rôle | Description |
| --- | --- |
| `ssh` | Installe les clés et renforce la configuration SSH |
| `cron` | Programme les mises à jour système le dimanche à 02:00 |
| `monitor` | Collecte les statistiques chaque heure à la minute 15 |
| `logrotate` | Assure la rotation et la compression des journaux |
| `ports` | Configure et rend persistantes les règles iptables |
| `packages` | Installe les paquets déclarés dans l'inventaire |
| `selinux` | Installe, active et configure SELinux |
| `backup` | Sauvegarde les serveurs gérés le dimanche à 00:00 |

Les statistiques sont enregistrées dans
`/opt/monitor/server_stats.csv` sur chaque serveur.

Les sauvegardes sont stockées sur le serveur de sauvegarde dans
`/opt/backup/<serveur>/<date>`. Chaque exécution crée un répertoire horodaté
et supprime les répertoires plus anciens que `backup_retention_days`. La
valeur par défaut est de 30 jours. La sauvegarde est annulée si l'espace
disponible est inférieur à `backup_min_free_gb`, soit 10 Gio par défaut.

Une sauvegarde terminée contient un marqueur
`.server-maintainer-backup-complete`. Le script ne crée ce marqueur qu'après
avoir vérifié la présence de `/etc/os-release` et `/etc/passwd`.

## Précautions

Ce projet modifie des composants sensibles et doit d'abord être testé dans
un environnement isolé.

- Le rôle SSH désactive l'authentification par mot de passe.
- Le rôle `ports` applique une politique `DROP` aux connexions entrantes.
- Le rôle cron effectue une mise à niveau complète. Le redémarrage automatique
  est désactivé par défaut et se contrôle avec `cron_automatic_reboot`.
- L'activation de SELinux peut provoquer un redémarrage et un réétiquetage.
- La première sauvegarde peut consommer beaucoup d'espace disque et de
  bande passante.

Vérifier l'accès par clé SSH et conserver une console de secours avant le
premier déploiement.

Le rôle SSH valide `sshd_config` avec `sshd -t` avant tout redémarrage. Le
rôle de sauvegarde enregistre également l'empreinte du serveur de destination
dans le fichier `known_hosts` de `root`.

## Vérification

Contrôler la syntaxe du playbook sans l'exécuter :

```bash
set -a
source .env
set +a
ansible-playbook \
  --vault-password-file .vault-password \
  -i inventory.yaml playbook.yaml --syntax-check
```

Pour visualiser les changements prévus, Ansible propose aussi le mode
simulation, sous réserve que les modules employés le prennent en charge :

```bash
ansible-playbook \
  --vault-password-file .vault-password \
  -i inventory.yaml playbook.yaml --check --diff
```

Vérifier en lecture seule qu'il existe suffisamment de sauvegardes récentes
et que leurs fichiers essentiels sont présents :

```bash
ansible-playbook \
  --vault-password-file .vault-password \
  -i inventory.yaml verify_backups.yaml
```

Ce contrôle améliore la détection des sauvegardes incomplètes, mais ne
remplace pas un exercice de restauration sur une machine Debian isolée. Une
restauration réelle doit utiliser une cible explicitement dédiée afin de ne
pas écraser un serveur existant.

Exécuter les contrôles de qualité locaux :

```bash
pip install -r requirements-dev.txt
ANSIBLE_VAULT_PASSWORD_FILE=.vault-password ansible-lint
```

La CI GitHub exécute les vérifications syntaxiques et `ansible-lint` avec des
identifiants factices provenant de `vault.yml.example`.

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](LICENSE).
