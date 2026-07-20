# 🚀 Configuration du Répertoire TMA Salesforce Release

Ce guide détaille les étapes pour initialiser un nouveau dépôt de projet Salesforce TMA (Tierce Maintenance Applicative) basé sur le template **2paceRepoTemplate** et pour configurer l'intégration continue (CI) via GitHub Actions et les plugins SFDX Hardis.

---

## 1. Initialisation du Répertoire GitHub

Suivez ces étapes pour créer le dépôt à partir du modèle :

1.  **Création du Dépôt :**
    * Rendez-vous sur le template : [**2paceRepoTemplate**](https://github.com/2Pace/2paceRepoTemplate)
    * Cliquez sur le bouton **"Use this template"** pour créer un nouveau dépôt.
    * 
2.  **Configuration du Dépôt :**
    * Assurez-vous de **sélectionner `Include all branches`**.
    * Nommez le nouveau dépôt selon la convention : `TMA-#CLIENT#-ReleaseSalesforce`.
    * 

---

## 2. Configuration du PAT (Personal Access Token) pour la CI

Un **Personal Access Token (PAT)** à granularité fine est nécessaire pour permettre à l'utilisateur de l'intégration continue d'accéder au dépôt.

1.  **Génération du PAT :**
    * Accédez à [**Settings > Developer Settings > Personal access token > Fine-grained token**](https://github.com/settings/tokens?type=beta).
    * Définissez une **date d'expiration** lointaine (1 an maximum).
    * 
2.  **Configuration des Ressources :**
    * Sous `Resource owner`, sélectionnez **2PACE**.
    * Choisissez le dépôt du projet récemment créé.
    * 
3.  **Définition des Permissions :**
    * Dans la section `Repository permissions`, donnez les droits en **Lecture et Écriture** sur le `Contents` du dépôt.
    * 
4.  **Enregistrement du Token :**
    * **Copiez le token généré immédiatement.** Il ne sera plus affiché après cette étape.
    * 
    * ⚠️ **Note :** Si vous n'avez pas les droits suffisants pour configurer cela, contactez un administrateur de l'espace GitHub **2PACE**.

---

## 3. Ajout du PAT en Secret GitHub

Le token copié doit être stocké comme un secret dans le dépôt pour être utilisé par GitHub Actions.

1.  **Navigation vers les Secrets :**
    * Dans votre répertoire, allez à **Settings > Secrets and variables > Actions**.
    * Cliquez sur **"New Repository Secret"**.
2.  **Création du Secret :**
    * Nom du Secret : `GH_TOKEN`
    * Valeur du Secret : le **token PAT** copié précédemment.
    * 

---

## 4. Configuration de l'Authentification CI SFDX Hardis (VS Code)

Ces étapes configurent les informations d'identification de l'organisation Salesforce pour l'intégration continue en utilisant l'extension SFDX Hardis dans VS Code.

1.  **Installation/Mise à Jour des Plugins Hardis :**
    * **a) Installation :** Dans VS Code, allez dans **Extensions**, cherchez `SFDX Hardis` et cliquez sur **Install**.
    * 
    * **b) Mise à jour :** Si les plugins sont déjà installés, suivez la [procédure de mise à jour des plugins ](https://www.notion.so/Mise-jour-des-plugins-c7f374025aaa442594965b8e2f8e036f?pvs=21).
2.  **Configuration de l'Authentification CI :**
    * Dans VS Code, exécutez la commande `sfdx hardis:Configuration: Configure org CI authentication`.
    * Choisissez l'organisation Salesforce appropriée dans la fenêtre contextuelle.
    * 
3.  **Paramétrage de la CI :**
    * Définissez le **nom de la branche**, le **nom d'utilisateur** et l'**URL de l'org**.
    * Acceptez de créer l'application connectée (`Connected App`) et nommez-la `CI_2PACE`.
    * 
4.  **Récupération des Valeurs :**
    * Récupérez la valeur de la configuration qui s'affiche dans le terminal VS Code.
    * 
5.  **Création des Secrets SFDX :**
    * Créez les deux secrets suivants dans les **Secrets GitHub** de votre dépôt (à côté de `GH_TOKEN`):
        * `SFDX_HARDIS_CLIENT_ID`
        * `SFDX_HARDIS_SECRET`
    * 
6.  **Finalisation de la Configuration :**
    * Définissez les informations de l'application connectée (nom, adresse e-mail, profil de l'utilisateur CI) dans Salesforce.
    * **Commitez** la configuration pour la branche dans la branche pertinente.
    * Vous pouvez voir la validation/le déploiement via ce lien : [Vidéo de démonstration](https://drive.google.com/file/d/1qBn7CxGBgC6oK4bdTXktEMlHk9EtZ9M4/view).

---

## 5. Configuration de l'URL d'Authentification SFDX (Alternative ou Complément)

Cette méthode permet d'utiliser l'URL d'authentification complète de SFDX (méthode de connexion JWT ou Web Server Flow).

1.  **Génération du Fichier d'Authentification :**
    * Dans le terminal de VS Code, exécutez la commande suivante, en remplaçant `my-org` par l'alias de votre organisation :

    ```bash
    sf org display --target-org my-org --verbose --json > authFile.json
    ```

2.  **Récupération de l'URL :**
    * Ouvrez le fichier `authFile.json` et copiez la valeur du champ `sfdxAuthUrl`.

3.  **Ajout du Secret `SFDXAUTHURL` :**
    * Copiez cette valeur dans un nouveau **Secret GitHub** de votre dépôt :
        * Nom du Secret : `SFDXAUTHURL`
        * Valeur du Secret : la valeur de `sfdxAuthUrl` copiée.
    *