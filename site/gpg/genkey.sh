#!/bin/sh
#
#	genkey.sh - Generate a GPG key for APT signing
#
Prg=`basename $0`
Cnf=key.conf

#   Paths are relative, so move to our top directory
if ! [ -f $Cnf ]; then
    cd `dirname $0`
    if ! [ -f $Cnf ]; then
	echo "$Prg: cannot find '$Cnf' configuration file" >&2
	exit 2
    fi
fi
Name="`sed -n 's/^Name-Real: //p' $Cnf`"
Mail="`sed -n 's/^Name-Email: //p' $Cnf`"

#   Delete any existing key
if gpg -k | grep "^uid  *$Name <$Mail>$" >/dev/null; then
    echo "Deleting existing keys found for $Mail:"
    gpg -k $Mail | sed 's/^/    /'
    fp=`gpg --fingerprint $Mail | sed -n 's/^ *Key fingerprint = //p' | tr -d ' '`
    gpg --batch --delete-secret-and-public-key $fp
fi
Conf=$HOME/.gnupg/gpg.conf
grep 'digest-algo SHA256' $Conf >/dev/null || echo "cert-digest-algo SHA256\ndigest-algo SHA256" >>$Conf

#   Generate new keys
echo "Please generate entropy with 'sudo grep -Lr SomeImpossibleString /'..."
gpg --gen-key --batch $Cnf
gpg -k

#   Make a full backup to be restored with gpg --import
gpg -a --export-secret-keys $Mail >master.gpg

#   Export the signing subkey for gpg --import on the repositories server
gpg -a --export-secret-subkeys $Mail >signing.gpg

#   Export the public subkey key.gpg to be copied in each repository,
#	downloaded by the APT client and passed to apt-key add
#
gpg -a --export $Mail >key.gpg				# for apt-key on clients
