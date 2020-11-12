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

## Configuration
The Configuration is read form a JSON file. Look at Sample.json

Basic configuration is at the top level:
* `ComputerName`: change the name of the computer
* `InstallWsl`: a boolean to install WSL. If you are on Windows 2004 or later, it will automatically enable WSL2. Default: `false`
* `TaskStages`: an array of stages of tasks:
	* `StageNumber`: the number of this stage. 
		These are executed in ascending order, starting with zero. If there is a missing stage, we will load the next highest number. At the moment, the script processes each script sequentially
	* `Tasks`: an array of tasks
		* `Type`: which can be one of the following:
			* `microsoftStore`: install a Microsoft Store app 
			* `winget`: install an app using Winget

		The remaining fields depend on the type:

### Install Microsoft Store App
* `Id`: the Microsoft Store Product ID. You can find the product id by using the share link on the store app page

### Install a Winget package
* `Id`: the Winget package to add. It is installed with `winget -e`, so you need to accurately match the package name
* `AdditionalOptions`: an array of additional command line parameters to pass to Winget.
		

## Todo
### Architecture
* Create function to update Windows
* Use the configuration file to install a file from a URL
* Use the configuration file to install Office
* Option to skip Windows Update
* Install Winget AppX package, rather than making people sign up to AppInstaller Insider
  * Make this configurable
* Use the Windows Update PowerShell modules to do the Windows updating
* Add the ability to include other config files

### Missing bits
* Auto elevate to Admin
* While doing rebooting, re-start script on login automatically
* Do upgrades before WSL to allow for an update to a more recent version of Windows
* Check requirements before installing items (e.g. Terminal)
* Check if Winget is installed
* Install latest version of Windows

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
* Configure Powershell
