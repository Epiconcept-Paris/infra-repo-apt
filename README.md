# infra-repo-apt
Fabrique de *repositories* APT pour les paquets Epiconcept sur Debian/Ubuntu

## Composition
La fabrique gère la construction et la mise à jour de deux *repositories* : ````prep```` (pré-production) et ````prod```` (production), au moyen des deux scripts principaux ````prep.sh```` et ````prod.sh```` et du script auxiliaire ````update.sh````

La construction et la mise à jour nécéssitent un jeu de clés GPG qui doivent avoir été générées préalablement au moyen du script ````gpg/genkey.sh```` et de son fichier de configuration spéciale ````gpg/key.conf````. Le jeu de clés comprend une clé secrête qui reste sur le serveur et qui servira à la signature du fichier ````Release```` des repositories et une clé publique ````gpg/key.gpg```` que les clients APT importeront pour accéder à ces *repositories*. Il est à noter que la génération de clé doit se faire sur le serveur, sinon il faudrait non seulement placer la clé publique dans ````gpg/key.gpg```` mais aussi importer les clés secrètes avec ````gpg --import```` (cas non géré).

La fabrique se compose des fichiers suivants :
````
config/obsolete
config/component
config/dists
config/relconf
gpg/genkey.sh
gpg/key.conf
gpg/key.gpg
update.sh
prep.sh
prod.sh
````
et exploite l'arborescence suivante:
````
├── config
│   ├── component
│   ├── obsolete
│   ├── dists
│   ├── relconf
│   └── prodlist (après éxécution de prod.sh)
├── sources
│   ├── builds
│   │   └── *.deb
│   ├── travis
│   │   └── *.deb
│   └── epibin
│       └── *.deb
├── docroot
│   ├── prep
│   │   ├── debs
│   │   │   └── ... (paquetss)
│   │   ├── dists
│   │   │   └── ... (distributions linux)
│   │   └── key.gpg
│   └── prod
│       ├── debs
│       │   └── ... (paquets)
│       ├── dists
│       │   └── ... (distributions linux)
│       └── key.gpg
├── gpg
│   ├── genkey.sh
│   ├── key.conf
│   └── key.gpg
├── tmp
│   ├── deblist
│   ├── relconf
│   └── ...
├── prep.sh
├── prod.sh
├── update.sh
└── update.log

````
Le répertoire ````config```` est utilisé par le script auxiliaire ````update.sh ```` pour la génération (construction et mise à jour) d'un repository. L'utilisateur de la fabrique doit placer ce répertoire sur le serveur.

Le répertoire ````sources```` contient les paquets Debian d'origine, rangés selon leurs différentes provenances (serveur de build, Travis CI et paquets binaires Epiconcept). Il est de la responsabilité de l'utilisateur de la fabrique de peupler ces répertoires avec les fichiers ````.deb```` de son choix.

Le répertoire ````docroot```` est destiné comme son nom l'indique à être la racine du serveur web de paquets. Il contient les répertoires ````prep```` et ````prod```` pour chacun des deux *repositories* de pré-production et de production. La raison d'être de la fabrique étant de générer et mettre à jour ce répertoire et ses contenus, l'utilisateur n'a pas à y intervenir ni même à créer le répertoire ````docroot````.

Le répertoire ````gpg```` contient la clé publique ````key.cfg````, le script de génération et surtour le fichier de configuration ````key.conf```` qui contient la passphrase du jeu de clés GPG. **Après avoir** placé ce répertoire sur le serveur et **généré le jeu de clés GPG, il est donc souhaitable de sauvegarder ailleurs et de supprimer le fichier ````gpg/key.conf````**.

Le répertoire ````tmp```` est créé si nécessaire et doit normalement être vide après l'exécution des scripts.

Les scripts ````prep.sh````, ````prod.sh```` et ````update.sh```` constituent la fabrique proprement dite, dons l'utilisation est détaillée ci-après. Le script ````update.sh```` produit un log ````update.log```` signalant la date des updates et le détail de leur traitement (surtout les anomalies).


## Utilisation
### Préalable : génération du jeu de clés GPG
Avant de pouvoir utiliser les scripts prep.php et prod.php, il faut générer le jeu de clés GPG de la façon suivante :
````
cd gpg
./genkey.sh
````
puis lancer sur un autre terminal une commande pour générer l'entropie nécessaire à GPG (un exemple de commande est affiché).

Quand le script se termine, la clé publique résultante se trouve dans ````gpg/key.gpg```` **et les clés secrètes dans le trousseau GPG** que l'on peut afficher pour contrôle avec la commande :
````
gpg -k
````

### Gestion du *repository* de pré-production ````prep````
Elle se fait par le script ````prep.sh````. Trois commandes sont disponibles :

1. Mise à jour du *repository* ````prep```` après la modification du repértoire ````sources/```` :
````
./prep.sh update
````
Le script ````prep.sh```` peuple d'abord le répertoire ````debs```` :
````
debs
├── any
│   ├── all
│   │   └── *.deb
│   └── amd64
│       └── *.deb
├── deb8
│   └── amd64
│       └── *.deb
└── deb9
    └── amd64
        └── *.deb
````

en normalisant au passage les noms deq paquet sous la forme :
````
<nom-paquet>_<version-paquet>_<archi-paquet>.deb
````
en extrayant \<nom-paquet>, \<version-paquet> et \<archi-paquet> de chaque paquet lui-même et en éliminant les paquets obsolètes déclarés dans ````config/obsolete````.

Puis ````prep.sh```` invoque le au script auxiliaire auxiliaire ````update.sh```` qui peuple le répertoire ````dists```` avec des répertoires correspondant chacun à une distribution spécifiée dans le fichier ````config/dists```` et ayant la structure :
````
<nom-distrib>
├── main
│   ├── binary-all
│   │   ├── Packages.gz
│   │   └── Packages
│   └── binary-amd64
│       ├── Packages.gz
│       └── Packages
├── Release
└── Release.gpg
````
le deuxième champ de chaque ligne du fichier ````config/dist```` indique l'étiquette à rechercher dans la version de chaque paquet pour que, si elle s'y trouve, ce paquet ne soit inclus que dans la distribution indiquée dans le premier champ. Par exemple, les binaires php comprenant l'étiquette ````deb8```` ne sont inclus que dans les distributions de ````config/dists```` dont le deuxième champ est ````deb8````.

Les architectures ````all```` et ````amd64```` sont elles extraites automatiquement des packages eux-même. Si l'on introduit dans ````sources```` des paquets pour l'architecture ````armh````, celle ci apparaitra automatiquement dans son répertoire ````binary-armh```` dans les répertoires des distributions de ````dist````.

Il est aussi possible de changer le nom du composant ````main```` en modifiant le contenu du fichier ````config/component````.

Enfin, la commande ````prep.sh list```` supprime automatiquement des *repositories* ````prep```` et ````prod```` les paquets qui auraient été supprimés de l'arborescence ````sources/```` depuis la dernière invocation de ````prep.sh list````.

2. Liste des fichiers de pré-production pas encore en production :
````
./prep.sh list
````
Pour obtenir la liste de tous les paquets du *repository* ````prep````, on peut employer au choix :
````
find docroot/prep/debs -type f -name '*.deb'

(cd docroot/prep/debs; find * -type f -name *.deb | sed 's;.*/;;')
````

3. Liste des noms de paquets (sans version, au sens apt / dpkg) de pré-production comportant plus d'une version :
````
./prep.sh ver
````
et liste des différentes versions d'un paquet :
````
./prep.sh ver <nom-dpkg-paquet>
````
ou
````
./prep.sh ver <nom-fichier-paquet>
````


### Gestion du *repository* de production ````prod````
Elle se fait par le script ````prod.sh````. Trois commandes sont également disponibles :

1. Ajout au *repository* ````prod```` de paquets du *repository* ````prep```` :
````
./prod.sh add <nom-fichier-paquet> [ <nom-fichier-paquet> ... ]
````

2. Suppression de paquets du *repository* ````prod```` :
````
./prod.sh del <nom-fichier-paquet> [ <nom-fichier-paquet> ... ]
````

3. Liste des noms de paquets (sans version, au sens apt / dpkg) de production comportant plus d'une version :
````
./prep.sh ver
````
et liste des différentes versions d'un paquet :
````
./prep.sh ver <nom-dpkg-paquet>
````
ou
````
./prep.sh ver <nom-fichier-paquet>
````
(de manière identique à ````prep.sh ver ...````).

## Sauvegarde

Pour pourvoir reproduire le contenu de la fabrique, il faut sauvegarder le répertoire ````config/```` et l'arborescence ````sources/````.
Il faut également sauvegarder le jeu de clés GPG.
