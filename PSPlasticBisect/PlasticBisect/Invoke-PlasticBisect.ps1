. $PSScriptRoot\..\CmWrapper\CmWrapper.ps1
. $PSScriptRoot\..\HigherOrderFunctions\Invoke-InChangeset.ps1
. $PSScriptRoot\..\HigherOrderFunctions\Invoke-InDirectory.ps1

enum TestResult {
    Correct
    Incorrect
    Unknown
    Fatal
}

function Invoke-PlasticBisect {
    <#
    .SYNOPSIS
        Launches a bisect operation in a workspace.
    .DESCRIPTION
        Launches a bisect operation in a given workspace, for a given branch,
        between two given changesets.
    .PARAMETER WorkspaceRoot
        The root directory of the workspace to run the bisect into.
    .PARAMETER BranchName
        The name of the branch to bisect.
    .PARAMETER MinimumCsetId
        The minimum cset id in which to run the bisect (a.k.a. Correct changeset).
    .PARAMETER MaximumCsetId
        The maximum cset id in which to run the bisect (a.k.a. Incorrect changeset).
    .PARAMETER TestScript
        The script to run in every cset.
        You don't need to switch your workspace in said cset.
        Your script needs to receive one 'PSCustomObject' parameter and set the
        result in its 'Result' property.
        The result must be a member of the [TestResult] enum.
    .PARAMETER CmExePath
        The path of the 'cm.exe' executable to use during the bisect process.
    .EXAMPLE
        Invoke-PlasticBisect `
            -WorkspaceRoot C:\Users\sergi\wkspaces\codice `
            -BranchName 'main'`
            -MinimumCsetId 157892 `
            -MaximumCsetId 157950 `
            -TestScript {
                param([PSCustomObject]$ResultCapture)
                Invoke-InDirectory ".\01plastic\build\server" {
                    Write-Verbose "Executing 'compile-nunit' target.";
                    .\nant compile-nunit;
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Could not compile the target";
                        $ResultCapture.Result = [TestResult]::Fatal;
                        return;
                    }
                }

                Invoke-InDirectory ".\02nervathirdparty\nunit\net-4.0" {
                    Write-Verbose "Testing 'nunitserver.dll'";
                    .\nunit-console.exe /run:DataQueryRepositoryTests ..\01plastic\bin\server\nunitserver.dll /noshadow;
                    if ($LASTEXITCODE -eq 0) {
                        Write-Verbose "Changeset tested CORRECT.";
                        $ResultCapture.Result = [TestResult]::Correct;
                    } else {
                        Write-Verbose "Changeset tested INCORRECT.";
                        $ResultCapture.Result = [TestResult]::Incorrect;
                    }
                }
            }
    .NOTES
        Author:     Sergio Luis Para
        Date:       May 17th, 2020
    #>
    param(
        [Parameter(
            Mandatory = $True,
            HelpMessage = "The root directory of the workspace to run the bisect into."
        )]
        [string]$WorkspaceRoot,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The name of the branch to bisect."
        )]
        [string]$BranchName,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The minimum cset id in which to run the bisect (a.k.a. Correct changeset)"
        )]
        [int]$MinimumCsetId,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The maximum cset id in which to run the bisect (a.k.a. Incorrect changeset)."
        )]
        [int]$MaximumCsetId,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The script to run in every cset."
        )]
        [scriptblock]$TestScript,

        [Parameter(
            HelpMessage = "The path of the 'cm.exe' executable to use during the bisect process."
        )]
        [string]$CmExePath = "cm.exe"
    )

    PROCESS {
        return Invoke-InDirectory $WorkspaceRoot {
            [PSCustomObject[]]$changesets = Find-ChangesetsById `
                -CmExePath $CmExePath `
                -BranchName $BranchName `
                -MinimumChangesetId $MinimumCsetId `
                -MaximumChangesetId $MaximumCsetId;

            Write-Verbose "Found $($changesets.Count) changesets to test.";

            [ScriptBlock]$testScriptBlock = {
                param(
                    [PSCustomObject]$Changeset,
                    [PSCustomObject]$ResultCapture
                )
                Invoke-InChangeset `
                    -CmExePath $CmExePath `
                    -ChangesetId $Changeset.CsetId `
                    -ScriptBlock $TestScript `
                    -ResultCapture $ResultCapture;
            };

            [PSCustomObject]$result = Invoke-Bisect `
                -Items $changesets `
                -LowerBound 0 `
                -UpperBound $($changesets.Length - 1) `
                -TestScriptBlock $testScriptBlock;

            Write-Verbose "Result: $result";

            return $result;
        }
    }
}

function Invoke-Bisect {
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject[]]$Items,

        [Parameter(Mandatory = $True)]
        [int]$LowerBound,

        [Parameter(Mandatory = $True)]
        [int]$UpperBound,

        [Parameter(Mandatory = $True)]
        [scriptblock]$TestScriptBlock
    )

    PROCESS {
        if ($UpperBound -eq ($LowerBound + 1)) {
            [PSCustomObject]$result = $Items[$UpperBound];
            Write-Verbose "Found a result: $result";
            return $result;
        }

        [int]$nextItem = $LowerBound + (($UpperBound - $LowerBound) / 2);
        [PSCustomObject]$nextItemToTest = $Items[$nextItem];

        [PSCustomObject]$resultCapture = [PSCustomObject]@{
            Result = [TestResult]::Unknown
        };

        Write-Verbose "Testing item $nextItemToTest";
        $TestScriptBlock.Invoke($Items[$nextItem], $resultCapture);
        Write-Verbose "Tested $nextItemToTest`: [$($resultCapture.Result)]";

        [HashTable]$nextRunArguments = @{
            Items = $Items
            LowerBound = $(
                if ($resultCapture.Result -eq [TestResult]::Correct) {
                    $nextItem
                } else {
                    $LowerBound
                })
            UpperBound = $(
                if ($resultCapture.Result -eq [TestResult]::Incorrect) {
                    $nextItem
                } else {
                    $UpperBound
                })
            TestScriptBlock = $TestScriptBlock
        };

        Write-Verbose "Running again...";
        Invoke-Bisect @nextRunArguments;
    }
}




