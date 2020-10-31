<#
By Donovan Sobrero
Date: 10/30/202
check if software is installed
$software = what is shown in add remove programs
#>

$software = "Vmware Workstation";
$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -eq $software }) -ne $null

If(-Not $installed) {
    # checked and was successfull
	Write-Host "'$software' NOT is installed.";
} else {
    # so Something
	Write-Host "'$software' is installed."
}