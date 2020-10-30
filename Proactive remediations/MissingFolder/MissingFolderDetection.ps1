$Folder - "C:\resource"
try {
    if (Test-Path -Path $Folder -ErrorAction SilentlyContinue) {
        Write-Host "All Intune Resource Files are Present"
        Exit 0
    }
    Else {
        Write-Warning "Intune Resource files missing Georges Fualt"
        Exit 1
    }
}
Catch {
    Write-Warning $_
    Exit 1
}