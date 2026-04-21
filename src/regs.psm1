$keys = [PSCustomObject]@{
    allowScripts = [PSCustomObject]@{
        add = @(
            '"HKCR\\Applications\\powershell.exe\\shell\\open\\command" /ve /t REG_SZ /d "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -NoLogo -ExecutionPolicy unrestricted -File \\"%%1\\"" /f >nul 2>&1'
            '"HKCU\\SOFTWARE\\Microsoft\\PowerShell\\1\\ShellIds\\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Restricted" /f >nul 2>&1'
            '"HKCU\\SOFTWARE\\Microsoft\\PowerShell\\1\\ShellIds\\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Unrestricted" /f >nul 2>&1'
            '"HKLM\\SOFTWARE\\Microsoft\\PowerShell\\1\\ShellIds\\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Restricted" /f >nul 2>&1'
            '"HKLM\\SOFTWARE\\Microsoft\\PowerShell\\1\\ShellIds\\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Unrestricted" /f >nul 2>&1'
        )
        remove = @(
            '"HKCR\\Applications\\powershell.exe" /f >nul 2>&1'
            '"HKCR\\ps1_auto_file" /f >nul 2>&1'
        )
    }
    browser = [PSCustomObject]@{
        chrome = [PSCustomObject]@{
            add = @(
                '"HKLM\\SOFTWARE\\Policies\\Google\\Chrome/" /v /"BackgroundModeEnabled/" /t REG_DWORD /d /"0/" /f >nul 2>&1"'
                '"HKLM\\SOFTWARE\\Policies\\Google\\Chrome/" /v /"HardwareAccelerationModeEnabled/" /t REG_DWORD /d /"0/" /f >nul 2>&1"'
                '"HKLM\\SOFTWARE\\Policies\\Google\\Chrome/" /v /"HighEfficiencyModeEnabled/" /t REG_DWORD /d /"1/" /f >nul 2>&1"'
                '"HKLM\\SOFTWARE\\Policies\\Google\\Chrome\\ExtensionInstallForcelist/" /v /"1/" /t REG_SZ /d /"ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx/" /f >nul 2>&1"'
            )
            remove = @()
        }
        edge = @()
    }

}
