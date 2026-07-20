# 📘 Documentation Technique : Workflow de Sauvegarde Salesforce

# 1️⃣ Fonctionnement du full backup
## 🎯 Objectif du Workflow
Ce script automatise la **sauvegarde quotidienne des métadonnées** de plusieurs organisations Salesforce (Dev, UAT, Prod, etc.) vers des branches Git spécifiques. Il s'exécute via un conteneur Docker pré-configuré (`nanon22/sf_backup`) qui contient déjà les outils nécessaires (SFDX CLI, Python, jq, Git).

---

## ⚙️ 1. Déclencheurs et Environnement

* **Fréquence (`cron`) :** Le backup se lance automatiquement tous les jours à **23h41 UTC**.
* **Déclenchement Manuel (`workflow_dispatch`) :** Vous pouvez lancer le backup à la demande depuis l'interface GitHub ("Run workflow").
* **Conteneur :** Le job ne tourne pas sur la machine virtuelle Ubuntu standard, mais à l'intérieur de l'image Docker `nanon22/sf_backup:latest`. Cela signifie que vous n'avez pas besoin d'installer SFDX ou Python dans les étapes du script ; ils sont déjà là.
* **test matrixmatrix :** au début des fichiers de backup mettre à jour les orgs cibles dans la partie stratégie
 
```
    strategy:
      matrix:
          # These must match your GitHub Environment names exactly
        env: [UAT, PROD]
```


---

## 🛠️ 2. Configuration Requise (Ce que vous devez faire)

Pour que ce script fonctionne sur un nouveau projet, vous devez configurer trois éléments clés dans le répertoire GitHub.

### A. Les Variables d'Environnement (Repository Variables)

#### variables globales
Ces variables définissent l'identité de l'utilisateur qui effectuera les commits de backup.
* `vars.BACKUP_USEREMAIL` : Email GitHub.
* `vars.BACKUP_USERNAME` : Username GitHub.

#### variables d'environnements
créer un environnement par org à sauvegarder. et ajouter les variables :

* `vars.BRANCH_NAME` : branche vers laquelle pousser le résultat du backup
* `vars.BACKUP_MESSAGE` : message de commit automatique

### B. Le Secret d'Authentification (Repository Secrets)
C'est la partie la plus critique. Le script attend un secret nommé `SFDXAUTHURL`.

* **Format :** Ce secret doit contenir un objet **JSON** regroupant les URLs d'authentification de toutes vos orgs, et ce JSON doit être encodé en **Base64**.
* **Exemple de contenu avant encodage :**
    ```json
    {
      "DEV_AUTH": "force://PlatformCLI::Key@votre-instance-dev.my.salesforce.com",
      "PROD_AUTH": "force://PlatformCLI::Key@votre-instance-prod.my.salesforce.com"
    }
    ```
    *Vous devez encoder ce JSON en Base64 et coller le résultat dans le secret GitHub.*
### C. Le Fichier de Configuration (`backup_config.json`)
Vous devez créer un fichier nommé `backup_config.json` à la racine du dépôt. Le script lit ce fichier pour savoir quelles orgs sauvegarder.

### D. configuration des variables d'environnements  
**Structure attendue par le script :**
```json
{
  "environments": [
    {
      "name": "DevOrg",
      "branch_name": "backup/dev",
      "message": "Backup Automatique Dev",
      "auth_url_variable_name": "DEV_AUTH"
    },
    {
      "name": "ProdOrg",
      "branch_name": "backup/prod",
      "message": "Backup Automatique Prod",
      "auth_url_variable_name": "PROD_AUTH"
    }
  ]
}
```
* `name` : Alias donné à l'org lors de la connexion.
* `branch_name` : La branche Git où le code sera poussé (⚠️ **cette branche doit exister au préalable**).
* `auth_url_variable_name` : La clé correspondante dans votre JSON secret `SFDXAUTHURL`.

---

## 🔍 3. Analyse du Script (Pas à pas)

Voici ce que fait le script techniquement, ligne par ligne :

1.  **Initialisation Git :**
    Il configure l'utilisateur Git et marque le répertoire courant comme "safe" (nécessaire dans les conteneurs GitHub Actions).

2.  **Chargement de la Configuration :**
    ```bash
    if [ -f backup_config.json ]; then ...
    ```
    Il vérifie si votre fichier `backup_config.json` existe. Si oui, il l'utilise pour écraser la configuration par défaut du conteneur (`/config.json`).

3.  **Boucle sur les Environnements :**
    Il lit le tableau `environments` du JSON et itère sur chaque entrée. Pour chaque environnement, il extrait les variables (Nom, Branche, Message, Clé d'URL).

4.  **Changement de Branche (`git switch`) :**
    Il bascule sur la branche cible (ex: `backup/dev`).
    *Note technique : Le `checkout` initial est fait avec `fetch-depth: 0`, ce qui est crucial car cela télécharge tout l'historique, permettant au script de basculer entre les branches.*

5.  **Authentification Dynamique :**
    ```bash
    SFDXAUTHURL=$(echo "${{ secrets.SFDXAUTHURL }}" | base64 --decode | jq -r .$SFDXAUTHURL_NAME)
    ```
    Il récupère le secret global, le décode, et utilise `jq` pour extraire uniquement l'URL de l'environnement en cours (basé sur `auth_url_variable_name`). Il crée ensuite un fichier temporaire `SFDX_URL.txt` pour connecter la CLI Salesforce.

6.  **Génération du Manifest (`package.xml`) :**
    `sf project generate manifest --from-org $ORG_NAME`
    Il interroge l'org pour savoir quelles métadonnées sont présentes et génère un fichier `package.xml`.

7.  **Nettoyage (`sanitize.py`) :**
    `python /utils/sanitize.py package.xml`
    Le script exécute un utilitaire Python (inclus dans le conteneur Docker) pour nettoyer le `package.xml`. Cela sert retirer les doublons de métadonnées ou à segmenter le fichier en plusieurs s'il contient trop de métadonnées (+10000).

8.  **Récupération (`Retrieve`) :**
    Il télécharge physiquement les métadonnées filtrées dans le dossier `SanitizedPackages`.

9.  **Commit et Push :**
    Il ajoute les fichiers, fait un commit avec la date courante, et pousse vers la branche dédiée (`origin $BRANCH_NAME`).

### ⚠️ Points de Vigilance pour le Release Manager

1.  **Création des branches :** Assurez-vous que les branches définies dans `backup_config.json` (ex: `backup/dev`) existent déjà dans le repo. Le script fait un `switch`, pas un `checkout -b`.
2.  **Expiration des Tokens :** L'URL SFDX ("Sfdx Auth Url") contient souvent un Refresh Token. S'il expire ou est révoqué, le backup échouera.
3.  **Encodage Base64 :** L'erreur la plus fréquente est d'oublier d'encoder le JSON des secrets en Base64 ou de faire une erreur de syntaxe JSON à l'intérieur.


# 2️⃣ Fonctionnement du partial backup

## 🎯 Objectif du Workflow
Ce script automatise la **sauvegarde partielle et fréquente** des métadonnées. Contrairement au backup complet qui récupère tout, ce workflow est conçu pour tourner plus souvent (toutes les 6 heures) et utilise un script Python spécifique (`sf_backup.py`) pour identifier et récupérer les métadonnées (probablement basé sur les modifications récentes ou une requête spécifique).

---

## ⚙️ 1. Déclencheurs et Environnement

* **Fréquence Élevée (`cron`) :** Le backup se lance automatiquement **toutes les 6 heures** à la 11ème minute (00h11, 06h11, 12h11, 18h11 UTC).
    * Syntaxe : `cron: "11 */6 * * *"`
* **Déclenchement Manuel :** Possible via `workflow_dispatch`.
* **Conteneur :** Utilise la même image Docker `nanon22/sf_backup:latest` contenant les outils requis.

---

## 🛠️ 2. Configuration Requise

La configuration est **identique** à celle du backup complet. Si vous avez déjà configuré le Full Backup, ce workflow utilisera les mêmes paramètres.

### A. Variables et Secrets (GitHub Settings)
* `vars.BACKUP_USEREMAIL` & `vars.BACKUP_USERNAME` : Identité Git.
* `secrets.SFDXAUTHURL` : Objet JSON (encodé Base64) contenant les URLs d'authentification.

### B. Fichier de Configuration (`backup_config.json`)
Le script utilise le même fichier `backup_config.json` à la racine pour itérer sur les environnements.

```json
{
  "environments": [
    {
      "name": "DevOrg",
      "branch_name": "backup/dev",
      "message": "Backup Partiel Dev",
      "auth_url_variable_name": "DEV_AUTH"
    }
  ]
}
```

---

## 🔍 3. Analyse des Différences Techniques

La structure globale est similaire au backup complet (Init Git -> Loop -> Auth -> Switch Branch), mais l'étape de génération du manifest change radicalement.

### Le Cœur du Processus (La différence clé)

Au lieu de demander à Salesforce "Donne-moi tout" (`sf project generate manifest`), ce script effectue une opération plus chirurgicale :

1.  **Extraction des Tokens :**
    Après l'authentification `sf org login`, le script extrait l'Access Token et l'URL de l'instance :
    ```bash
    ACCESS_TOKEN=$(echo $LOGIN_INFO | jq -r .result.accessToken)
    INSTANCE_URL=$(echo $LOGIN_INFO | jq -r .result.instanceUrl)
    ```

2.  **Exécution du Script Python Dédié :**
    ```bash
    python /sf_backup.py $ACCESS_TOKEN $INSTANCE_URL --query-all
    ```
    * **Action :** Il appelle le script `/sf_backup.py` présent dans le conteneur avec l'argument `--query-all`.
    * **Rôle probable :** Ce script interroge l'API Salesforce (probablement l'objet `SourceMember` ou via Tooling API) pour identifier les composants qui ont changé ou qui répondent à des critères spécifiques, au lieu de scanner toute l'org.
    * **Sortie :** Il génère un `package.xml` ciblé dans le dossier `SanitizedPackages`.

3.  **Récupération et Push :**
    ```bash
    sf project retrieve start -x SanitizedPackages/*
    ```
    Il ne télécharge que les éléments identifiés par le script Python, rendant le backup beaucoup plus rapide et léger.

### ⚠️ Points de Vigilance pour le Release Manager

1.  **Volume de Commits :** Comme ce script tourne 4 fois par jour, l'historique Git de la branche de backup va grandir rapidement.
2.  **Limites API :** Bien que "partiel", ce script consomme des appels API (pour le `query-all` et le `retrieve`). Sur une org très active ou avec des limites strictes, surveillez la consommation API.
3.  **Cohérence :** Ce backup est complémentaire du backup complet ("Full"). Le partiel sert souvent à capturer l'état "en cours de journée", tandis que le Full sert de référence stable nocturne.

# 3️⃣ Fonctionnement du smart backup

## 🎯 Objectif du Workflow
Ce script est conçu pour une **sauvegarde incrémentale et quasi-temps réel**. Il s'exécute **toutes les heures** et détecte uniquement les modifications effectuées depuis la dernière exécution (Delta). C'est le filet de sécurité ultime pour ne rien perdre du travail de développement en cours de journée.

---

## ⚙️ 1. Déclencheurs et Environnement

* **Fréquence Très Élevée (`cron`) :** Le backup se lance **toutes les heures**, à la 16ème minute.
    * Syntaxe : `cron: "16 */1 * * *"` (24 fois par jour).
* **Déclenchement Manuel :** Possible via `workflow_dispatch`.
* **Conteneur :** Toujours l'image standard `nanon22/sf_backup:latest`.

---

## 🛠️ 2. Configuration Requise

Bonne nouvelle : si vous avez configuré le "Full Backup" ou le "Partial Backup", **ce workflow est déjà configuré**. Il partage exactement les mêmes prérequis.

### A. Variables et Secrets (Déjà en place)
* `vars.BACKUP_USEREMAIL` & `vars.BACKUP_USERNAME`
* `secrets.SFDXAUTHURL`

### B. Fichier de Configuration (`backup_config.json`)
Il utilise le même fichier `backup_config.json` pour cibler les environnements.

```json
{
  "environments": [
    {
      "name": "DevOrg",
      "branch_name": "backup/dev",
      "message": "Smart Backup (Hourly)",
      "auth_url_variable_name": "DEV_AUTH"
    }
  ]
}
```

---

## 🔍 3. Analyse Technique : La différence "Smart"

La différence majeure avec le workflow "Partial" réside dans une subtilité de la commande Python, qui change totalement la logique de récupération.

### La commande Python (Mode Delta)

```bash
python /sf_backup.py $ACCESS_TOKEN $INSTANCE_URL
```

* **Absence d'argument :** Contrairement au backup "Partial" qui utilisait le drapeau `--query-all`, ici le script est lancé **sans arguments supplémentaires**.
* **Comportement (Source Tracking) :**
    * Ce mode exploite le **Source Tracking** de Salesforce (objets `SourceMember`).
    * Il demande à l'Org : *"Qu'est-ce qui a changé spécifiquement depuis la dernière fois que j'ai vérifié ?"*
    * Il ne génère un `package.xml` que pour ces éléments modifiés.
* **Résultat :**
    * Si personne n'a travaillé sur l'org depuis 1 heure : Le script ne récupère rien, le `commit` est vide ou ignoré.
    * Si un développeur a modifié une classe Apex : Le script ne télécharge que cette classe Apex.

### ⚠️ Points de Vigilance pour le Release Manager

1.  **Prérequis Org (Source Tracking) :** Ce workflow fonctionne idéalement sur les **Sandboxes** ou les **Scratch Orgs** où le Source Tracking est activé. Sur de vieilles Orgs de Production sans Source Tracking activé, ce mode pourrait ne pas fonctionner comme prévu ou retomber sur un comportement par défaut.
2.  **Consommation API :** Avec 24 exécutions par jour par Org, c'est le workflow le plus gourmand en appels API de login.
3.  **Conflits Git Potentiels :** Si des développeurs travaillent sur la même branche `backup/dev` (ce qui ne devrait pas arriver, cette branche doit être réservée au robot), les conflits seront fréquents vu la cadence horaire.