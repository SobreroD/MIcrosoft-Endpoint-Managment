try{
    Add-VpnConnection -Name "VPN" -ServerAddress "VPN.Contoso.loc" -TunnelType L2TP -L2tpPsk "SecretPassword" -Force -AuthenticationMethod PAP -RememberCredential -AllUserConnection -ErrorAction Stop
    exit 0
}
catch{
    $errMsg = $_.Exception.Message
    Write-host $errMsg
    exit 1
}