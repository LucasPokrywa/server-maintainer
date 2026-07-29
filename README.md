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

Créer le fichier local contenant les identifiants :

```bash
cp .env.example .env
```

Compléter ensuite `.env` :

```dotenv
SERVER1_ANSIBLE_USER=your_server_user
SERVER1_ANSIBLE_PASSWORD=your_server_password
BACKUP_SERVER_ANSIBLE_USER=your_backup_user
BACKUP_SERVER_ANSIBLE_PASSWORD=your_backup_password
```

Si une valeur contient des caractères interprétés par Bash, l'entourer de
guillemets simples. Le fichier `.env` est ignoré par Git et ne doit jamais
être ajouté au dépôt.

## Configuration

Les serveurs, adresses, paquets, ports et paramètres SELinux se configurent
dans `inventory.yaml`.

L'inventaire fourni contient deux groupes :

- `managed_servers` : serveurs administrés et sauvegardés ;
- `backup_servers` : serveurs recevant les sauvegardes.

Avant un déploiement, adapter au minimum :

- `ansible_host` pour chaque machine ;
- `ssh_pubkey` avec le chemin de la clé publique locale ;
- `firewall_rules` avec les ports réellement nécessaires ;
- `packages` avec les logiciels à installer.

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
chargé les variables de `.env` :

```bash
set -a
source .env
set +a
ansible-playbook -i inventory.yaml playbook.yaml --tags monitor
```

## Rôles

| Rôle | Description |
| --- | --- |
| `ssh` | Installe les clés et renforce la configuration SSH |
| `cron` | Programme les mises à jour système le dimanche à 02:00 |
| `monitor` | Collecte les statistiques chaque heure à la minute 15 |
| `ports` | Configure les règles iptables et la politique d'entrée |
| `packages` | Installe les paquets déclarés dans l'inventaire |
| `selinux` | Installe, active et configure SELinux |
| `backup` | Sauvegarde les serveurs gérés le dimanche à 00:00 |

Les statistiques sont enregistrées dans
`/opt/monitor/server_stats.csv` sur chaque serveur.

Les sauvegardes sont stockées sur le serveur de sauvegarde dans
`/opt/backup/<serveur>/<date>`. Chaque exécution crée un répertoire horodaté
et ne supprime pas les sauvegardes précédentes. Une politique de rétention
doit donc être définie séparément selon l'espace disponible.

## Précautions

Ce projet modifie des composants sensibles et doit d'abord être testé dans
un environnement isolé.

- Le rôle SSH désactive l'authentification par mot de passe.
- Le rôle `ports` applique une politique `DROP` aux connexions entrantes.
- Le rôle cron effectue une mise à niveau complète et redémarre le serveur.
- L'activation de SELinux peut provoquer un redémarrage et un réétiquetage.
- La première sauvegarde peut consommer beaucoup d'espace disque et de
  bande passante.

Vérifier l'accès par clé SSH et conserver une console de secours avant le
premier déploiement.

## Vérification

Contrôler la syntaxe du playbook sans l'exécuter :

```bash
set -a
source .env
set +a
ansible-playbook -i inventory.yaml playbook.yaml --syntax-check
```

Pour visualiser les changements prévus, Ansible propose aussi le mode
simulation, sous réserve que les modules employés le prennent en charge :

```bash
ansible-playbook -i inventory.yaml playbook.yaml --check --diff
```

## Licence

Ce projet est distribué sous licence MIT. Voir le fichier [LICENSE](LICENSE).
