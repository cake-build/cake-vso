Param(
    [string]$Script,
    [string]$Target,
    [string]$Verbosity,
    [string]$Arguments
)

Write-Verbose "Parameters:";
foreach($key in $PSBoundParameters.Keys)
{
    Write-Verbose ($key + ' = ' + $PSBoundParameters[$key]);
}

Import-Module "Microsoft.TeamFoundation.DistributedTask.Task.Internal";
Import-Module "Microsoft.TeamFoundation.DistributedTask.Task.Common";

$RootPath = Split-Path -parent $Script;
$ToolPath = Join-Path $RootPath "tools";
$PackagePath = Join-Path $ToolPath "packages.config";
$CakePath = Join-Path $ToolPath "Cake/Cake.exe";
$NuGetPath = Join-Path $ToolPath "nuget.exe";

Write-Verbose "=============================================="
Write-Verbose "Root = $RootPath";
Write-Verbose "Tools = $ToolPath";
Write-Verbose "Packages = $PackagePath";
Write-Verbose "Cake = $CakePath";
Write-Verbose "NuGet = $NuGetPath";
Write-Verbose "=============================================="

# Check if there's a tools directory.
if (!(Test-Path $ToolPath)) {
    Write-Verbose "Creating tools directory...";
    New-Item -Path $ToolPath -Type Directory | Out-Null;
    if (!(Test-Path $ToolPath)) {
        Throw "Could not create tools directory.";
    }
}

# Make sure NuGet exist.
if (!(Test-Path $NuGetPath)) {
  # Download NuGet.exe.
  Write-Verbose "Downloading nuget.exe...";
  (New-Object System.Net.WebClient).DownloadFile("https://nuget.org/nuget.exe", $NuGetPath);
  # Make sure it was properly downloaded.
  if (!(Test-Path $NuGetPath)) {
      Throw "Could not find nuget.exe";
  }
}

# Install prereqs from NuGet.
Push-Location;
Set-Location $ToolPath;
if ((Test-Path $PackagePath)) {
  # Install tools in packages.config.
  Write-Host "Restoring packages...";
  Invoke-Expression "$NuGetPath install `"$PackagePath`" -ExcludeVersion -OutputDirectory `"$ToolPath`"";
}
if (!(Test-Path $CakePath)) {
  # Install Cake if not part of packages.config.
  Write-Host "Installing Cake...";
  Invoke-Expression "$NuGetPath install Cake -ExcludeVersion -OutputDirectory `"$ToolPath`"";
}
Pop-Location;

# Make sure that Cake has been installed.
if (!(Test-Path $CakePath)) {
    Throw "Could not find Cake.exe at $CakePath";
}

# Start Cake
Write-Host "Executing build script...";
Invoke-Tool -Path $CakePath -Arguments "`"$Script`" -target=`"$Target`" -verbosity=`"$Verbosity`" --paths_tools=`"$ToolPath`" $Arguments";
