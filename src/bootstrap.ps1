Import-Module WinSux

elevateScript
windowSettings

# Make script silent
$progresspreference = 'silentlycontinue'

function main {

	$choice = $Host.UI.PromptForChoice(
	    'Install Options',
	    'Choose what you want to do. By default the script will perform an online install, which requires internet. But you can predownload the required files and install from them later, if you wish.',
	    [System.Management.Automation.Host.ChoiceDescription[]](
		[System.Management.Automation.Host.ChoiceDescription]::new("&O", "Perform a regular online install"),
		[System.Management.Automation.Host.ChoiceDescription]::new("&P", "Prefetch the required binaries for an offline install.")
	    ),
	    	[System.Management.Automation.Host.ChoiceDescription]::new("&L", "Perform an offline install using local files."),
		[System.Management.Automation.Host.ChoiceDescription]::new("&D", "Clean up and delete the WinSux temporary directory."),
	0  # default choice index
	)
	if ($choice -eq 0) { onlineInstall }
	elseif ($choice -eq 1) { prefetchFiles }
	elseif ($choice -eq 2) { offlineInstall }
	elseif ($choice -eq 3) { cleanUp }

	# Check if necessary temporary directories were made
	if (makeTempDir = $false) {
		Write-Host "Script was unable to create temporary directories, exiting..."
		Pause
		Exit
	}

	# Check internet
	if (networkTest = $false) {
		Write-Host "This option requires internet access!"
		Pause
		Exit
	}

}

# Checks the internet connection
function networkTest{
if (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue) {
	return $true
}

else {
	return $false
	}
}

# Makes the needed temp directories
function makeTempDir{
	try {
		New-Item -ItemType Directory -Path "$env:TEMP\WinSux", "$env:TEMP\WinSux\bin", "$env:TEMP\WinSux\bin", "$env:TEMP\WinSux\bin\ddu", "$env:TEMP\WinSux\bin\inspector" -Force -ErrorAction Stop | Out-Null
		return $true
	} catch {
		Write-Error "Creation of temporary directory failed. No permissions or non-standard environment? Please make sure `$env:TMP is accessible. Error: $($_.Exception.Message)"
		return $false
	}
}

# Bootstraps required source files from GitHub
function bootstrap{
	# Download src folder and root files from GitHub
	$repo = "qrlh/WinSux"

		$srcfiles = (IRM "https://api.github.com/repos/$repo/contents/src").download_url
		foreach ($url in $srcfiles) {
			$filename = $url.Split("/")[-1]
				IWR $url -OutFile "$env:TEMP\WinSux\src\$filename"
		}

	$rootfiles = IRM "https://api.github.com/repos/$repo/contents/"
		foreach ($item in $rootfiles) {
			if ($item.type -eq "file") {
				IWR $item.download_url -OutFile "$env:TEMP\WinSux\$($item.name)"
			}
		}
}

function onlineInstall {
	# Run WinSux install script
	# dot notation opens script in current scope

	. $env:TEMP\WinSux\src\onlineInstall.ps1
	restart
}

function prefetchFiles {

}

function offlineInstall {

}

function cleanUp {

}

function restart {
	Write-Host "RESTARTING`n" -ForegroundColor Red
	Start-Sleep -Seconds 5
	shutdown -r -t 00
}

main
