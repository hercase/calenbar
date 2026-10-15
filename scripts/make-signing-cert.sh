#!/bin/sh
# Creates a self-signed code-signing identity "Calenbar Dev" in the login keychain (run once).
# Signing every build with the same identity keeps macOS permissions (Calendar, Notifications)
# across rebuilds; ad-hoc signatures change each build and make macOS ask again.
set -e
# System LibreSSL on purpose: Homebrew OpenSSL 3+ writes PKCS#12 files the macOS keychain rejects.

NAME="Calenbar Dev"
if security find-identity -p codesigning | grep -q "\"$NAME\""; then
  echo "Identity \"$NAME\" already exists."
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$WORK/cert.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
PASSWORD=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$NAME" -out "$WORK/identity.p12" -passout "pass:$PASSWORD" 2>/dev/null

# -T lets codesign use the key without a keychain prompt on every build.
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P "$PASSWORD" -T /usr/bin/codesign >/dev/null

echo "Created code-signing identity \"$NAME\"."
