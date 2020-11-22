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
* Create function to update Windows
* Create a configuration file, and then call the functions based on lines in the config file
* Use the Windows Update PowerShell modules to do the Windows updating
* Add the ability to include other config files
* Use splatting to build command lines

### Missing bits
* Auto elevate to Admin
* If no file is passed on the command line, use a windows file picker to select it. [Example of using a WinForms File Open dialog in PowerShell][1], [Example of using WPF File Open][2]
* While doing rebooting, re-start script on login automatically
* Do upgrades before WSL to allow for an update to a more recent version of Windows
* Check requirements before installing items (e.g. Terminal)
* Check if Winget is installed
* Display the TaskStage number
* Install latest version of Windows

### Features
* Uninstall included Windows Installer apps
* Uninstall included Windows Store apps
* Add option to prompt for computer name
* Add Visual Studio Extenstions
* Add VS Code Extensions

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

[1]: https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/
[2]: https://www.c-sharpcorner.com/uploadfile/mahesh/openfiledialog-in-wpf/