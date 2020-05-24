function Invoke-InDirectory {
    <#
    .SYNOPSIS
        Runs a script block inside a directory, then returns.
    .DESCRIPTION
        Runs a script block inside a directory. Once finished, it restores the
        location at the time of invocation.
    .PARAMETER DirectoryPath
        The path of the directory in which to run the ScriptBlock.
    .PARAMETER ScriptBlock
        The ScriptBlock to run in the directory.
    .EXAMPLE
        Invoke-InDirectory ".\src\project" {
            dotnet publish -o ..\..\bin
        }
    .NOTES
        Author:     Sergio Luis Para
        Date:       May 24th, 2020
    #>
    param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            HelpMessage = "The path of the directory in which to run the ScriptBlock."
        )]
        [string]$DirectoryPath,

        [Parameter(
            Mandatory = $True,
            Position = 1,
            HelpMessage = "The ScriptBlock to run in the directory."
        )]
        [ScriptBlock]$ScriptBlock
    )

    PROCESS {
        [string]$currentPath = $(Get-Location).Path;
        try {
            Set-Location -Path $DirectoryPath;
            return &$ScriptBlock;
        } finally {
            Set-Location -Path $currentPath;
        }
    }
}
