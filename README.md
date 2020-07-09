# WindowsInstall
A Script to install a clean Windows machine to something useful. 

## To make PowerShell work
You will need to set the execution policy for scripts. 

For me: 
`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

You may also need to run `Unblock-File` against this script



## Todo
### Architecture
* Create functions that are called to install stuff, and call those (including manually running installers)
* Create a configuration file, and then call the functions based on lines in the config file

### Missing bits
* Start the store app to load the updates before we begin
* Use one drop file to keep state, rather than one for every stage
* Auto elevate to Admin
* While doing rebooting, re-start script on login automatically
* Do upgrades before WSL to allow for an update to a more recent version of Windows
* Add configuration for PowerToy screen layouts
* Check requirements before installing items (e.g. Terminal)

### Features
* Uninstall included Windows Installer apps
* Uninstall included Windows Store apps

### Configuration
* Configure WSL environment
* Can we configure Edge (Portions that aren't synced like Search Engines, and use the selected search engine form new tab screen)
* Can we configure Windows Settings
	* Trackpad Tap to Click
* Set power settings