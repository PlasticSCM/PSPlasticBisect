[string]$CsetIdFindQuery = "changesets where branch = '{0}' and changesetid >= {1} and changesetid <= {2}";

[string]$CmFindFormat = "{changesetid}@#@{date}@#@{guid}@#@{owner}";
[string]$CmFindFormatRegex = "(?<csetId>[0-9]+)@#@(?<date>[0-9/ :]+)@#@(?<guid>[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})@#@(?<owner>[a-zA-Z0-9 @\.]+)";

function Find-ChangesetsById {
    param(
        [Parameter(
            Mandatory = $True,
            HelpMessage = "The cm.exe executable to use for the find operation."
        )]
        [string]$CmExePath,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The name of the branch."
        )]
        [string]$BranchName,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The minimum cset id for the search."
        )]
        [string]$MinimumChangesetId,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The maximum cset id for the search."
        )]
        [string]$MaximumChangesetId
    )

    PROCESS {
        [string]$cmFindQuery = (
            $CsetIdFindQuery -f $BranchName, $MinimumChangesetId, $MaximumChangesetId
        );

        return Find-Changesets `
            -CmExePath $CmExePath `
            -CmFindQuery $cmFindQuery;
    }
}

function Find-Changesets {
    param(
        [Parameter(
            Mandatory = $True,
            HelpMessage = "The cm.exe executable to use for the find operation."
        )]
        [string]$CmExePath,

        [Parameter(
            Mandatory = $True,
            HelpMessage = "The query to run."
        )]
        [string]$CmFindQuery
    )

    PROCESS {
        [string[]]$findResult =
            &$CmExePath find $CmFindQuery --format="$CmFindFormat" --nototal;

        [PSCustomObject[]]$result = $findResult | ForEach-Object {
            ConvertTo-ChangesetObject -CmFindLine $_
        };

        return $result;
    }
}

function ConvertTo-ChangesetObject {
    param(
        [Parameter(
            Mandatory = $True,
            HelpMessage = "A line from the 'cm find' query result."
        )]
        [string]$CmFindLine
    )

    PROCESS {
        if ($CmFindLine -match $CmFindFormatRegex) {
            return [PSCustomObject]@{
                CsetId = [int]::Parse($Matches.csetId)
                Owner = $Matches.owner
                Guid = [Guid]::Parse($Matches.guid)
                Date = [DateTime]::Parse($Matches.date)
            }
        }

        return $Null;
    }
}
