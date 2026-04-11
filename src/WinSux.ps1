# SCRIPT RUN AS ADMIN
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
{Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit}
$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + " (Administrator)"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
Clear-Host

# SCRIPT CHECK INTERNET
if (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
    Write-Host "Internet Connection Required`n" -ForegroundColor Red
    Pause
    exit
}

# SCRIPT SILENT
$progresspreference = 'silentlycontinue'

# Make temp directory
New-Item -ItemType Directory -Path "$env:TEMP\WinSux", "$env:TEMP\WinSux\bin", "$env:TEMP\WinSux\bin", "$env:TEMP\WinSux\bin\ddu", "$env:TEMP\WinSux\bin\inspector" -Force | Out-Null

Function WinGetSource{
    Write-Host "Downloading from WinGet`n"

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

    # Packages to be installed via WinGet
    # version is used to pin/override versions
    # flags is used to pass individual flags to the installers, be sure to properly escape quotes
    $installpkgs = @(
        @{ id = "7zip.7zip";                    version = "";  flags = "/S" },
        @{ id = "Google.Chrome";                version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.DirectX";            version = "";  flags = "/quiet"},
        @{ id = "Microsoft.VCRedist.2005.x86";  version = "";  flags = '/Q /C:\"msiexec /i vcredist.msi /qn /norestart\"' },
        @{ id = "Microsoft.VCRedist.2008.x86";  version = "";  flags = "/q" },
        @{ id = "Microsoft.VCRedist.2010.x86";  version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.VCRedist.2012.x86";  version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.VCRedist.2013.x86";  version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.VCRedist.2015+.x86"; version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.VCRedist.2005.x64";  version = "";  flags = '/Q /C:\"msiexec /i vcredist.msi /qn /norestart\"' },
        @{ id = "Microsoft.VCRedist.2008.x64";  version = "";  flags = "/q" },
        @{ id = "Microsoft.VCRedist.2010.x64";  version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.VCRedist.2012.x64";  version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.VCRedist.2013.x64";  version = "";  flags = "/quiet /norestart" },
        @{ id = "Microsoft.VCRedist.2015+.x64"; version = "";  flags = "/quiet /norestart" }
    )
    foreach ($pkg in $installpkgs) {
        $ver = if ($pkg.version) { "--version $($pkg.version)" } else { "" }
        winget install $pkg.id $ver --override "$($pkg.flags)" --accept-package-agreements --accept-source-agreements
    }

    # Packages to be downloaded via WinGet and unpacked/installed manually
    $dest = "$env:TEMP\WinSux\bin"
    $downloadpkgs = @(
        @{ id = "Wagnardsoft.DisplayDriverUninstaller"; version = "" },
        @{ id = "Orbmu2k.nvidiaProfileInspector";       version = "" }
    )
    # Download packages while generating path array
    $script:bins = @{}
    foreach ($pkg in $downloadpkgs) {
        $ver = if ($pkg.version) { "--version $($pkg.version)" } else { "" }
        $before = Get-ChildItem $dest | Select-Object -ExpandProperty FullName
        winget download $pkg.id $ver --download-directory $dest --accept-package-agreements --accept-source-agreements
        $after = Get-ChildItem $dest | Select-Object -ExpandProperty FullName
        $new = $after | Where-Object { $_ -notin $before -and $_ -notmatch '\.yaml$' }
        $script:bins[$pkg.id] = $new
    }

    # Unpack/Install binaries manually
    # DDU
    & "$env:SystemDrive\Program Files\7-Zip\7z.exe" x $script:bins["Wagnardsoft.DisplayDriverUninstaller"] -o"$env:TEMP\WinSux\bin\ddu" -y | Out-Null
    # Nvidia Profile Inspector
    & "$env:SystemDrive\Program Files\7-Zip\7z.exe" x $script:bins["Orbmu2k.nvidiaProfileInspector"] -o"$env:TEMP\WinSux\bin\inspector\" -y | Out-Null
    Copy-Item "$env:TEMP\WinSux\bin\inspector\nvidiaProfileInspector.exe" -Destination "$env:TEMP\WinSux\bin\inspector.exe" 
}

Function GitHubSource{
    Write-Host "Downloading from GitHub`n"
    # Download and extract entire WinSux repo
    $repo = "qrlh/WinSux"
    $zip = "$env:TEMP\WinSux\WinSux.zip"
    IWR "https://github.com/$repo/archive/refs/heads/main.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath "$env:TEMP\WinSux" -Force
    Remove-Item $zip -Force
    # Flatten the extracted WinSux-main subfolder
    Get-ChildItem "$env:TEMP\WinSux\WinSux-main" | Move-Item -Destination "$env:TEMP\WinSux" -Force
    Remove-Item "$env:TEMP\WinSux\WinSux-main" -Recurse -Force

    # install 7zip
    Start-Process -Wait "$env:TEMP\WinSux\bin\7zip.exe" -ArgumentList "/S"

    # install c++
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2005_x86.exe" -ArgumentList "/Q /C:`"msiexec /i vcredist.msi /qn /norestart`"" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2005_x64.exe" -ArgumentList "/Q /C:`"msiexec /i vcredist.msi /qn /norestart`"" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2008_x86.exe" -ArgumentList "/q" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2008_x64.exe" -ArgumentList "/q" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2010_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2010_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2012_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2012_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2013_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2013_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2015_2017_2019_2022_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    Start-Process -Wait "$env:TEMP\WinSux\bin\vcredist2015_2017_2019_2022_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden 

    # extract ddu with 7zip
    & "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$env:TEMP\WinSux\bin\ddu.exe" -o"$env:TEMP\WinSux\bin\ddu" -y | Out-Null

    # install google chrome
    Start-Process -Wait "$env:TEMP\WinSux\bin\chrome.exe" -ArgumentList "--silent --install" -WindowStyle Hidden


    # extract directx with 7zip
    & "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$env:TEMP\WinSux\bin\directx.exe" -o"$env:TEMP\WinSux\bin\directx" -y | Out-Null

    # install directx
    Start-Process -Wait "$env:TEMP\WinSux\bin\directx\DXSETUP.exe" -ArgumentList "/silent" -WindowStyle Hidden
}

$choice = $Host.UI.PromptForChoice(
    'Use WinGet?',
    '(If not binaries from GitHub will be used.)',
    [System.Management.Automation.Host.ChoiceDescription[]](
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "Collect binaries from WinGet"),
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "Collect binaries from WinSux GitHub repository")
    ),
0  # default choice index
)
if ($choice -eq 0) { WinGetSource }
else { GitHubSource }

Write-Host "Staging complete"

Write-Host "7zip config`n"
# set config for 7zip
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
# cleaner 7zip start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

Write-Host "DDU config`n"
# set config for ddu
$DduConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<DisplayDriverUninstaller Version="18.1.4.2">
	<Settings>
		<SelectedLanguage>en-US</SelectedLanguage>
		<RemoveMonitors>True</RemoveMonitors>
		<RemoveCrimsonCache>True</RemoveCrimsonCache>
		<RemoveAMDDirs>True</RemoveAMDDirs>
		<RemoveAudioBus>True</RemoveAudioBus>
		<RemoveAMDKMPFD>True</RemoveAMDKMPFD>
		<RemoveNvidiaDirs>True</RemoveNvidiaDirs>
		<RemovePhysX>True</RemovePhysX>
		<Remove3DTVPlay>True</Remove3DTVPlay>
		<RemoveGFE>True</RemoveGFE>
		<RemoveNVBROADCAST>True</RemoveNVBROADCAST>
		<RemoveNVCP>True</RemoveNVCP>
		<RemoveINTELCP>True</RemoveINTELCP>
		<RemoveINTELIGS>True</RemoveINTELIGS>
		<RemoveOneAPI>True</RemoveOneAPI>
		<RemoveEnduranceGaming>True</RemoveEnduranceGaming>
		<RemoveIntelNpu>True</RemoveIntelNpu>
		<RemoveAMDCP>True</RemoveAMDCP>
		<UseRoamingConfig>False</UseRoamingConfig>
		<CheckUpdates>False</CheckUpdates>
		<CreateRestorePoint>False</CreateRestorePoint>
		<SaveLogs>False</SaveLogs>
		<RemoveVulkan>True</RemoveVulkan>
		<ShowOffer>False</ShowOffer>
		<EnableSafeModeDialog>False</EnableSafeModeDialog>
		<PreventWinUpdate>True</PreventWinUpdate>
		<UsedBCD>False</UsedBCD>
		<KeepNVCPopt>False</KeepNVCPopt>
		<RememberLastChoice>False</RememberLastChoice>
		<LastSelectedGPUIndex>0</LastSelectedGPUIndex>
		<LastSelectedTypeIndex>0</LastSelectedTypeIndex>
	</Settings>
</DisplayDriverUninstaller>
'@
Set-Content -Path "$env:TEMP\WinSux\bin\ddu\Settings\Settings.xml" -Value $DduConfig -Force
# set ddu config to read only
Set-ItemProperty -Path "$env:TEMP\WinSux\bin\ddu\Settings\Settings.xml" -Name IsReadOnly -Value $true

Write-Host "Block driver from Windows Update`n"
# prevent downloads of drivers from windows update
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\DriverSearching`" /v `"SearchOrderConfig`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

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

Write-Host "RESTARTING`n" -ForegroundColor Red

# restart
Start-Sleep -Seconds 5
shutdown -r -t 00
