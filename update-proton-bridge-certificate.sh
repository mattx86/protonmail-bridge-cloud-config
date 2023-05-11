#!/bin/bash

. /root/.letsencrypt_settings

# Get certificate.
cd /root
lego --accept-tos --email $LETSENCRYPT_EMAIL --domains=$LETSENCRYPT_HOSTNAME --http run

# Install certificate.
PROTON_BRIDGE_HOME=$(getent passwd proton-bridge | awk -F':' '{print $6}')
install -o proton-bridge -g proton-bridge -m 400 /root/.lego/certificates/${LETSENCRYPT_HOSTNAME}.crt ${PROTON_BRIDGE_HOME}/${LETSENCRYPT_HOSTNAME}.crt
install -o proton-bridge -g proton-bridge -m 400 /root/.lego/certificates/${LETSENCRYPT_HOSTNAME}.key ${PROTON_BRIDGE_HOME}/${LETSENCRYPT_HOSTNAME}.key

# Build import-tls-cert, if needed.
if [ ! -f /root/import-tls-cert/import-tls-cert ] ; then
  mkdir /root/import-tls-cert
  cd /root/import-tls-cert
  curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/import-tls-cert.go -o import-tls-cert.go
  go mod init import-tls-cert
  go install github.com/google/goexpect@v0.0.0-20210430020637-ab937bf7fd6f
  go mod tidy
  go build import-tls-cert.go
fi

# Stop Proton Mail Bridge.
RESTART_PROTON_BRIDGE=false
systemctl status proton-bridge >/dev/null 2>&1
if [ $? -eq 0 ] ; then
  systemctl stop proton-bridge
  RESTART_PROTON_BRIDGE=true
fi

# Import certificate.
/root/import-tls-cert/import-tls-cert ${PROTON_BRIDGE_HOME}/${LETSENCRYPT_HOSTNAME}.crt ${PROTON_BRIDGE_HOME}/${LETSENCRYPT_HOSTNAME}.key

# Ensure proton-bridge CLI has stopped running.
pkill -9 -f -n -U proton-bridge 'bridge --cli'

# Start Proton Mail Bridge if it was previously running.
if [ "$RESTART_PROTON_BRIDGE" == "true" ] ; then
  systemctl start proton-bridge
fi
