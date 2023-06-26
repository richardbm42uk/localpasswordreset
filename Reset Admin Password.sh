#!/bin/bash

# Static variables

# Change these variables
adminUser="administrator"
adminResetPlistPath="/Library/Managed Preferences/uk.co.academia.adminReset.plist"
passphrase="2a2d77446bf423b50129237b"

debugMode=true

logPath=/var/log/adminResetlog.log

plistbuddy=/usr/libexec/PlistBuddy 
salt=$4

# Log - this will be left in Jamf Pro
log(){
	echo "Log: $1"
}

# Verbose Log - we will remove this in the live implementation
verboseLog(){
	if [ $debugMode = "true"]; then
		dateLog "Verbose Log: $1"
	fi
}

# Log which writes the date to a local log
dateLog(){
	dateStamp=$(date)
	echo "$dateStamp $1"
	echo "$dateStamp $1" >> "$logPath"
}

decrypt() {
	echo "${1}" | /usr/bin/openssl enc -md md5 -aes256 -d -a -A -S ""${salt}"" -k "${passphrase}"
}

#Start of script

# Check for decryption keys. Quit if they are missing
if [ -z "$salt" ] || [ -z "$passphrase" ] || [ ! -e "$adminResetPlistPath" ]; then 
	log "Salt, passphrase or password list is missing, exiting"
	exit 1
fi

# Get the new Password
newEncoded=$(defaults read "$adminResetPlistPath" new) 
if [ -z "$newEncoded" ]; then # If there is no new password defined, quit
	log "No current password found, exiting"
	exit 1
else #Otherwise decrypt it and make sure it's not already been set
	new=$(decrypt $newEncoded) 
	#verboseLog  "New password will be set to $new"
    newPasswordTest=$(dscl . authonly "$adminUser" "$new") # Test the new password 
		if [ "$newPasswordTest" = "" ]; then # If the password works, it's already been updated, so quit
			echo "Password has already been updated, exiting."
            exit 0 
		fi
fi

# Loop through to find the current password
index=0
while [ -z $passwordVerified ]; do
	passToTestEncoded=$(/usr/libexec/PlistBuddy  -c "Print :old:$index" "$adminResetPlistPath")
	#verboseLog  $passToTestEncoded
	if [ -z $passToTestEncoded ]; then #If there is no password to test, exit the loop by setting passwordVerified to false
		#verboseLog  "No more passwords to test"
		passwordVerified="false" 
	else #Otherwise, decrypt the password
		passToTest=$(decrypt "$passToTestEncoded") 
		#verboseLog  "$passToTest"
		passwordTest=$(dscl . authonly "$adminUser" "$passToTest") # Test the password 
		if [ "$passwordTest" = "" ]; then # If the password works
			#verboseLog  "Found the correct password"
			passwordVerified="true" # Mark the password as Verified
		else
			#verboseLog  "Password did not match" 
			echo "No match found."
		fi
	fi
	index=$((index + 1)) # Iterate through the possible passwords
done

case $passwordVerified in
	true)
		#verboseLog  "Do stuff to change the password"
		/usr/local/bin/jamf changePassword -username "$adminUser" -password "$new" -oldPassword "$passToTest" -verbose
		resetStatus="$?"
		if [ "$resetStatus" = 0 ]; then
			dateLog "Success"
		else
			dateLog "Fail, error $resetStatus"
			exit 1
		fi
	;;
	false)
		log "No valid password found, exit"
		dateLog "Fail"
		exit 1
	;;
	*)
		log "Password verification not set, something odd has happened!"
		dateLog "Fail"
		exit 1
	;;
esac