# WindowsInstall
A Script to install a clean Windows machine to something useful. 

## Important note about Windows Package Manager
You will need to [join the Windows Package Manager Insiders Program](http://aka.ms/winget-InsiderProgram) 
and make sure you're logged into the Windows Store (You can log into the store while the store 
updates are being downloaded)

## To make PowerShell work
You will need to set the execution policy for scripts. 

For me: 
`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

You may also need to run `Unblock-File` against this script

## Todo
### Architecture
* Create function to install winget applications
* Create function to install downloaded files
* Create function to install downloaded MSI files
* Create function to update Windows
* Create function to install Office 365
* Create a configuration file, and then call the functions based on lines in the config file
* Use the Windows Update PowerShell modules to do the Windows updating
* Use one drop file to keep state, rather than one for every stage

### Missing bits
* Auto elevate to Admin
* While doing rebooting, re-start script on login automatically
* Do upgrades before WSL to allow for an update to a more recent version of Windows
* Check requirements before installing items (e.g. Terminal)

### Features
* Uninstall included Windows Installer apps
* Uninstall included Windows Store apps
* Add Visual Studio Extenstions
* Add VS Code Extensions
	* C#

### Configuration
* Configure WSL environment (.profile)
* Can we configure Edge (Portions that aren't synced like Search Engines, and use the selected search engine form new tab screen)
* Can we configure Windows Settings
	* Trackpad Tap to Click
* Set power settings
* Add configuration for PowerToy screen layouts
* Install PowerLine
* Add Terminal configuration
	* Include PowerLine
