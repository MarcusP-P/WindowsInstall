# WindowsInstall
A Script to install a clean Windows machine to something useful. 

## To make PowerShell work
You will need to set the execution policy for scripts. 

For me: 
`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

You may also need to run `Unblock-File` against this script



## Todo
* Start the store app to load the updates before we begin
* Use one drop file to keep state, rather than one for every stage
* Auto elevate to Admin
* While doing rebooting, re-start script on login automatically
* add uninstall of Windows Installer apps
* Add Windows Store uninstaller
* Use a configuration file to allow different configs fpr different computers
* Do upgrades before WSL to allow for an update to a more recent version of Windows
* Add configuration for PowerToy screen layouts
* Check requirements before installing items (e.g. Terminal)
* Add download for non winget installers
* Configure WSL environment
* Can we configure Edge from the script?
* Can we configure Windows?