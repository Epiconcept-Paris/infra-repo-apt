# infra-repo-apt
Fabrique de dépots APT pour les paquets Epiconcept sur Debian/Ubuntu

## Composition
La fabrique gère la construction et la mise à jour de deux dépots APT : ````prep```` (pré-production) et ````prod```` (production), au moyen des deux scripts principaux ````prep.sh```` et ````prod.sh```` et du script auxiliaire ````update.sh````, destinés à être installés sur un serveur de dépots.

La construction et la mise à jour des dépots APT nécéssitent un jeu de clés GPG qui doivent avoir été générées préalablement au moyen du script ````gpg/genkey.sh````, préférablement ailleurs que sur le serveur de dépots APT.

La fabrique se compose des fichiers suivants :
````
config/obsolete
config/component
config/dists
config/relconf
config/prodlist	(généré par prod.sh)
gpg/genkey.sh
gpg/key.conf
gpg/master.gpg	(généré par gpg/genkey.sh)
gpg/signing.gpg	(généré par gpg/genkey.sh)
gpg/key.gpg	(généré par gpg/genkey.sh)
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
│   └── prodlist    (après éxécution de prod.sh)
│
├── sources         (exemple d'arborescence)
│   ├── builds
│   │   └── *.deb
│   ├── travis
│   │   └── *.deb
│   └── epibin
│       └── *.deb
├── docroot
│   ├── prep
│   │   ├── debs
│   │   │   └── ... (paquets)
│   │   ├── dists
│   │   │   └── ... (distributions Debian/Ubuntu)
│   │   └── key.gpg
│   └── prod
│       ├── debs
│       │   └── ... (paquets)
│       ├── dists
│       │   └── ... (distributions Debian/Ubuntu)
│       └── key.gpg
├── gpg
│   ├── genkey.sh
│   ├── key.conf
│   ├── master.gpg
│   ├── signing.gpg
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
Le répertoire ````config```` est utilisé par le script auxiliaire ````update.sh ```` pour la génération (construction et mise à jour) d'un dépot.
L'utilisateur de la fabrique doit placer ce répertoire sur le serveur.

Le répertoire ````sources```` contient les paquets Debian d'origine, rangés éventuellement selon leurs différentes provenances (serveur de build, Travis CI et paquets binaires Epiconcept).
Il est de la responsabilité de l'utilisateur de la fabrique de fournir le répertoire ````sources```` peuplé avec les répertoires et les fichiers ````.deb```` de son choix.

Le répertoire ````docroot```` est destiné comme son nom l'indique à être la racine du serveur web de paquets.
Il contient les répertoires ````prep```` et ````prod````, pour chacun des deux dépots de pré-production et de production.
La raison d'être de la fabrique étant de générer et mettre à jour ce répertoire et ses contenus, l'utilisateur n'a pas à y intervenir ni même à créer le répertoire ````docroot````.

Le répertoire ````gpg```` contient le script ````genkey.sh```` de génération du jeu de clés GPG et surtout le fichier de configuration ````key.conf```` qui contient la passphrase du jeu de clés GPG.
Lors de l'exécution de ````genkey.sh````, trois fichiers sont créés : le jeu complet ````master.gpg````, la sous-clé secrète de signature ````signing.gpg```` et la clé publique ````key.gpg````.

Le répertoire ````tmp```` est créé si nécessaire et doit normalement être vide après l'exécution des scripts.

Les scripts ````prep.sh````, ````prod.sh```` et ````update.sh```` constituent la fabrique proprement dite, dont l'utilisation est détaillée ci-après. Le script ````update.sh```` produit un log ````update.log```` signalant la date des updates et le détail de leur traitement (surtout les anomalies).


## Utilisation
### Préalable : génération du jeu de clés GPG
Le script ````update.sh```` utilisant les commandes ````dpkg-scanpackages```` et ````apt-ftparchive````, il faut avoir installé respectivement les packages Debian ````dpkg-deb```` et ````apt-utils```` pour que le script fonctionne correctement.

Avant de pouvoir utiliser les scripts ````prep.php```` et ````prod.php````, il faut d'abord générer un jeu de clés GPG. Cette génération se fait par le script ````gpg/genkey.sh````, qui utilise le fichier de configuration ````gpg/key.conf````.

Avant la génération proprement dite (de préférence ailleurs que sur le serveur final de dépots APT), il convient de passer en revue et de modifier s'il y a lieu les 4 dernières lignes du fichier ````key.conf```` :

- Name-Real: Epiconcept Infrastructure Hébergement
- Name-Email: infra@epiconcept.fr
- Expire-Date: 3y
- Passphrase: And there were gardens bright with sinuous rills
 (tirée du poème "Xanadu" de Coleridge)

par exemple avec les commandes suivantes :

````
cd gpg
vi key.conf
./genkey.sh
````
Il est nécessaire de "générer de l'entropie" pour GPG en tapant sur un autre terminal une commande du type de celle affichée par le script ou en installant préalablement le package Debian 'rng-tools'.

Quand le script se termine, le répertoire contient trois clés :
- une clé principale ````master.gpg````, qu'il est impératif de sauvergarder et qu'il vaut mieux ensuite supprimer, surtout si elle est générée sur le serveur de dépots.
- une sous-clé secrète ````signing.gpg```` qui doit être installée sur le serveur de dépots APT par:
````
gpg --import signing.gpg
````
et qui servira à la signature des fichiers Release des distributions dans les dépots.
- une clé publique ````key.gpg```` qui sera intégrée au dépots APT et installée sur les clients APT par ````apt-key add````.

Sur le serveur de dépots, après installation de ````signing.gpg````, seuls les fichiers ````key.conf```` et ````key.gpg```` sont nécessaires dans le répertoire ````gpg/````.


### Gestion du dépot de pré-production ````prep````
Elle se fait par le script ````prep.sh````. Trois commandes sont disponibles :

1. Mise à jour du dépot ````prep```` après la modification du repértoire ````sources/```` :
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

en normalisant au passage les noms des paquets sous la forme :
````
<nom-paquet>_<version-paquet>_<archi-paquet>.deb
````
en extrayant \<nom-paquet>, \<version-paquet> et \<archi-paquet> de chaque paquet lui-même et en éliminant les paquets obsolètes déclarés dans ````config/obsolete````.

Puis ````prep.sh```` invoque le script auxiliaire ````update.sh```` qui peuple le répertoire ````dists```` avec des répertoires correspondant chacun à une distribution spécifiée dans le fichier ````config/dists```` et ayant la structure :
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

Les architectures ````all```` et ````amd64```` sont elles extraites automatiquement des packages eux-mêmes.
Si l'on introduit dans ````sources```` des paquets pour l'architecture ````armh````, celle ci apparaitra automatiquement dans son répertoire ````binary-armh```` dans les répertoires des distributions de ````dist````.

Il est aussi possible de changer le nom du composant ````main```` en modifiant le contenu du fichier ````config/component````.

Enfin, la commande ````prep.sh update```` supprime automatiquement des dépots ````prep```` et ````prod```` les paquets qui auraient été supprimés de l'arborescence ````sources/```` depuis la dernière invocation de ````prep.sh list````.

2. Liste des fichiers de pré-production pas encore en production :
````
./prep.sh list
````
Pour obtenir la liste de tous les paquets du dépot ````prep````, on peut employer par exemple :
````
find docroot/prep/debs -type f -name '*.deb'
````
ou encore
````
(cd docroot/prep/debs; find * -type f -name *.deb | sed 's;.*/;;')
````
ou un mélange de ces deux commandes.

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


### Gestion du dépot de production ````prod````
Elle se fait par le script ````prod.sh````. Trois commandes sont également disponibles :

1. Ajout au dépot ````prod```` de paquets du dépot ````prep```` :
````
./prod.sh add <nom-fichier-paquet> [ <nom-fichier-paquet> ... ]
````

2. Suppression de paquets du dépot ````prod```` :
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

## Sauvegarde et restauration

Pour pouvoir reproduire le contenu de la fabrique, il faut sauvegarder le répertoire ````config/````, le répertoire ````gpg/```` (si ce n'est déjà fait) et l'arborescence ````sources/````.

Après avoir restauré ces éléments sur le serveur désiré, il suffit d'exécuter :
````
gpg --import gpg/signing.gpg
rm gpg/signing.gpg
./prep.sh update
./prod.sh add `cat config/prodlist`
````
