# Planning

## État actuel

* un repository unique, avec des fichiers Packages copiés pour chaque version de Debian ou Ubuntu (voir resources/existant/apt_deploy.sh pour la génération)
  * aucune séparation par version de distro
  * aucune séparation prod/preprod
  * on ne met à disposition que la dernière version de chaque paquet
  * le repo n'est pas signé, ce qui implique de contourner les avertissements d'APT
  * de mémoire, il y a un type de repo "simple", trivial, et un "full". C'est le premier qui a été mis en place.

* les fichiers packages sont disponibles à cette url: http://files.epiconcept.fr/repositories_apt/epiconcept/dists/bionic/main/binary-i386/Packages
* deux sources de paquets
  * un serveur de build interne
  * des builds automatisés Travis CI qui sont déposés en SCP dans un dossier, et recopiés par apt_deploy.sh
  * les builds PHP sont pour l'instant poussés sur le serveur de build, mais à terme ils doivent être une troisième source

* trois natures de contenu pour les paquets
  * code PHP du framework Voozanoo (3 ou 4)
  * code PHP d'une application
  * scripts utilitaires et cartographie propres à une nature de serveur (frontal, bdd, replication, etc...)

## Contraintes fonctionnelles

* x mini-framework de génération de paquets
  * x utilise des numéros de build comprenant la release debian. Ex: -2+deb9u1 -1+jessie8

* x prévoir deux repositories : prod et preprod (prep)
  * x les paquets arrivent dans un certain nombre de sources répertoriées (build, travis, epi-php, autre à venir)
  * x le script update.sh (evolution de apt_deploy.sh) est invoqué (par une URL http) à chaque changement dans les sources et reconstruit le répertoire preprod
  * x une opération (cli) permet de lister les paquets qui sont en preprod et pas encore en production
  * x une autre opération (cli) permet de montrer le fichier dans le repo de prod ou de le retirer
  * x les urls auront apt.epiconcept.fr pour base, le reste est libre (ou chaque repo aura son propre virtualhost si c'est nécessaire, genre apt-prod et apt-preprod)

* x permettre de garder plusieurs versions pour chaque paquet, et qu'elles soient toutes installables (pour assurer le rollback en cas de problème avec la nouvelle version)
  * x outils cli permettant de lister les différentes versions pour un paquet donné
  * ~ la politique de rétention sera à définir plus tard **(hors périmètre du projet courant, sans doute par nature du contenu des paquets)**

* x fonctionnalités
  * x les fichiers packages doivent être disponibles pour différentes versions Debian et Ubuntu (dont la liste sera dans un fichier texte ou plusieurs, stockés dans /etc/epiconcept/apt_repo/, variables liste_dist et liste_arch du script)
  * x les paquets propres à une version (uniquement les paquets PHP pour l'instant) ne devront être rendus disponibles que pour cette version
  * x le repo doit être signé pour que les paquets soient acceptés, et la clef disponible pour être déployée en même temps que le fichier /etc/apt/sources.list.d/epiconcept.list qui est déjà fait)
  * ~ l'accès aux packages et aux paquets sera limité soit sur l'IP, soit idéalement sur une authentification (si cela est possible pour APT) qui sera déposée sur chaque serveur (via le script de provisionning déjà existant à Epiconcept) **(hors périmètre du projet courant, l'authentification HTTP de Apache sera utilisée)**
  * x les paquets prenant une place certaine, on peut utiliser des softs ou hard links pour éviter de dupliquer les fichiers

* x définir les dossiers à sauvegarder pour restaurer les données à l'identique (dossier des paquets, éventuelles données à garder, etc...)
