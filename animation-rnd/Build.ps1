param(
    [string]$Python = 'python',
    [switch]$InstallDependencies,
    [switch]$PrepareOnly,
    [switch]$Validate
)
$ErrorActionPreference = 'Stop'
if ($InstallDependencies) {
    & $Python -m pip install --disable-pip-version-check --target (Join-Path $PSScriptRoot '.deps') -r (Join-Path $PSScriptRoot 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$pipelineArgs = @((Join-Path $PSScriptRoot 'scripts\pipeline.py'))
if ($PrepareOnly) { $pipelineArgs += '--prepare-only' }
& $Python @pipelineArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($Validate -and -not $PrepareOnly) {
    & $Python (Join-Path $PSScriptRoot 'scripts\validate.py')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
