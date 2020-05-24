$functions = @(
    @{ Module = "PlasticBisect"; Name = "Invoke-PlasticBisect"; Alias = "pbisect" }
    @{ Module = "HigherOrderFunctions"; Name = "Invoke-InDirectory" }
    @{ Module = "HigherOrderFunctions"; Name = "Invoke-InChangeset" }
);

foreach ($function in $functions) {
    . "$PSScriptRoot\$($function.Module)\$($function.Name).ps1"
    if ($function.Alias) {
        New-Alias -Name $function.Alias -Value $function.Name;
        Export-ModuleMember -Function $function.Name -Alias $function.Alias;
    } else {
        Export-ModuleMember -Function $function.Name;
    }
}
