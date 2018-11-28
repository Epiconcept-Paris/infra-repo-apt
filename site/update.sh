#!/bin/sh
#	update.sh - Update repository control files
#
Prg=`basename $0`

CfgDir=config
GpgDir=gpg
TmpDir=tmp

if [ "$1" ]; then
    expr $1 : '[^/][^/]*/' >/dev/null || { echo "$Prg: '$1' is not a relative path" >&2; exit 2; }
    RepDir=$1
else
    echo "Usage: $Prg <repository-top-dir>" >&2
    exit 1
fi

#   Paths are relative, so move to our top directory
if ! [ -f $CfgDir/dists -a -f $CfgDir/relconf -a -f $GpgDir/key.gpg ]; then
    cd `dirname $0`
    if ! [ -f $CfgDir/dists -a -f $CfgDir/relconf -a -f $GpgDir/key.gpg ]; then
	echo "$Prg: cannot find $CfgDir/dist, $CfgDir/relconf and $GpgDir/key.gpg files" >&2
	exit 2
    fi
fi

Compo=main
DebDir=$RepDir/debs

umask 002

# Generate Packages files
for DebArch in `ls -d $RepDir/debs/*/*`
do
    #ls $DebArch/*.deb | sed -e "s;^$DebArch/;;" -e 's/.deb$/ optional base/' -e 's/_all//' -e 's/_[0-9]* / /' | sort -u >$DebArch/override
    echo "Generating $DebArch/override"
    for deb in $DebArch/*.deb
    do
        dpkg-deb -W --showformat '${Package} optional base\n' $deb 2>/dev/null
    done | sort -u >$DebArch/override
    echo "Processing $DebArch ..."
    dpkg-scanpackages -m $DebArch $DebArch/override >$DebArch/Packages
    rm $DebArch/override
done

# Make dists directories
while read Dist BinDir
do
    echo "Updating '$Dist' distribution"
    DistDir=$RepDir/dists/$Dist
    CompDir=$DistDir/$Compo
    for ArchDir in $RepDir/debs/any/*
    do
	Arch=`basename $ArchDir`
	mkdir -p $CompDir/binary-$Arch
	cp $ArchDir/Packages $CompDir/binary-$Arch
    done
    if [ -d $RepDir/debs/$BinDir ]; then
	for ArchDir in $RepDir/debs/$BinDir/*
	do
	    Arch=`basename $ArchDir`
	    mkdir -p $CompDir/binary-$Arch
	    cat $ArchDir/Packages >>$CompDir/binary-$Arch/Packages
	done
    fi
    Archs=
    sep=
    for ArchDir in $CompDir/binary-*
    do
	gzip -9 <$ArchDir/Packages >$ArchDir/Packages.gz
	xz <$ArchDir/Packages >$ArchDir/Packages.xz
	Archs="$Archs$sep`expr $ArchDir : "$CompDir/binary-\(.*\)"`"
	sep=' '
    done
    test "`basename $RepDir`" = 'prod' && Orig='production' || Orig='pre-prod'
    sed -e "s/%ORIG%/$Orig/" -e "s/%DIST%/$Dist/" -e "s/%COMPO%/$Archs/" -e "s/%ARCHS%/$Compo/" $CfgDir/relconf >$TmpDir/relconf
    apt-ftparchive -c $TmpDir/relconf release $DistDir/ >$DistDir/Release
    sed -n 's/^Passphrase: //p' $GpgDir/key.conf | (cd $DistDir; rm -f Release.gpg; gpg --sign --passphrase-fd 0 --batch -ab -o Release.gpg Release)
done <$CfgDir/dists
ln $GpgDir/key.gpg $RepDir

