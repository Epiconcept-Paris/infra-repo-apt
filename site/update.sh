#!/bin/sh
#
#	update.sh - Update repository control files
#
Prg=`basename $0`

CfgDir=config
GpgDir=gpg
TmpDir=tmp

now()
{
    # Timestamps: just comment-out next line to remove them
    date '+[%Y-%m-%d %H:%M:%S] '
}

# Compo is the subdir we want in each dist, exactly as it appears
# after the dist name in /etc/apt/sources.list on APT clients
Compo=`cat $CfgDir/component`

umask 002
#
#   Startup checks
#
#   Note that error messages are NOT redirected to stderr !
#   Most of the time, stderr in this script would be itself redirected
#   to update.log, but we want to see the error messages on our tty
#
#   Check package dependencies
for binpkg in dpkg-scanpackages:dpkg-dev apt-ftparchive:apt-utils
do
    bin=`expr "$binpkg" : '\([^:]*\):'`
    pkg=`expr "$binpkg" : '[^:]*:\(.*\)$'`
    command -v $bin >/dev/null || { echo "$Prg: $bin not found, install package $pkg"; exit 3; }
done

#   Check our target repository top-dir (does not have to exist)
if [ "$1" ]; then
    expr $1 : '[^/][^/]*/' >/dev/null || { echo "$Prg: '$1' is not a relative path"; exit 2; }
    RepDir=$1
    Type=`basename $1`
else
    echo "Usage: $Prg <repository-top-dir>"
    exit 1
fi

#   We want our paths relative, so move to our top directory
if ! [ -f $CfgDir/dists -a -f $CfgDir/relconf -a -f $GpgDir/key.gpg ]; then
    cd $(dirname $0)
    if ! [ -f $CfgDir/dists -a -f $CfgDir/relconf -a -f $GpgDir/key.gpg ]; then
	echo "$Prg: cannot find $CfgDir/dist, $CfgDir/relconf and $GpgDir/key.gpg files"
	exit 2
    fi
fi
Top=$PWD/$RepDir

#
#   First step: generate the Packages files
#
DebDir=$RepDir/debs	# Packages top-dir
PkgDir=$RepDir/.pkg	# Package-info cache
Ts='+%Y-%m-%d %H:%M:%S'
Dsp="dpkg-scanpackages: info: Wrote 1 entries to output Packages file."
Err=$PkgDir/errors
Ovr=$PkgDir/override
>$Err
for DebArch in $(ls -d $DebDir/*/*)
do
    ArchDir=$(expr $DebArch : "$DebDir/\(.*\)")
    echo "$(now)Processing $ArchDir ..." >&2
    mkdir -p $PkgDir/$ArchDir
    #	First, build all missing / obsolete .pkg files
    /bin/ls -l --time-style="$Ts" $DebArch | while read m l u g s date time name
    do
	pkg=$(basename "$name" .deb)
	test "$pkg" = "$name" && continue	# $name does not end in .deb (e.g. Packages)
	pkg="$pkg.pkg"
	if [ -f $PkgDir/$ArchDir/$pkg ]; then
	    set -- $(ls -l --time-style="$Ts" $PkgDir/$ArchDir/$pkg)
	    test "$6" = "$date" -a "$7" = "$time" && continue
	fi
	echo "Processing $ArchDir/$name"
	echo "$pkg" | sed 's/_.*$/ optional base/' >$Ovr
	dpkg-scanpackages -m "$DebArch/$name" $Ovr 2>>$Err | sed "s;$Top/;;" >$PkgDir/$ArchDir/$pkg
	touch -d "$date $time" $PkgDir/$ArchDir/$pkg
    done
    #	Then remove any stale .pkg file
    ls $PkgDir/$ArchDir | while read f
    do
	deb=$(basename "$f" .pkg)
	test "$deb" = "$f" && continue	# $f does not end in .pkg
	deb=$deb.deb
	test -f $DebArch/$deb || { echo "Removing obsolete $PkgDir/$ArchDir/$f"; rm -f $PkgDir/$ArchDir/$f; }
    done
    All=$DebArch/Packages
    >$All
    find $PkgDir/$ArchDir -name '*.pkg' | LANG=C sort -t_ -k1,1 | xargs cat >>$All
    
    echo "$(now)Processing $ArchDir ended" >&2
done
grep "^$Dsp\$" $Err >/dev/null && echo "g/^$Dsp\$/d\nw" | ed - $Err
rm -f $Ovr

#
#   Second step: make the Dist directories
#
# APT requires the Release files to be signed with a *certified* key and
#	only the subkey (certified by the main key) fulfils that requirement
Mail="`sed -n 's/^Name-Email: //p' $GpgDir/key.conf`"
Sign=`gpg -k --with-colons $Mail | awk -F: '$1 == "sub" {print substr($5,9)}'`

while read Dist BinDir Comment
do
    test "$Dist" || continue		# empty line
    test "$Dist" = '#' && continue	# comment line
    echo "$(now)Updating '$Dist' distribution..." >&2
    DistDir=$RepDir/dists/$Dist
    CompDir=$DistDir/$Compo

    # First collect the Packages from debs/any (any $Dist)
    for ArchDir in $DebDir/any/*
    do
	Arch=`basename $ArchDir`
	mkdir -p $CompDir/binary-$Arch
	cp $ArchDir/Packages $CompDir/binary-$Arch
    done

    # Then concat Packages from debs/$Bindir if it exists
    if [ -d $DebDir/$BinDir ]; then
	for ArchDir in $DebDir/$BinDir/*
	do
	    Arch=`basename $ArchDir`
	    mkdir -p $CompDir/binary-$Arch
	    cat $ArchDir/Packages >>$CompDir/binary-$Arch/Packages
	done
    fi

    Archs=
    sep=
    # Create gziped version of Packages files and collect $Archs
    for ArchDir in $CompDir/binary-*
    do
	gzip -9 <$ArchDir/Packages >$ArchDir/Packages.gz
	Archs="$Archs$sep`expr $ArchDir : "$CompDir/binary-\(.*\)"`"
	sep=' '
    done

    # Create the Release file
    expr "$Type" : 'prod' >/dev/null && Orig='production' || Orig='pre-prod'
    sed -e "s/%ORIG%/$Orig/" -e "s/%DIST%/$Dist/" -e "s/%COMPO%/$Compo/" -e "s/%ARCHS%/$Archs/" $CfgDir/relconf >$TmpDir/relconf
    apt-ftparchive -c $TmpDir/relconf release $DistDir >$DistDir/Release

    # Sign the release file
    sed -n 's/^Passphrase: //p' $GpgDir/key.conf | (cd $DistDir; rm -f Release.gpg; gpg -sab --default-key $Sign --passphrase-fd 0 --pinentry-mode=loopback --batch -o Release.gpg Release)
    echo "$(now)Updated '$Dist' distribution." >&2
done <$CfgDir/dists
#
#   Done !
#
# Cleanup
rm $TmpDir/relconf
# If called for prod, save prod.list
expr "$Type" : 'prod' >/dev/null && find -L $DebDir -type f -name '*.deb' | sed 's;.*/;;' >config/${Type}.list
# Add public key that APT clients will import with apt-key
test -f $RepDir/key.gpg || ln $GpgDir/key.gpg $RepDir
