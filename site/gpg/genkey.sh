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

#   Generate new keys
echo "Please generate entropy with 'sudo grep -Lr SomeImpossibleString /'..."
gpg --gen-key --batch $Cnf
gpg -k

#   Export the public signing subkey to be copied in the repo
#   APT requires the Release files to be signed with a *certified* key and
#	only the subkey (certified by the main key) fulfils that requirement
Sign=`gpg -k --with-colons $Mail | awk -F: '$1 == "sub" {print substr($5,9)}'`
gpg -a --export $Sign >key.gpg
