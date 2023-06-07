# protonmail-bridge-cloud-config
Cloud Configs for creating a secure ProtonMail Bridge system

## How to use
1. Copy and paste the cloud config `.yml` contents where applicable for your cloud.  (I make use of Hetzner Cloud, though your cloud may work without any changes necessary.)
2. In the `.yml` contents, specify your new Proton Mail Bridge system's hostname, and the contact email address to use with the Let's Encrypt SSL certificate registration:
    - `  - echo "#!/bin/bash\n/root/create-protonmail-bridge-system.sh 'proton-bridge.your-domain.com' 'you@your-domain.com'" >/root/create-protonmail-bridge-system-with-args.sh`
3. Once the Proton Mail Bridge installation is complete, login to the system as root and run `proton-bridge-cli`.  At the Proton Mail Bridge CLI prompt:
    1. Enter `login` and proceed with the prompts to login to your Proton Mail account.
    2. Enter `info` and make note of the username and password.  You will need this information for your email client.
    3. Enter `exit`.
    4. Start the service with `systemctl start proton-bridge`.
3. The ProtonMail Bridge will be accessible on ports 993 (IMAPS / IMAP SSL) and 587 (SMTPS / SMTP SSL).  Enjoy!
