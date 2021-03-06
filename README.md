# infra-repo-apt
Fabrique de dépôts APT pour les paquets Epiconcept sur Debian/Ubuntu


## 1 Présentation

La fabrique gère la construction et la mise à jour de deux dépôts APT : `prep` (pré-production) et `prod` (production), au moyen des deux scripts principaux `prep.sh` et `prod.sh` et du script auxiliaire `update.sh`, destinés à être installés sur un serveur de dépôts.

La construction et la mise à jour des dépôts APT nécéssitent un jeu de clés GPG qui doivent avoir été générées préalablement au moyen du script `gpg/genkey.sh`, préférablement ailleurs que sur le serveur de dépôts APT.

La fabrique se compose des fichiers suivants (dans le répertoire `site` de ce dépôt git) :
```
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
```
et elle exploite l'arborescence suivante:
```
├── config
│   ├── component
│   ├── obsolete
│   ├── dists
│   ├── relconf
│   └── prodlist    (généré par prod.sh)
│
├── gpg
│   ├── genkey.sh
│   ├── key.conf
│   ├── master.gpg  (généré par genkey.sh)
│   ├── signing.gpg (généré par genkey.sh)
│   └── key.gpg	    (généré par genkey.sh)
│
├── prep.sh
├── prod.sh
├── update.sh
│
├── sources	    (exemple d'arborescence, à fournir)
│   ├── builds
│   │   └── *.deb
│   ├── travis
│   │   └── *.deb
│   └── epibin
│       └── *.deb
│
├── docroot	    (généré par les scripts)
│   │
│   ├── prep	    (LE dépôt de pré-production)
│   │   ├── debs
│   │   │   └── ... (paquets)
│   │   ├── dists
│   │   │   └── ... (distributions Debian/Ubuntu)
│   │   └── key.gpg
│   │
│   └── prod	    (LE dépôt de production)
│       ├── debs
│       │   └── ... (paquets)
│       ├── dists
│       │   └── ... (distributions Debian/Ubuntu)
│       └── key.gpg
│
├── tmp		    (généré par les scripts)
│   └── ...
│
└── update.log	    (généré par les scripts)

```
Le répertoire `config` est utilisé surtout par le script auxiliaire `update.sh` (qui n'est pas destiné à être appelé directement) pour la génération (construction et mise à jour) d'un dépôt.
L'utilisateur de la fabrique doit placer ce répertoire sur le serveur.

Le répertoire `gpg` contient le script `genkey.sh` de génération du jeu de clés GPG et surtout le fichier de configuration `key.conf` qui contient la passphrase du jeu de clés GPG.
Lors de l'exécution de `genkey.sh`, trois fichiers sont créés : le jeu complet `master.gpg`, la sous-clé secrète de signature `signing.gpg` et la clé publique `key.gpg`.
Une partie du répertoire `gpg`: `key.conf` et `key.gpg` doit se trouver sur le serveur de dépôts.
La clé `signing.gpg` doit aussi y être installée par `gpg --import signing.gpg`.

Les scripts `prep.sh`, `prod.sh` et `update.sh` constituent la fabrique proprement dite, dont l'utilisation est détaillée dans une section ci-dessous.
Ils doivent donc être placés à coté (dans le même sur-répertoire) que `config/`, `gpg/` et `sources/` décrit ci-après.

Le répertoire `sources` contient les paquets Debian d'origine, rangés éventuellement selon leurs différentes provenances (serveur de build, Travis CI et paquets binaires Epiconcept).
Il est de la responsabilité de l'utilisateur de la fabrique de fournir le répertoire `sources` peuplé avec les répertoires et les fichiers `.deb` de son choix.

Le répertoire `docroot` est destiné, comme son nom l'indique, à être la racine du serveur web de paquets.
Il contient les répertoires `prep` et `prod`, pour chacun des deux dépôts de pré-production et de production.
La raison d'être de la fabrique étant de générer et de mettre à jour ce répertoire et ses contenus, l'utilisateur n'a pas à y intervenir ni même à créer le répertoire `docroot`.

Le répertoire `tmp` est créé si nécessaire et doit normalement être vide après l'exécution des scripts. L'utilisateur n'a donc pas à s'en préoccuper.

Enfin, le script `update.sh` produit un log `update.log` qui signale la date des updates et le détail de leur traitement (surtout les anomalies).


## 2 Installation

### 2.1 Installation des paquets prérequis

Le script `update.sh` utilisant les commandes `dpkg-scanpackages` et `apt-ftparchive`, il faut avoir respectivement installé sur le serveur de dépôts les packages Debian
 - dpkg-dev
 - apt-utils

pour que les scripts fonctionnent correctement.

### 2.2 Génération du jeu de clés GPG

Avant de pouvoir utiliser les scripts `prep.sh` et `prod.sh`, il faut d'abord générer un jeu de clés GPG. Cette génération se fait par le script `gpg/genkey.sh`, qui utilise le fichier de configuration `gpg/key.conf`.

Avant la génération proprement dite (de préférence ailleurs que sur le serveur final de dépôts APT), il convient de passer en revue et de modifier s'il y a lieu les 4 dernières lignes du fichier `key.conf` :

- Name-Real: Epiconcept Infrastructure Hébergement
- Name-Email: infra@epiconcept.fr
- Expire-Date: 3y
- Passphrase: And there were gardens bright with sinuous rills
	&nbsp; &nbsp; *(tirée du poème "Xanadu" de Coleridge)*

**Il faut AU MINIMUM changer cette passphrase, du fait qu'elle est ici exposée publiquement**,

avant de générer le jeu de clés, par exemple avec les commandes suivantes :

```
cd gpg
vi key.conf
./genkey.sh
```
Si le script genkey.sh semble alors se bloquer, c'est qu'il attend de "l'entropie système", qu'il est possible de lui fournir :
- en tapant sur un autre terminal une commande du type de celle affichée par `genkey.sh`
- ou en installant préalablement le package Debian 'rng-tools' sur le système de génération des clés

Quand le script se termine, le répertoire contient trois clés :
- une clé principale `master.gpg`, qu'il est impératif de sauvergarder et qu'il vaut mieux ensuite supprimer, surtout si elle est générée sur le serveur de dépôts
- une sous-clé secrète `signing.gpg`, qui servira à la signature des fichiers `Release` des distributions dans les dépôts et qui doit être installée sur le serveur de dépôts APT par : `gpg --import signing.gpg`, en tant qu'utilisateur qui exécutera les scripts `prep.sh` et `prod.sh`
- une clé publique `key.gpg` qui sera intégrée aux dépôts APT et installée sur les clients APT par : `apt-key add key.gpg`

Sur le serveur de dépôts, après installation de `signing.gpg`, seuls les fichiers `key.conf` et `key.gpg` sont nécessaires dans le répertoire `gpg`.

Enfin, si ce serveur de dépôts est bien, comme recommandé, différent de celui où a été généré le jeu de clés GPG, il faut placer à la fin du fichier `$HOME/.gnupg/gpg.conf` de l'utilisateur qui exécutera les scripts les 2 lignes suivantes :
```
cert-digest-algo SHA256
digest-algo SHA256
```

### 2.3 Copie des fichiers

Il faut copier dans un même répertoire sur le serveur de dépôts :
- le répertoire `site/config` de ce dépôt git
- les fichiers `key.conf`, `key.gpg` et `signing.gpg` (à supprimer après import) de `site/gpg/`
- les scripts `prep.sh`, `prod.sh` et `update.sh` de `site/`

Il faut créer et peupler de paquets `.deb` le répertoire `sources`.


## 3 Utilisation

### 3.1 Gestion du dépôt de pré-production `prep`

Elle se fait par le script `prep.sh`. Trois commandes sont disponibles :

#### 1) Mise à jour du dépôt `prep` après la modification du répertoire `sources` :
```
./prep.sh update
```
Le script `prep.sh` peuple d'abord le répertoire `docroot/prep/debs` (créé au besoin) :
```
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
```

en normalisant au passage les noms des paquets sous la forme :
```
<nom-paquet>_<version-paquet>_<archi-paquet>.deb
```
en extrayant \<nom-paquet>, \<version-paquet> et \<archi-paquet> de chaque paquet lui-même et en éliminant les paquets obsolètes déclarés dans `config/obsolete`.
Les paquets dont le nom dans `sources/` n'est pas normalisé sont signalés, avec leur nom normalisé, dans `update.log`.

Puis `prep.sh` invoque le script auxiliaire `update.sh` qui peuple le répertoire `docroot/prep/dists` selon le contenu du fichier `config/dists` dont voici un extrait :
```
...
saucy	deb7
jessie	deb8
trusty	deb8
utopic	deb8
vivid	deb8
wily	deb8
stretch	deb9
xenial	deb9
...
```
Pour le premier champ de chaque ligne du fichier `config/dists`, `update.sh` crée un répertoire de distribution portant ce nom et ayant la structure :
```
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
```
Le deuxième champ de chaque ligne du fichier `config/dist` indique l'étiquette (chaine de caractères) à rechercher dans la version de chaque paquet pour que, si elle s'y trouve, ce paquet ne soit inclus que dans la distribution indiquée dans le premier champ.
Par exemple, les binaires PHP comprenant l'étiquette `deb8` ne sont inclus que dans les distributions de `config/dists` dont le deuxième champ est `deb8`.

Les architectures `all` et `amd64` qui apparaissent en suffixes des répertoires `binary-all` et `binary-amd64` sont, elles, extraites automatiquement des packages eux-mêmes.
Si l'on introduisait par exemple dans `sources` des paquets pour l'architecture `armh`, celle ci apparaitrait automatiquement dans un répertoire `binary-armh` de l'arborescence de chaque distribution de `dist`, à condition toutefois que la sélection ci-dessus par le deuxième champ de `config/dists` le permette.

Il est aussi possible de changer le nom du composant `main` en modifiant le contenu du fichier `config/component`.

Enfin, la commande `prep.sh update` supprime automatiquement des dépôts `prep` et `prod` les paquets qui auraient été supprimés de l'arborescence `sources/` depuis la dernière invocation de `prep.sh update`.

#### 2) Liste des fichiers de pré-production pas encore en production :
```
./prep.sh list
```
#### 3a) Liste des différentes versions d'un paquet de pré-production :
```
./prep.sh ver <nom-fichier-paquet>
```
ou
```
./prep.sh ver <nom-dpkg-paquet>
```
Le nom-dpkg d'un paquet est le nom du paquet au sens dpkg, c'est à dire jusqu'au premier caractère '_'.

#### 3b) Liste des *noms-dpkg* de paquets de pré-production comportant plus d'une version :
```
./prep.sh ver
```

Pour obtenir par ailleurs la liste de tous les paquets du dépôt `prep`, on peut employer par exemple :
```
find docroot/prep/debs -type f -name '*.deb'
```
ou encore
```
(cd docroot/prep/debs; find * -type f -name *.deb | sed 's;.*/;;')
```
ou un mélange de ces deux commandes.


### 3.2 Gestion du dépôt de production `prod`

Elle se fait par le script `prod.sh`. Trois commandes sont également disponibles :

#### 1) Ajout au dépôt `prod` de paquets du dépôt `prep` :
```
./prod.sh add <nom-fichier-paquet> [ <nom-fichier-paquet> ... ]
```

#### 2) Suppression de paquets du dépôt `prod` :
```
./prod.sh del <nom-fichier-paquet> [ <nom-fichier-paquet> ... ]
```

#### 3a) Liste des différentes versions d'un paquet de production :
```
./prod.sh ver <nom-fichier-paquet>
```
ou
```
./prod.sh ver <nom-dpkg-paquet>
```
Le nom-dpkg d'un paquet est le nom du paquet au sens dpkg, c'est à dire jusqu'au premier caractère '_'.

#### 3b) Liste des noms-dpkg de paquets de production comportant plus d'une version :
```
./prod.sh ver
```
(de manière identique à `prep.sh ver ...`).


## 4 Sauvegarde, restauration et "fsck"

### 4.1 Sauvegarde

Pour pouvoir reproduire le contenu de la fabrique, il faut sauvegarder le répertoire `config` et l'arborescence `sources/`.

Le répertoire `gpg` a normalement été sauvegardé en entier après la génération du jeu de clés GPG.

### 4.2 Restauration

Après avoir installé la clé GPG de signature par :
```
gpg --import gpg/signing.gpg
rm gpg/signing.gpg
```
et avoir restauré les éléments (sauvegardés comme indiqué ci-dessus) sur le serveur désiré, il suffit d'exécuter :
```
./prep.sh update
./prod.sh add `cat config/prodlist`
```
pour restaurer complètement les dépôts APT.

### 4.3 Refection des dépôts APT (comme fsck pour les systèmes de fichier)

La fabrique de dépôts utilise des liens UNIX durs (et non symboliques) pour relier entre eux les fichiers de `sources/`, de `docroot/prep/debs/` et de `docroot/prod/debs/`.
Pour diverses raisons, il peut arriver que ces liens soient anormalement cassés.
Les scripts de la fabrique ne fonctionneraient alors plus correctement.
Mais la méthode utilisée pour la restauration s'applique. Il suffit de faire :
```
rm -r docroot
./prep.sh update
./prod.sh add `cat config/prodlist`
```
pour rétablir le fonctionnement normal.


## 5 Image docker de test

Ce dépôt git contient également un répertoire `test` permettant de créer une image docker sous Debian 'stretch' de tests de `apt-get`.

Pour créer l'image, lancer la commande `test/bake`, qui affiche à la fin la commande d'invocation du conteneur de l'image. Cette commande est également copiée dans `logs/run-${DebVer:-stretch}.sh`.
Il est possible de créer une image docker sous une autre version de Debian par la variable d'environnement **DebVer**, par exemple : `DebVer=jessie test/bake` (attention, la validité de la version Debian n'est pas vérifiée, mais `test/bake` s'arrêtera en cas d'erreur de build de l'image docker).

Le conteneur partage le répertoire `test/share`, vu en interne comme `/opt/share`, et lance automatiquement le script `test/cfg` par le biais d'un hardlink dans `test/share`.
Ce script utilise par défaut les dépôts Epiconcept `https://apt.epiconcept.fr/prep (ou /prod)`, mais il est possible de tester le dépôt local de la façon suivante :
```
dpkg -l apache2 >/dev/null || sudo apt-get install apache2
sudo ln -s `realpath site/docroot` /var/www/html/apt
>test/share/local
test/bake
```
Enfin ce dépôt git contient aussi le script `test/bin/debinfo` qui n'est qu'une étude, un *proof of concept* pour la fabrique de dépôts APT, qui n'est utilisé que dans l'image de test pour lister les packages à la fin de `test/cfg`.

## 6 Déploiement manuel

* Import de la clé (l'auth n'est pas nécessaire au sein de l'infra epiconcept)
```console
curl -u username:password https://apt.epiconcept.fr/prep/key.gpg | sudo apt-key add -
```

* Configuration du repository dans /etc/apt/sources.list.d/epiconcept.list (prendre une seule ligne, en fonction de la version et de la distribution utilisée)
```
deb [arch=amd64,all] https://apt.epiconcept.fr/prep/ <release> main
```
ce qui peut se faire ainsi
```
echo "deb [arch=amd64,all] https://apt.epiconcept.fr/prep/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/epiconcept.list
```
Il faut (hors de notre infra) ajouter l'authentification (en Debian 9 j'ai dû mettre dans /etc/apt/auth.conf pour que ça marche, il faut peut être inclure auth.conf.d ?)
```
echo -e "machine apt.epiconcept.fr\nlogin <user>\npassword <mdp>" | tee /etc/apt/auth.conf.d/apt.epiconcept.fr.conf
```
