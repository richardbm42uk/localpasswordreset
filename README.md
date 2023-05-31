# Local Password Reset

## What is this?

This workflow is aimed at IT departments who need to rotate the password of all Macs in their estate. It is designed to be deployed using an MDM (specifically Jamf) and can update any known passwords for a given user account.

### Why bother?

With the advent of Apple's CPUs, hard disk ownership and other changes is macOS changing passwords has become more complicated. FileVault can present its own complications when it comes to passwords - so this script is designed to make it simple to update passwords.

### Who is this for?

This is aimed at IT departments who don't have a need for LAPS, who want to deploy generic admin accounts to their Mac estate but need to periodically rotate passwords when staff leave or on a set schedule.

### Why use this method over another?

This method has been designed to overcome several potential issues, including

- It can try several different current passwords in the event of inconsistency, typically if some Macs haven't had their password updated straight away
- It keeps all passwords secure by deploying them in 3 separate components, meaning that only someone with access to the MDM able to see all the components is likely to be able to reverse engineer the passwords

### Minimising risks that users can find the passwords

Passwords are deployed to the end client as an AES 256-bit encrypedstring. In this implementation, this is stored on the Mac so a savvy user could find the list of strings which is accessable as a configuration profile or managed preference file. However, all strings require a separate PASSKEY and SALT to successfully be decrypted, both of which are stored separately and only available on the local machine during execution of the script, dramatically limiting the possibilty of users decrypting the strings.

| Component  | Deployed using  | Security Note  |
|:----------|:----------|:----------|
| Encrypted Passwords   | Configuration Profile | The encrypted strings are visible on client Macs in System Preferences / Settings under Profiles if this is not hidden. The strings are also visible at /Library/Managed Preferences/SOMEDOMAIN.plist |
| PASSPHRASE    | Script   | The passphrase is hard coded as a variable in the password change script. This keeps it separate in the Jamf interface from the SALT. The script is downloaded and executed by Jamf Pro. Administrator credentials would be needed to extract the script during this brief window. The script is not stored on client Macs otherwise.|
| SALT   | Policy    | The salt is passed into the script during policy execution. This keeps it separated from the PASSPHRASE. The salt could be obtained by a user only during execution by monitoring active processes on the Mac.|

To further obfuscate these details, it is recommended to not use names like "Password Reset" for the Configuration profile or its domain. IT staff can also be restricted from accessing the SALT or PASSPHRASE by removing their access to the Script or Policy sections of Jamf Pro if necessary.

To further minimise risk, any compromised PASSPHRASE or SALT can be replaced and an new list of encrypted passwords generated. This can be performed any time that staff with knowledge of the password update leaves, or on a scheduled basis.

Efforts to further minimise the already very small risks are further minimised in a more complex version of this script that only downloads the configuration profile during script execution.

Furthermore, the passwords could in theory be decrypted without the SALT and PASSPHRASE using brute force. By adding more encrypted strings (old passwords) to the list, this provides a greater possibility of decryption. However, as long as the passwords themselves are obscure and follow general advice (eg: not just changing the number at the end, not reusing dictionary words, keeping passwords long), this would make it extremely hard for any decryption attack. In 2021, it was suggested that the most powerful quantum computers would take 229*10^20 billion years to crack AES 256, and even so a good obscure password might be even harder if each is unique.


# How to deploy with Jamf Pro

## Component overview

| Item  | Type  | Description  |
|:----------|:----------|:----------|
| Generate Encrypted Passwords | Script | Script to encrypt your passwords ready for deployment
| Reset Admin Password    | Script   | Script to perform the password rotation
| Admin Password Profile   | Profile   | Configuration Profile to deliver encrypted password strings for possible old passwords and the new password
| Reset Admin Password  | Policy   | Jamf Pro Policy to perform the password rotation



## Generate encrypted passwords

Use the script **Generate Encrypted Passwords** to create hashed versions of both the new and any previous passwords

Set the PASSWORD variable to the password that needs to be encryped

On first run, make sure the firstRun variable is set to true, this will generate a SALT and PASSPHRASE as well as the encrypted password string. 
Having run the script, copy the SALT and PASSPHRASE as values of the variables in the script and change the firstRun variable to false. Make sure to save a copy of the script or make a note of your SALT and PASSPHRASE as these are used to encrypt any future passwords and to decrypt them.

Run the script to generate encrypted versions of all known old passwords that need updating as well as the new password that Macs should be set to. Keep a note of the output ready to deploy.

## Reset Admin Password Script

The script should be uploaded to Jamf Pro and the following variables customised

1. **adminUser** - the name of the admin user account to be updated with a new password
2. **adminResetPlistPath** - the path to the password preferences which is deployed as a separate password. This must match the profile being deployed, eg: /Library/Managed Preferences/*com.myDomain.passwordList.plist* which corresponds to a profile with the domain *com.myDomain.passwordList.plist*
3. **passphrase** - a passphrase used to encrypt the password. Set this to the passphrase generated at first run of the  **Generate Encrypted Passwords**
4. **debugMode** - debug mode creates additional logs in the log file and Jamf Pro and should be disabled in production by setting its value to false, for testing set it to true
5. **logPath** - path for logging the script, default path *var/log/adminResetlog.log*

It is also recommended to set Parameter 4 with the title "Salt"

## Configuration Profile 

The profile will install a list of old possible passwords as well as the new password to be used. It can be updated easily by replacing the new password and moving the old password to the old password section in order to rotate the passwords.

1. In Jamf Pro, create a new configuration Profile.
2. It is recommended to name the Profile with an obscure name, eg: Admin Account as this could be discovered by end users.
3. Add the Application & Custom payload and use the Upload option
4. Click add and enter a domain. This domain can be anything, but must match the preference file in the script. Eg: *com.myDomain.passwordList.plist* will create a preference at /Library/Managed Preferences/*com.myDomain.passwordList.plist*
5. Paste in the property list for the configuration profile. 
6. Replace the encrypted string in the *new* array with the encrypted string generated by the  **Generate Encrypted Passwords** for the latest password that Macs should use
7. Replace the encrypted string(s) in the *old* array with the encrypted string(s) of passwords that are currently or previously in use and need to be updated. Copy and paste the line to add more encrypted strings if there are more, or alternately delete encrypted strings if they are not needed.
8. Scope the profile to any Macs that need passwords updated and Save the profile.

Note. In Step 7, when resetting passwords, the old passwords are tested by the script starting at the top and working down. It is recommended to list passwords in date order with the latest retired password at the top and older or less common passwords at the bottom. There is no limit on how many old passwords can be listed, but there can only be one new password.

## Reset Admin Password Policy

The policy will deploy the new password by running the script on the client Mac. 

1. In Jamf Pro, create a Policy and provide a suitable name. 
2. Trigger should be set appropriately. Typically at Checkin, though a custom Trigger can be used during testing. Startup and Login options are possible if enabled in the environment, but Login is not recommended as this could theoretically change the admin password during that admin user attempting to log in.
3. Execution Frequency should typically be set to *Once Per Computer* unless using an Extension Attribute to monitor password status. However, if using *Once Per Computer* it is recommended to configure retries if the policy fails. 
4. Add a Script payload and choose the *Reset Admin Password Script*
5. Paste in the SALT generated earlier as parameter $4.
6. Scope and Save the policy.

##### Frequency
If the policy reruns, the script will not change the password if it already matches the new password currently being set, so it should be safe to allow the policy to rerun on a Mac. However to minimise unnecessary execution, the policy should only run once unless it fails. This does however necessitate manually Flushing the policy every time the password is rotated.
If used in conjunction with an Extension Attribute, then the policy can run without being flushed. However, such an Extension Attribute would need to include both the SALT and PASSPHRASE or use a completely different method of encryption which would lower security.

# Maintenance

To update the passwords and rerun the policy
1. Generate a new encrypted string for the new password
2. Edit the Configuration Profile to
	1. Move the now retired string from the "new" array to the top of the "old" array.
	2. Paste the newly generated encrypted string as the only entry in the "new" array.
3. If the Reset Admin Password Policy is set to run Once Per Computer, then access its Logs and click Flush All to set it to run again.

# Testing

It is strongly recommended to test the policy on a selection of Macs before wider deployment. The Configuration Profile can be more widely deployed without affecting any other functionality of any Macs.

### Tests to run:
1. On a Mac with an admin account that matches a known "old" password, the password should be updated to the "new" password
2. On Mac without that admin account or with an unknown password, the script should fail.

# Known Issues

In deployment, this script can fail if the administrator account has never logged in or if OS updates have occurred since the last login. The admin account will display as locked when running DSCL queries and can only be fixed by manually logging into the account. After this, script execution should work. In this case, a workaround is to completely remove the account and replace it with a new account - this is not recommended in workflows where FileVault is used as the new account may not be granted a Secure Token when programatically created by Jamf Pro, and is unlikely to have FileVault access until it is manually logged into for the first time.

# License

This Script is available for use at your own risk. It comes with no guarantees and the author cannot be held responsible for any harm caused by running it (especially without proper testing).

It is recommended that you do not deploy the script if you're not comfortable with the deployment process and not able to read the script and have at least a good understanding of what it is going to do.

**This script must not be used in full or in part or plagarised by Jigsaw24 or anyone affiliated with Jigsaw24.**