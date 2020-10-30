$Folder = "C:\Resource"
try {
    New-item -path $Folder -ItemType Directory -Force | Out-Null
    if (test-Path $folder -ErrorAction SilentlyContinue) {
            Exit 0
    }
    Else {
        Exit 1
    }
}
catch {
    exit 1
}