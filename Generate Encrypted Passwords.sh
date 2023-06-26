#!/bin/bash
# Generate Encrypted Password

## Password to encrypt
PASSWORD=newPassword

## Generate new salt and passphrase on first run only
firstRun=false

## Settings to configure after first run
SALT="c23ad434d1a51985" #SALT
PASSPHRASE="a5c3b841e22196010c6709d8" #Passphrase

# Start of script

if [ $firstRun = false ]; then
	SALT=$(openssl rand -hex 8)	
	PASSPHRASE=$(openssl rand -hex 12)	

echo "First run complete, to ensure all future passwords use the same details
1. Change firstRun to                  false
2. Change the SALT variable to         $SALT
3. Change the PASSPHRASE to            $PASSPHRASE
"
fi

encryptedPassword=$(echo "${PASSWORD}" | openssl enc -md md5 -aes256 -a -A -S "${SALT}" -k "${PASSPHRASE}")

# Insert the password to be encrypted here and run.

echo "Encrypted password:                    $encryptedPassword"