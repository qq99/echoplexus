#!/bin/sh
SANDBOX_USERNAME='sandbox'
PUBLIC_DIR='public'
echo "Creating a new user account with disabled login named $SANDBOX_USERNAME"
adduser --disabled-login --gecos 'Sandbox' $SANDBOX_USERNAME
mkdir -p $PUBLIC_DIR/sandbox
echo "Allowing $SANDBOX_USERNAME user access to $PUBLIC_DIR/sandbox"
chown -R :sandbox $PUBLIC_DIR/sandbox
chmod -R g+rw $PUBLIC_DIR/sandbox
echo 'If you want to run phantomjs-screenshotter, you must now enable it in config.js, install phantomjs, and install the phantomjs_screenshot sister repository beside the echoplexus repository.'
