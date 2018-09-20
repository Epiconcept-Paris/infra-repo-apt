#!/bin/bash

#if [ "$(ps aux |grep -E "[a]pt_deploy" |grep -v -e sudo |wc -l)" -gt 2 ]; then
#	exit 0
#fi

chemindest=/var/www/files.epiconcept.fr/data/files/repositories_apt/epiconcept/
chemindest_list=$chemindest/dists/
chemindestDeb=$chemindest/deb/
chemindestZIP=/var/www/files.epiconcept.fr/data/files/Episoft/

liste_dist="lenny squeeze wheezy jessie precise natty quantal raring saucy trusty xenial stretch bionic sid"
liste_arch="i386 amd64 armhf"

log=/home/epiconcept_build/journal.log

echo $(date +%Y%m%d%H%M%S) >> $log

rsync -rav /home/travis/depot/ $chemindestDeb/ >> $log

orig=$(pwd)
cd $chemindest
for i in deb/*.deb; do echo "$i optionnal base" | sed -e "s#deb/##" -e "s#.deb##" -e "s#_all##" -e "s#_[0-9]* # #" ; done | sort | uniq > override
dpkg-scanpackages deb/ override > Packages 2>> $log
gzip -c Packages > Packages.gz
bzip2 -c Packages > Packages.bz2

cd $orig
for dist in $liste_dist; do
	sed -e "s/ARCH/$liste_arch/g" -e "s/DATE/$(date --date='TZ="UTC"' +"%a, %d %b %G %R:%S UTC%z")/g" -e "s/DIST/$dist/g" /usr/local/bin/apt_deploy_Release > $chemindest_list/$dist/Release
        for arch in $liste_arch; do
                chemin="$chemindest_list/$dist/main/binary-$arch/"
                mkdir -p $chemin
		chmod 775 $chemin
                rsync -raq --dirs $chemindest/Packages* $chemin
		chmod 664 $chemin/*
		cp $chemindest_list/$dist/Release* $chemin
        done
done

chmod 664 $chemindestDeb/* $chemindestZIP/*

