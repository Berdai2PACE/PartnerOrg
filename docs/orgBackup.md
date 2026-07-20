# 🗄️ Mécanisme de Sauvegarde (Backup)

  Chaque environnement Salesforce est entièrement représenté dans des **branches de sauvegarde** :

  ```
  backup/QA, backup/SIT, backup/UAT, backup/PROD
  ```

  Ces branches sont alimentées automatiquement :

  - Elles contiennent **l’état réel des organisations Salesforce**.  
  - Toute différence entre les branches *release/* et *backup/* expose :
    - une modification directe dans l’org,
    - ou un changement hors du processus standard CICD.

  ---

  ## 🔁 Workflows de Sauvegarde

  Il existe **trois types de backups**, chacun exécuté par GitHub Actions :

  ### 🔹 Full Backup
  - Synchronise **toutes** les métadonnées de l'org.
  - Déclenché :
    - lors de la **création de la branche**,
    - puis **1 fois/jour** (vers minuit idéalement).

  ### 🔹 Partial Backup
  - Synchronise uniquement les métadonnées définies dans `config_backup`.
  - Déclenché **3 à 4 fois par jour**.

  ### 🔹 Smart Backup
  - Synchronise **uniquement les métadonnées modifiées ou créées** dans la période définie.
  - Ne traite que les types listés dans `config_backup`.
  - Déclenché **chaque heure**.