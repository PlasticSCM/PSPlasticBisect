function Invoke-InChangeset {
    <#
    .SYNOPSIS
        Runs a script block in a given changeset, then returns.
    .DESCRIPTION
        Runs a script block in a given changeset. Once finished, you have the
        option of restoring the changeset the workspace was pointing to before
        the operation.
    .PARAMETER CmExePath
        The cm.exe executable to use for the find operation.
    .PARAMETER ChangesetId
        The id of the changeset the workspace should be pointing to before
        running the ScriptBlock.
    .Parameter ScriptBlock
        The ScriptBlock to run once the workspace is pointing to the given
        changeset.
    .PARAMETER ResultCapture
        An object to capture the result of the ScriptBlock.
    .PARAMETER RestoreWorkspace
        Whether or not to restore the workspace to its initial state once
        finished.
    .EXAMPLE
        [PSCustomObject]$captureResult = [PSCustomObject]@{
            ObjectFound = $False
            Size = 0
        };

        Invoke-InChangeset -ChangesetId 32 -ScriptBlock {
            param([PSCustomObject]$ResultCapture)

            if ($(TestPath -Path '.\releases\9.0.16.4255)) {
                Write-Verbose 'Found the release!';
                $ResultCapture.ObjectFound = $True;
                $ResultCapture.Size = (Get-Item .\releases\9.0.16.4255\release.exe).Length;
            } else {
                Write-Verbose 'Did not find the release.';
                $ResultCapture.ObjectFound = $False;
            }
        } -ResultCapture $captureResult;
    .NOTES
        The function will NOT attempt to undo changes before switching
        the workspace back and forth!
    .NOTES
        Author:     Sergio Luis Para
        Date:       May 24th, 2020
    #>
    param(
        [Parameter(
            HelpMessage = "The cm.exe executable to use for the find operation."
        )]
        [string]$CmExePath,

        [Parameter(
            Mandatory = $True,
            Position = 0,
            HelpMessage = "The id of the changeset the workspace should be pointing to before running the ScriptBlock."
        )]
        [int]$ChangesetId,

        [Parameter(
            Mandatory = $True,
            Position = 1,
            HelpMessage = "The ScriptBlock to run once the workspace is pointing to the given changeset."
        )]
        [ScriptBlock]$ScriptBlock,

        [Parameter(
            Mandatory = $True,
            Position = 2,
            HelpMessage = "An object to capture the result of the ScriptBlock."
        )]
        [PSCustomObject]$ResultCapture,

        [Parameter(
            HelpMessage = "Whether or not to restore the workspace to its initial state once finished."
        )]
        [Switch]$RestoreWorkspace
    )

    PROCESS {
        Write-Verbose "Switching workspace to cs:$ChangesetId";

        $workspaceLocation = &$CmExePath status --cset;
        &$CmExePath switch cs:$ChangesetId | Out-Null;
        try {
            $ScriptBlock.Invoke($ResultCapture) | Out-Null;
        } finally {
            if ($RestoreWorkspace) {
                &$CmExePath switch $workspaceLocation;
            }
        }
    }
}
