# PSPlasticBisect

A PowerShell function to bisect your Plastic SCM repository

![](https://raw.githubusercontent.com/PlasticSCM/PSPlasticBisect/master/img/invoke-plasticbisect-example.gif)

## How to set this up

This module has not been published yet. To get it working, do the following (customize commands as necessary!):

1. Check the directory where your PowerShell install looks for its profile:

```powershell
PS> $PROFILE
C:\Users\sergi\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

2. Clone this repository somewhere:

```powershell
PS> git clone https://github.com/PlasticSCM/PSPlasticBisect C:\PSPlasticBisect
```

3. Copy the PSPlasticBisect directory from the cloned repository to where your PowerShell install looks for modules:

```powershell
PS> Copy-Item `
  -Path C:\PSPlasticBisect\PSPlasticBisect `
  -Destination C:\Users\sergi\OneDrive\Documents\PowerShell\Modules\
```

4. Import the module:

```powershell
PS> Import-Module -Name PSPlasticBisect -Force
```

5. That's all!

## What is a *bisect*?

When talking VCS, a _bisect_ is finding the changeset where a bug was introduced, using binary search.

You can do so by hand, but as developers, we tend to ask computers to do the heavy lifting.

## How to use `Invoke-PlasticBisect`

To use `Invoke-PlasticBisect` (and in general to bisect any repository) you only need to know two things: a changeset where there is no bug, and a changeset where there is.

We will work with two silly but important assumptions:

* Time only goes forward.

* We want to know the changeset where a bug was introduced, and not where it was fixed.

Under these two assumptions, the oldest changeset will be the one where everything worked OK (the _correct_ changeset), whilst the newest one will be the one where something fails (the _incorrect_ changeset).

Take a look at this repository I prepared. In the example, the _correct changeset id_ will be `0`, and the _incorrect changeset id_ will be `10`.

![](https://raw.githubusercontent.com/PlasticSCM/PSPlasticBisect/master/img/bisect-repository-example.png)

Because the bisect operation implements a binary search, these are the changesets that will get tested:

![](https://raw.githubusercontent.com/PlasticSCM/PSPlasticBisect/master/img/bisect-tested-csets.gif)

We will test each changeset using a `ScriptBlock`. Said ScriptBlock must receive a parameter of type `PSCustomObject`, and we will set the result of testing the changeset in its `Result` member. This `Result` must be a member of `TestResult` enum (`[TestResult]::Correct`, `[TestResult]::Incorrect` or `[TestResult]::Fatal`).

We **do NOT** need to worry to set the workspace - the bisect implementation takes care of that.

So take this as an example: in each one of the tests, I will run `dotnet test`  and set the result depending on its exit code:

```powershell
{
    param([PSCustomObject]$ResultCapture)
    cd ".\src\test"
    dotnet test
    if ($LASTEXITCODE -eq 0) {
        $ResultCapture.Result = [TestResult]::Correct;
    } else {
        $ResultCapture.Result = [TestResult]::Incorrect;
    }
}
```

You have a helper _higher-ish_ order function named `Invoke-InDirectory`. Also, if you are using the latest PowerShell 7 you can use the ternary operator, so we can nicely wrap it like this:

```powershell
{
    param([PSCustomObject]$ResultCapture)
    Invoke-InDirectory ".\src\test" {
        dotnet test
        $ResultCapture.Result = ($LASTEXITCODE -eq 0) ? [TestResult]::Correct : [TestResult]::Incorrect;
    }
}
```

Putting all of the pieces together:

```powershell
PS> Invoke-PlasticBisect `
    -WorkspaceRoot "C:\Users\sergi\wkspaces\bisect-example" `
    -BranchName 'main' `
    -MininumCsetId 0 `
    -MaximumCsetId 10 `
    -TestScript {
        param([PSCustomObject]$ResultCapture)
        Invoke-InDirectory ".\src\test" {
            dotnet test
            $ResultCapture.Result = ($LASTEXITCODE -eq 0) `
                ? [TestResult]::Correct `
                : [TestResult]::Incorrect;
        }
    }
```

If you specify the `-Verbose` flag, you will see information about what's happening behind the scenes!

## Caveats

* The function does not ensure a clean workspace (this is, without private files). If you want a clean workspace before each test run, it is your responsibility to clean it up at the beginning of the `TestScript` .

* This module does not have any test! Pull requests implementing tests are more than welcome.

* The bisect works in a single branch - it does not follow mergelinks. It would be really nice if it did, though!
  
  * You start testing branch `main`.
  
  * The bisect detects that the changeset where the bug appeared has an incoming mergelink from `main/scm25600`.
  
  * The bisect follows the mergelink to the source branch `main/scm25600` and starts testing it.
    
    * It would be even nicer if the bisect was able to follow parent branches too, in case the bug was not introduced in a branch, but in its parent.
