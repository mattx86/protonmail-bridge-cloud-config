#!/bin/bash

LETSENCRYPT_HOSTNAME="$1"
LETSENCRYPT_EMAIL="$2"

proton_bridge_version="3.1.3"
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
curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/proton-bridge-cli -o /usr/local/bin/proton-bridge-cli
chmod 755 /usr/local/bin/proton-bridge-cli

# Create a service account for Proton Mail Bridge.
useradd -e '' -f -1 -K PASS_MAX_DAYS=-1 -U -r -m -s /usr/sbin/nologin proton-bridge

# Initialize the password store.
su -s /bin/bash -c "gpg --batch --passphrase '' --quick-gen-key 'proton-bridge' default default never" - proton-bridge
su -s /bin/bash -c "pass init 'proton-bridge'" - proton-bridge

# Install service files and enable the service to start on boot.
curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/proton-bridge.init.d -o /etc/init.d/proton-bridge
curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/proton-bridge.service -o /etc/systemd/system/proton-bridge.service
chmod 755 /etc/init.d/proton-bridge
chmod 644 /etc/systemd/system/proton-bridge.service
systemctl enable proton-bridge

# Get and import Let's Encrypt certificate.
echo "LETSENCRYPT_HOSTNAME=\"${LETSENCRYPT_HOSTNAME}\"" >/root/.letsencrypt_settings
echo "LETSENCRYPT_EMAIL=\"${LETSENCRYPT_EMAIL}\"" >>/root/.letsencrypt_settings
curl -Ls https://raw.githubusercontent.com/mattx86/protonmail-bridge-cloud-config/main/update-proton-bridge-certificate.sh -o /usr/local/bin/update-proton-bridge-certificate.sh
chmod 755 /usr/local/bin/update-proton-bridge-certificate.sh
echo "15 3 15 */2 * root /usr/local/bin/update-proton-bridge-certificate.sh >/dev/null 2>&1" >/etc/cron.d/update-proton-bridge-certificate
chmod 644 /etc/cron.d/update-proton-bridge-certificate
/usr/local/bin/update-proton-bridge-certificate.sh

# Let user know we are done.
echo
echo
echo "Proton Mail Bridge installation is complete."
echo
echo "Please login to this system as root and run \"proton-bridge-cli\"."
echo "Once inside the Proton Mail Bridge CLI, enter \"login\" and proceed"
echo "with the prompts to login to your Proton Mail account.  When complete,"
echo "enter \"info\" and make note of the username and password.  Next,"
echo "enter \"exit\" and start the service (systemctl start proton-bridge),"
echo "or reboot the system."
echo
echo "Enjoy!"
echo
echo
