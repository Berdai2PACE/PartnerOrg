# retrieve_all_metadata

Script permettant de récupérer l'intégralité de la métadonnée d'une org Salesforce en local.

## Prérequis

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- Python 3

## Utilisation

### 1. Se connecter à l'org

```bash
sf org login web -a <alias>
```

### 2. Lancer le script

```bash
./scripts/retrieve_all_metadata/retrieve_all_metadata.sh -a <alias>
```

#### Options

| Option | Description | Défaut |
|--------|-------------|--------|
| `-a`   | Alias de l'org (obligatoire) | — |
| `-o`   | Dossier de sortie | `./<alias>` |

#### Exemples

```bash
# Backup dans ./<alias>/force-app/
./scripts/retrieve_all_metadata/retrieve_all_metadata.sh -a PROD

# Backup dans un dossier spécifique
./scripts/retrieve_all_metadata/retrieve_all_metadata.sh -a PROD -o /tmp/backup-prod
```

## Structure de sortie

```
<alias>/
├── sfdx-project.json       # Projet SF généré automatiquement
├── package.xml             # Manifest complet de l'org
├── SanitizedPackages/      # Manifest découpé en chunks < 10 000 membres
│   ├── package1.xml
│   ├── package2.xml
│   └── ...
└── force-app/              # Métadonnée récupérée
    └── main/
        └── default/
            └── ...
```

## Fonctionnement

1. Vérifie que l'org est bien connectée via son alias
2. Génère le `package.xml` complet depuis l'org
3. Découpe le manifest en chunks de 10 000 membres max (limite API Salesforce)
4. Récupère la métadonnée en parallèle (5 workers) dans `force-app/`
