<#Requires -Version 7.0
<#   


 Prepare .admx files for use in Microsoft Endpoint Management Policies
 Use: Get-Intune_OMAfromAdmx.ps1

 Change Log

History:
	10/23/2020 Script Created by Nick Bowen @Bitflipper.tech
    And Donovan M Sobrero Donovan@networkmechanics.net

File Location: https://github.com/SobreroD/MIcrosoft-Endpoint-Managment/upload/main/Tools/OMA-URI_FromAMDX
       
 .SYNOPSIS
    Prompts the user with GUI Windows Explorer to find ADMX File.

    OMA-URI Format

    ./{user or device}/Vendor/MSFT/Policy/Config/{AreaName}/{PolicyName}

.EXAMPLE Mac
        .\Get-MDMFromAdmx.ps1 -AdmxPath  .\admx\chrome.admx

.EXAMPLE Windows
        .\Get-MDMFromAdmx.ps1


#>
Clear-Host
#------------------------ Setup Script ------------------------------------------------------------------------------------

#-------------- Dependency Check -------------------------------------------------------------------------------------------



# Ensure we have ImportExcel Module installed and loaded for output
if (Get-Module -ListAvailable -Name ImportExcel) {
    Write-Host "Checking if ImportExcel PS Module is installed" -ForegroundColor Green
    Write-Host "Module exists" -ForegroundColor RED
  } else {
    Write-Host "O this is your first time running this script." -ForegroundColor Green
    Write-Host "Let's get you all setup and install the missing Module for you." -ForegroundColor Green
    Install-Module -Name ImportExcel
  }

#-------------- Dependency Check section END ------------------------------------------------------------------------------

#------------ Functions START ---------------------------------------------------------------------------------------------
# WIndows GUI Select File>
#--------------------------------------------------------------------------------------------------------------------------
#>

Add-Type -AssemblyName System.Windows.Forms
$openFileDialog = New-Object windows.forms.openfiledialog   
$openFileDialog.initialDirectory = [System.IO.Directory]::GetCurrentDirectory()   
$openFileDialog.title = "Select Windows Policy ADMX file Location to Import"   
$openFileDialog.filter = "All files (*.*)| *.*"   
$openFileDialog.filter = "Policy ADMX Files|*.ADMX|All Files|*.*" 
$openFileDialog.ShowHelp = $True   
Write-Host "Select Policy ADMX File... (see FileOpen Dialog)" -ForegroundColor Green  
$result = $openFileDialog.ShowDialog()   # Display the Dialog / Wait for user response 
# in ISE you may have to alt-tab or minimize ISE to see dialog box 
$result 
if($result -eq "OK") {    
        Write-Host "Selected ADMX File:"  -ForegroundColor Green  
$AdmxPath = $OpenFileDialog.filename
        Write-Host "Processing" -ForegroundColor Red
        Write-Host "Windows ADMX File Exstracted Intune OMA-URI info Complete!" -ForegroundColor Green 
        Write-Host "Excel File located @ below Location:" -ForegroundColor Green 
        Write-Host $AdmxPath -ForegroundColor Yellow
        Write-Host " "
}
    else { Write-Host "Windows ADMX File Cancelled!" -ForegroundColor Yellow} 

<# Don't move this up as we need it to run as administrator and part of the make script#>

function Get-ADMXFile {
    [CmdletBinding()]
param (
   [parameter(Mandatory=$false)][String]$AdmxPath,
   [parameter(Mandatory=$false)][boolean]$EnableDebugMsgs=$false
)
# import Module importExcel to export Excel file without M$ Excel on Device
Import-Module ImportExcel

#if ($Dev -or $EnableDebugMsgs) {
	$DebugPreference = "Continue"	# Write-Debug statements will be written to console
#}
end {}
}
# Platform Dependent Path Separator (ie. \ or /)
$PathSep = [IO.Path]::DirectorySeparatorChar

if (-not (Test-Path -Path $AdmxPath)) {
    Write-Output "ADMX File Missing ($AdmxPath)"
    exit 1
}

$DefaultLang = "en-us"
$AdmxFileObj = Get-ChildItem -Path $AdmxPath
$AdmxFile = $AdmxFileObj.FullName
$AdmlName = $AdmxFileObj.Name -replace '\.admx$','.adml'
$AdmlDir = $AdmxFileObj.Directory.FullName
$AdmlFile = "$AdmlDir$PathSep$AdmlName"
if (-not (Test-Path -Path $AdmlFile)) {
    $AdmlDirAlt = "$AdmlDir$PathSep$DefaultLang"
    $AdmlFileAlt = "$AdmlDirAlt$PathSep$AdmlName"
    if (-not (Test-Path -Path $AdmlFileAlt)) {
        Write-Output "ADML File Missing.  Should be located in either: `n$AdmlFile `n$AdmlFileAlt)"
        exit 1
    } else {
        $Local:AdmlFile = $AdmlFileAlt
    }
}
$ExcelName = $AdmxFileObj.Name -replace '\.admx$','.xlsx'
$ExcelPath = "$AdmlDir$PathSep$ExcelName"

function Get-AreaName {
    [CmdletBinding()]
    param (
        [parameter(mandatory=$true)][System.Xml.XmlDocument]$ADMX    
    )
    begin {}
    process {
        # The {AreaName} format is {AppName}~{SettingType}~{CategoryPathFromAdmx}
        try {
            $AppName = $ADMX.policyDefinitions.policyNamespaces.target.prefix
            $Categories = @{}           
            $ADMX.policyDefinitions.categories.category | ForEach-Object {
                # Using child::node() was more reliable thatn using parentCategory for -XPath
                if ([bool](Select-Xml -Xml $_ -XPath 'child::node()')) {
                    $Categories.Add($_.name,$_.parentCategory.ref)
                } else {                    
                    $Categories.Add($_.name,$_.name)
                }
            }
            $ParentCategories = @()
            $Categories.GetEnumerator() | ForEach-Object {
                # Test for Parent Categories
                if (-not $Categories.ContainsKey($_.Value)) {
                    $ParentCategories += $_.Key
                }
            }
            $ParentCategories | ForEach-Object { $Categories[$_] = $_ }
            $Keys = @()
            $Categories.Keys | ForEach-Object { $Keys += $_ }
            foreach ($Key in $Keys) {    
                if ($Categories[$Key] -eq $Key) {
                    $Categories[$Key] = "$AppName~Policy~$Key"
                } else {
                    $Categories[$Key] = "$AppName~Policy~$($Categories[$Key])~$Key"
                }
            }           
            $Categories
        } catch {
            $PositionStr = $_.InvocationInfo.PositionMessage -replace '\r\n\+.*','' -replace '\n\+.*',''
            $ExceptionClean = $_.Exception.Message -replace '\r\n\+.*','' -replace '\n\+.*',''
            Write-Debug $PositionStr
            Write-Debug $ExceptionClean
        }       
    }
    end {}
}

function Get-Policies {
    [CmdletBinding()]
    param (
        [parameter(mandatory=$true)][System.Xml.XmlDocument]$ADMX,
        [parameter(mandatory=$true)][System.Xml.XmlDocument]$ADML,
        [parameter(mandatory=$true)][Hashtable]$AreaName
    )
    begin {}
    process {
        # The {AreaName} format is {AppName}~{SettingType}~{CategoryPathFromAdmx}
        try {
            $Policies = @()
            $ADMX.policyDefinitions.policies.policy | ForEach-Object {
                $PolicyDetails = $_
                $Help = ""
                $Value = "<enabled/>"
                if ($null -ne (Select-Xml -Xml $PolicyDetails -XPath '@explainText')) {
                    $ADLMID = $PolicyDetails.explainText -replace '.*string\.','' -replace '\)|\(',''
                    $HelpTemp = ($ADML.policyDefinitionResources.resources.stringTable.string | Where-Object { $_.id -eq $ADLMID }).'#text'
                    $Local:Help = $HelpTemp -replace ',',' '
                }                   
                if ([bool](Select-Xml -Xml $PolicyDetails -XPath 'elements/enum')) {                    
                    $ValueTemp = ""
                    if([bool](Select-Xml -Xml $PolicyDetails -XPath 'elements/enum/item/value/decimal')) {
                        $PolicyDetails.elements.enum.item.value.decimal | ForEach-Object {  
                            $Local:ValueTemp += "`n<data id=`"$($PolicyDetails.elements.enum.valueName)`" value=`"$([int]$_.value)`"/>"
                        }                        
                    } elseif ([bool](Select-Xml -Xml $PolicyDetails -XPath 'elements/enum/item/value/string')) {
                        $PolicyDetails.elements.enum.item.value.string | ForEach-Object {                            
                            $Local:ValueTemp += "`n<data id=`"$($PolicyDetails.elements.enum.valueName)`" value=`"$($_)`"/>"
                        }                           
                    }
                    $Local:Value += $ValueTemp
                }
                Switch -regex ($_.class) {
                    'User|Both' {
                        $PolicyObj = [PSCustomObject]@{
                            name   = $PolicyDetails.name
                            omauri = "./User/Vendor/MSFT/Policy/Config/$($AreaName[$PolicyDetails.parentCategory.ref])/$($PolicyDetails.name)"
                            value  = $value
                            help   = $Help
                            scope  = "user"
                        }
                        $Policies += $PolicyObj
                    }
                    'Device|Machine|Both' {
                        $PolicyObj = [PSCustomObject]@{
                            name   = $PolicyDetails.name
                            omauri = "./Device/Vendor/MSFT/Policy/Config/$($AreaName[$PolicyDetails.parentCategory.ref])/$($PolicyDetails.name)"
                            value  = $value
                            help   = $Help
                            scope  = "device"
                        }
                        $Policies += $PolicyObj
                    }
                }
                # <enabled/>	<data id=""BrowserSignin"" value=""0""/>                
            }
            $Policies
        } catch {
            $PositionStr = $_.InvocationInfo.PositionMessage -replace '\r\n\+.*','' -replace '\n\+.*',''
            $ExceptionClean = $_.Exception.Message -replace '\r\n\+.*','' -replace '\n\+.*',''
            Write-Debug $PositionStr
            Write-Debug $ExceptionClean
        }       
    }
    end {}
}

try {
    $ADMX = [xml](Get-Content -Path $AdmxFile)
    $ADML = [xml](Get-Content -Path $AdmlFile)
    
    $AreaName = Get-AreaName -ADMX $ADMX
    $AllPolicies = Get-Policies -ADMX $ADMX -ADML $ADML -AreaName $AreaName
    
    if (Test-Path $ExcelPath) {
        Remove-Item $ExcelPath -Force
    }
    
    $Excel = $AllPolicies | Where-Object { $_.scope -eq 'user' } | Export-Excel -Path $ExcelPath -WorksheetName "User" -AutoSize -AutoFilter -PassThru
    Set-Format -Address $Excel.Workbook.Worksheets["User"].Cells -WrapText -VerticalAlignment Top
    Close-ExcelPackage $Excel 

    $Excel = $AllPolicies | Where-Object { $_.scope -eq 'device' } | Export-Excel -Path $ExcelPath -WorksheetName "Device" -AutoSize -AutoFilter -PassThru
    Set-Format -Address $Excel.Workbook.Worksheets["Device"].Cells -WrapText -VerticalAlignment Top
    Close-ExcelPackage $Excel 

    #$AllPolicies | Where-Object { $_.scope -eq 'user' }  | Export-Excel -Path $ExcelPath -WorksheetName "User" -AutoSize -AutoFilter
    #$AllPolicies | Where-Object { $_.scope -eq 'device' } | Export-Excel -Path $ExcelPath -WorksheetName "Device" -AutoSize -AutoFilter   
} catch {
    $PositionStr = $_.InvocationInfo.PositionMessage -replace '\r\n\+.*','' -replace '\n\+.*',''
    $ExceptionClean = $_.Exception.Message -replace '\r\n\+.*','' -replace '\n\+.*',''
    Write-Debug $PositionStr
    Write-Debug $ExceptionClean
}    

