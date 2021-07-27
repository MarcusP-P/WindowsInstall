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
* `ComputerName`: [optional] change the name of the computer
* `InstallWsl`: [optional] a boolean to install WSL. If you are on Windows 2004 or later, it will automatically enable WSL2. Default: `false`
* `TaskStages`: [optional] an array of task stages. At the end of each stage, the script will exit.
	* `StageNumber`: [required] the number of this stage. 
		These are executed in ascending numerical order, starting with zero. If there is a missing stage, we will load the next highest number. At the moment, the script processes each script sequentially
	* `StartMessage`: [optional] a message to display at the start of this stage
	* `FinishMessage`: [optional] Message to display at the end of the stage. If this is missing, a default message will be displayed.
	* `FinishAction`: [optional] actions to take at the end of the set of stages. If not specified, `continue` is assumed.
		* `reboot`: Reboot at the end of the stage, after the user has hit enter
		* `exit`: Exit the script. It will need to be re-started manually
		* `continue`: continue onto the next stage
	* `Tasks`: [optional] an array of tasks
		* `Type`: [required] which can be one of the following:
			* `microsoftStore`: install a Microsoft Store app 
			* `winget`: install an app using Winget
			* `download`: downoad and execute an installer
			* `exec	: run an executable
			* `addWindowsFeature`: add a Windows feature
			* `removeWindowsFeature`: remove a Windows feature
			* `office`: intall Office 2016/2019/365, including customisations
		* `Comment`: [optional] this field doesn't affect the script in any way, but can be used to add notes to the configuration file. This field is not used by the script, but will not be used in the future.

		The remaining fields depend on the type:

### Install Microsoft Store App
* `Id`: [required] the Microsoft Store Product ID. You can find the product id by using the share link on the store app page
* `Text`: [optional] textual description to appear before installing

### Install a Winget package
* `Id`: [required] the Winget package to add. It is installed with `winget -e`, so you need to accurately match the package name
* `Scope`: [optional] Specify the scope of the package
* `AdditionalOptions`: [optional] an array of additional command line parameters to pass to Winget.

### Download and install from a URL
* `Url`: [required] the full URL of the file to download
* `Text`: [optional] text to display before the download
* `WaitMessage`: [optional] display this message to the user and wait for them to press enter after install

### Run an executable
* `Executable`: [required] the name of the executable.
* `Text`: [optional] text to display before starting the executable.

### Add a Windows feature
If the installation of the feature requires a reboot, the script will reboot at the end of the stage, overwriting the FinishAction for the stage.

* `Feature`: [required] the name of the feature to install

### Remove a Windows feature
If the removal of the feature requires a reboot, the script will reboot at the end of the stage, overwriting the FinishAction for the stage.

* `Feature`: [required] the name of the feature to uninstall

### Install Office
The Install Office task allows you to create a customised configuration file and uses the Office Deployment Tool to install it. 
See the [Configuration options for the Office Deployment Tool](https://docs.microsoft.com/en-us/deployoffice/office-deployment-tool-configuration-options)
to understand how to use the following options. Fields marked as optional are not required for the script to run, but may be required by the Office 
Deployment Tool.

* `ConfigurationAttributes`: [optional] an array of attributes to add to the Add element of the configuration file
	* `Attribute`: [required] the name of the attribute to add
	* `Value`: [required] the value to add
* `Products`: [optional] an array of products to install:
	* `ProductId`: [required] Microsoft's ID for the product to install. Refer to Mictosoft's [list of product IDs](https://docs.microsoft.com/en-au/office365/troubleshoot/installation/product-ids-supported-office-deployment-click-to-run).
	* `Language`: [optional] create the Language element:
		* `LanguageId`: [required] use this language
		* `Attributes`: [optional] an array of attributes for the Language element
			* `Attribute`: [required] the name of the attribute to add
			* `Value`: [required] the value to add
	* `Display`: [optional] create the Display element.
		* `Attributes`: [optional] an array of attributes for the Dispalay element
			* `Attribute`: [required] the name of the attribute to add
			* `Value`: [required] the value to add
	* `ExcludeComponents`: [optional] an array of strings containing the components to exclude from the office install. 
	  See [the list](https://docs.microsoft.com/en-us/deployoffice/office-deployment-tool-configuration-options#excludeapp-element) of known exlusions

## Todo
### Architecture
* Option to skip Windows Update
* Install Winget AppX package, rather than making people sign up to AppInstaller Insider
  * Make this configurable
* Add the ability to include other config files
* Use splatting to build command lines
* Add strictness checks
* Add error checking
* Add minimum and maximum Windows version numbers to tasks
* Install from Zipfile (e.g. OpenDBDiff)
* Install/uninstall Wondows Capabilities
* Install/Uninstall Windows Packages
* Windows 10 21H2 changes
  * Use wsl --install
  * Use built-in Winget

### Missing bits
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
* Execute commands under WSL
* Add AppX installer

### Configuration
* Configure WSL environment (.profile)
* Can we configure Edge (Portions that aren't synced like Search Engines, and use the selected search engine form new tab screen)
* Can we configure Windows Settings
  * Trackpad Tap to Click
  * Natural Scrolling
* Set power settings
* Add configuration for PowerToy Fanzy Zones screen layouts
* Install PowerLine
* Add Terminal configuration
  * Include PowerLine
* Configure Powershell
* Set system language and locale
* Set user  language and locale

[1]: https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/
[2]: https://www.c-sharpcorner.com/uploadfile/mahesh/openfiledialog-in-wpf/