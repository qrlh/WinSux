Import-Module WinSux

function main {
	installFromWinGet
	installManual
	7zipConfig
	dduConfig
	windowsUpdateConfig
	chromeConfig
	postRebootSetup
}

# Download / install required packages from WinGet
function installFromWinGet {
	# TODO: This should be exported from a psm1 module
    # Packages to be installed via WinGet
    # version is used to pin/override versions
    # flags is used to pass individual flags to the installers, be sure to properly escape quotes
    # installType is used to download packages instead of installing them
    $packages = Get-Content -Path ".\packages.json" -Raw | ConvertFrom-Json
    $installpkgs = $packages.packages

    Write-Host "Downloading from WinGet`n"

    $wingetFlags = "--accept-package-agreements --accept-source-agreements"
    $dest = "$env:TEMP\WinSux\bin"
    $script:bins = @{}
    foreach ($pkg in $installpkgs) {
        $ver = if ($pkg.version) {
            "--version $($pkg.version)"
        } else { "" }
        $before = Get-ChildItem $dest | Select-Object -ExpandProperty FullName
        $installType = if ($pkg.installType) {
            "$($pkg.installType)"
        } else { "install" }
        if ($installType) {
            $packageParam = "--download-directory $($dest)"
        } else { "--override `"$($pkg.flags)`"" }
        winget $installType $pkg.id $ver $packageParam $wingetFlags 
        $after = Get-ChildItem $dest | Select-Object -ExpandProperty FullName
        $new = $after | Where-Object { $_ -notin $before -and $_ -notmatch '\.yaml$' }
        $script:bins[$pkg.id] = $new
    }
}

# The binaries that are not installed from WinGet, but merely downloaded and require some kind of follow-up or manual install
function installManual {
    # Unpack/Install binaries manually
    # DDU
    & "$env:SystemDrive\Program Files\7-Zip\7z.exe" x $script:bins["Wagnardsoft.DisplayDriverUninstaller"] -o"$env:TEMP\WinSux\bin\ddu" -y | Out-Null
    # Nvidia Profile Inspector
    & "$env:SystemDrive\Program Files\7-Zip\7z.exe" x $script:bins["Orbmu2k.nvidiaProfileInspector"] -o"$env:TEMP\WinSux\bin\inspector\" -y | Out-Null
    Copy-Item "$env:TEMP\WinSux\bin\inspector\nvidiaProfileInspector.exe" -Destination "$env:TEMP\WinSux\bin\inspector.exe" 
	Write-Host "Staging complete"
}

function 7zipConfig {
	Write-Host "7zip config`n"
	# Set config for 7zip
	cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
	cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
	# cleaner 7zip start menu shortcut path
	Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
	Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}

function dduConfig {
    $dduConfigXml = [xml](Get-Content -Path ".\ddu.xml" -Raw) 
	Write-Host "DDU config`n"
	# Set config for ddu
	Set-Content -Path "$env:TEMP\WinSux\bin\ddu\Settings\Settings.xml" -Value $DduConfig -Force
	# set ddu config to read only
	Set-ItemProperty -Path "$env:TEMP\WinSux\bin\ddu\Settings\Settings.xml" -Name IsReadOnly -Value $true
}

function windowsUpdateConfig {
	Write-Host "Block driver from Windows Update`n"
	# Prevent downloads of drivers from windows update
	cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\DriverSearching`" /v `"SearchOrderConfig`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}
function chromeConfig {
	Write-Host "Chrome config`n"
	# install ublock origin lite
	cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist`" /v `"1`" /t REG_SZ /d `"ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx`" /f >nul 2>&1"
	# add chrome policies
	cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome`" /v `"HardwareAccelerationModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
	cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome`" /v `"BackgroundModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
	cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome`" /v `"HighEfficiencyModeEnabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

	# remove logon chrome
	$basePath = "HKLM:\Software\Microsoft\Active Setup\Installed Components"
	Get-ChildItem $basePath | ForEach-Object {
	    $val = (Get-ItemProperty $_.PsPath)."(default)"
	    if ($val -like "*Chrome*") {
		Remove-Item $_.PsPath -Force -ErrorAction SilentlyContinue
	    }
	}

	# remove chrome services
	$services = Get-Service | Where-Object { $_.Name -match 'Google' }
	foreach ($service in $services) {
	    cmd /c "sc stop `"$($service.Name)`" >nul 2>&1"
	    cmd /c "sc delete `"$($service.Name)`" >nul 2>&1"
	}

	# remove chrome scheduled tasks
	Get-ScheduledTask | Where-Object { $_.TaskName -like '*Google*' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
}

# TODO: This should be exported from a module
# TODO: We should try to use proper windows APIs to run the post reboot scripts
# https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks-create
function postRebootSetup {
	Write-Host "Setting up post-restart scripts`n"
	# allow password sign in
	cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device`" /v `"DevicePasswordLessBuildVersion`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

	# disable open terminal by default
	cmd /c "reg add `"HKCU\Console\%%Startup`" /v `"DelegationConsole`" /t REG_SZ /d `"{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}`" /f >nul 2>&1"
	cmd /c "reg add `"HKCU\Console\%%Startup`" /v `"DelegationTerminal`" /t REG_SZ /d `"{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}`" /f >nul 2>&1"

	# install runonce stepone ps1 file to run in safe boot
	cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"*stepone`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:TEMP\WinSux\src\stepone.ps1`" /f >nul 2>&1"

	# install runonce steptwo ps1 file to run in normal boot
	cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"steptwo`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:TEMP\WinSux\src\steptwo.ps1`" /f >nul 2>&1"

	# turn on safe boot
	cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"
}

main
