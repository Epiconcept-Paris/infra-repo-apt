#!/bin/sh
#
#	genkey.sh - Generate a GPG key for APT signing
#
Prg=`basename $0`
test -f key.conf || { echo "$Prg: cannot find ./key.conf (must cd to our dir)" >&2; exit 1; }
Mail="`sed -n 's/^Name-Email: //p' key.conf`"
if gpg -k | grep "^uid .* <$Mail>$" >/dev/null; then
    echo "Deleting existing key found for $Mail:"
    gpg -k $Mail | sed 's/^/    /'
    fp=`gpg --fingerprint $Mail | sed -n 's/^ *Key fingerprint = //p' | tr -d ' '`
    #fp=`gpg -K $Mail | sed -nr 's;^sec +([^ ]+) .*$;\1;p'`
    gpg --batch --delete-secret-and-public-key $fp
fi
echo "Please generate entropy with 'sudo grep -Lr SomeImpossibleString /'..."
gpg --gen-key --batch key.conf
gpg -k $Mail
gpg --armor --export $Mail >key.gpg
