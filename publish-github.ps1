param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$')]
    [string]$Repository = 'tishe-interior'
)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed. Fix the error above and run the script again." }
}
function Test-CommandSuccess {
    param([string]$Executable, [string[]]$Arguments)
    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments 1>$null 2>$null
        return $LASTEXITCODE -eq 0
    } finally { $ErrorActionPreference = $PreviousPreference }
}
foreach ($CommandName in @('git', 'gh')) {
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        throw "Missing $CommandName. Install Git and GitHub CLI, restart the terminal, then run this script again."
    }
}
if (-not (Test-Path 'dist/index.html') -or -not (Test-Path '.github/workflows/pages.yml')) { throw 'Website files are missing.' }
Write-Host 'Publishing this portfolio concept as a PUBLIC GitHub repository and GitHub Pages site.'
if (-not (Test-CommandSuccess 'gh' @('auth','status','--hostname','github.com'))) {
    Invoke-Checked 'gh' @('auth','login','--hostname','github.com','--git-protocol','https','--web','--scopes','workflow')
}
if (-not (Test-Path Env:GH_TOKEN) -and -not (Test-Path Env:GITHUB_TOKEN)) {
    $AuthStatus = (& gh auth status --hostname github.com 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the GitHub authorization.' }
    if ($AuthStatus -notmatch 'workflow') { Invoke-Checked 'gh' @('auth','refresh','--hostname','github.com','--scopes','workflow') }
}
Invoke-Checked 'gh' @('auth','setup-git','--hostname','github.com')
$Login = & gh api user --jq .login
if ($LASTEXITCODE -ne 0) { throw 'Could not read the authenticated GitHub account.' }
$UserId = & gh api user --jq .id
if ($LASTEXITCODE -ne 0) { throw 'Could not read the GitHub user ID.' }
$FullRepo = "$Login/$Repository"
$ExpectedRemote = "https://github.com/$FullRepo.git"
if (-not (Test-Path '.git' -PathType Container)) {
    if (Test-CommandSuccess 'gh' @('repo','view',$FullRepo,'--json','name')) { throw "Repository $FullRepo already exists. Run this script with -Repository a-different-name." }
    Invoke-Checked 'git' @('init','-b','main')
}
$Branch = & git branch --show-current
if ($LASTEXITCODE -ne 0 -or $Branch -ne 'main') { throw 'This script expects the main branch.' }
$Remotes = @(& git remote)
if ($LASTEXITCODE -ne 0) { throw 'Could not read Git remotes.' }
$HasOrigin = $Remotes -contains 'origin'
$Origin = ''
if ($HasOrigin) {
    $Origin = & git remote get-url origin
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the existing Git remote.' }
}
if ($HasOrigin -and $Origin -ne $ExpectedRemote -and $Origin -ne "git@github.com:$FullRepo.git") { throw 'Existing Git remote points to another repository.' }
Invoke-Checked 'git' @('add','dist','.github','.gitignore','README.md','vercel.json','download-assets.py','publish-github.sh','publish-github.ps1')
& git diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    Invoke-Checked 'git' @('-c',"user.name=$Login",'-c',"user.email=$UserId+$Login@users.noreply.github.com",'commit','-m','Add interior studio portfolio landing page')
} elseif ($LASTEXITCODE -ne 0) { throw 'Could not inspect staged changes.' }
if ($HasOrigin) {
    Invoke-Checked 'git' @('push','--set-upstream','origin','main')
} else {
    Invoke-Checked 'gh' @('repo','create',$FullRepo,'--public','--description','Interior design studio landing page - portfolio concept','--source','.','--remote','origin','--push')
}
if (Test-CommandSuccess 'gh' @('api',"repos/$FullRepo/pages")) {
    Invoke-Checked 'gh' @('api','--method','PATCH',"repos/$FullRepo/pages",'-f','build_type=workflow') | Out-Null
} else {
    Invoke-Checked 'gh' @('api','--method','POST',"repos/$FullRepo/pages",'-f','build_type=workflow') | Out-Null
}
$PreviousRunId = & gh run list --repo $FullRepo --workflow pages.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // empty'
if ($LASTEXITCODE -ne 0) { throw 'Could not read existing deployment workflows.' }
Invoke-Checked 'gh' @('workflow','run','pages.yml','--repo',$FullRepo,'--ref','main')
$RunId = ''
for ($Attempt = 0; $Attempt -lt 15; $Attempt++) {
    $RunId = & gh run list --repo $FullRepo --workflow pages.yml --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // empty'
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the deployment workflow.' }
    if ($RunId -and $RunId -ne $PreviousRunId) { break }
    Write-Host 'Waiting for the deployment workflow...'
    Start-Sleep -Seconds 2
}
if (-not $RunId -or $RunId -eq $PreviousRunId) { throw "Workflow requested. Check https://github.com/$FullRepo/actions" }
Invoke-Checked 'gh' @('run','watch',$RunId,'--repo',$FullRepo,'--exit-status')
$DemoUrl = & gh api "repos/$FullRepo/pages" --jq .html_url
if ($LASTEXITCODE -ne 0) { throw 'Deployment completed, but the demo URL could not be read.' }
Write-Host "`nRepository: https://github.com/$FullRepo"
Write-Host "Demo: $DemoUrl"
