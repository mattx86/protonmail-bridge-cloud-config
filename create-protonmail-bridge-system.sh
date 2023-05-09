#!/bin/bash

letsencrypt_hostname="$1"
letsencrypt_email="$2"

proton_bridge_version="3.1.1"
golang_version="2:1.18~0ubuntu2"

# Install the packages we need.
apt-get install -y git build-essential libsecret-common libsecret-1-dev libsecret-1-0 pass gpg golang=${golang_version} lego socat

# Get the Proton Mail Bridge code.
cd /root
git clone -b v${proton_bridge_version} --single-branch https://github.com/ProtonMail/proton-bridge.git

# Update some settings in the code.
cd /root/proton-bridge
go mod tidy
sed -rie '/gluon session ID/d' /root/go/pkg/mod/github.com/\!proton\!mail/gluon*/internal/session/session.go
sed -ri \
  -e 's;(IMAPPort:) .*;\1 1993,;' \
  -e 's;(SMTPPort:) .*;\1 1587,;' \
  -e 's;(IMAPSSL:) .*;\1 true,;' \
  -e 's;(SMTPSSL:) .*;\1 true,;' \
  -e 's;(ShowAllMail:) .*;\1 false,;' \
  -e 's;(AutoUpdate:) .*;\1 false,;' \
  internal/vault/types_settings.go

# Build and install the headless version of Proton Mail Bridge.
make build-nogui
install -o root -g root -m 755 /root/proton-bridge/proton-bridge /usr/local/bin/proton-bridge
install -o root -g root -m 755 /root/proton-bridge/bridge /usr/local/bin/bridge
cat <<EOF >/usr/local/bin/proton-bridge-cli
#!/bin/bash
su -P -s /bin/bash -c '/usr/local/bin/proton-bridge --cli' - proton-bridge
EOF
chmod 755 /usr/local/bin/proton-bridge-cli

# Create a service account for Proton Mail Bridge.
useradd -e '' -f -1 -K PASS_MAX_DAYS=-1 -U -r -m -s /usr/sbin/nologin proton-bridge

# Initialize the password store.
su -s /bin/bash -c "gpg --batch --passphrase '' --quick-gen-key 'proton-bridge' default default never" - proton-bridge
su -s /bin/bash -c "pass init 'proton-bridge'" - proton-bridge

# Get certificate.
cd /root
lego --accept-tos --email $letsencrypt_email --domains=$letsencrypt_hostname --http run
PROTON_BRIDGE_HOME=$(getent passwd proton-bridge | awk -F':' '{print $6}')
install -o proton-bridge -g proton-bridge -m 400 /root/.lego/certificates/${letsencrypt_hostname}.crt ${PROTON_BRIDGE_HOME}/${letsencrypt_hostname}.crt
install -o proton-bridge -g proton-bridge -m 400 /root/.lego/certificates/${letsencrypt_hostname}.key ${PROTON_BRIDGE_HOME}/${letsencrypt_hostname}.key

# Install certificate.
mkdir /root/import-tls-cert
cd /root/import-tls-cert
curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/import-tls-cert.go -o import-tls-cert.go
go mod init import-tls-cert
go install github.com/google/goexpect@latest
go mod tidy
go build import-tls-cert.go
./import-tls-cert ${PROTON_BRIDGE_HOME}/${letsencrypt_hostname}.crt ${PROTON_BRIDGE_HOME}/${letsencrypt_hostname}.key

# Install service files and enable the service to start on boot.
curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/proton-bridge.init.d -o /etc/init.d/proton-bridge
curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/proton-bridge.service -o /etc/systemd/system/proton-bridge.service
chmod 755 /etc/init.d/proton-bridge
chmod 644 /etc/systemd/system/proton-bridge.service
systemctl enable proton-bridge
