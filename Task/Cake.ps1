Param(
    [string]$script,
    [string]$target,
    [string]$verbosity,
    [string]$arguments
)

Write-Verbose "Entering script $MyInvocation.MyCommand.Name";
Write-Verbose "Parameter Values";
foreach($key in $PSBoundParameters.Keys)
{
    Write-Verbose ($key + ' = ' + $PSBoundParameters[$key]);
}

import-module "Microsoft.TeamFoundation.DistributedTask.Task.Internal";
import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common";

$rootPath = Split-Path -parent $script;
$toolsPath = Join-Path $rootPath "tools";
$packagePath = Join-Path $toolsPath "packages.config";
$cakePath = Join-Path $toolsPath "Cake/Cake.exe";
$nuGetPath = Join-Path $toolsPath "nuget.exe";

# Check if there's a tools directory.
if (!(Test-Path $toolsPath)) {
    Write-Host "Creating tools directory...";
    New-Item -Path $toolsPath -Type directory | out-null;
    if (!(Test-Path $toolsPath)) {
        Throw "Could not create tools directory.";
    }
}

# Make sure NuGet exist.
if (!(Test-Path $nuGetPath)) {
  # Download NuGet.exe.
  Write-Verbose "Downloading nuget.exe...";
  (New-Object System.Net.WebClient).DownloadFile("https://nuget.org/nuget.exe", $nuGetPath);
  # Make sure it was properly downloaded.
  if (!(Test-Path $nuGetPath)) {
      Throw "Could not find nuget.exe";
  }
}

# Install prereqs from NuGet.
Push-Location;
Set-Location $toolsPath;
if ((Test-Path $packagePath)) {
  # Install tools in packages.config.
  Write-Host "Restoring packages...";
  Invoke-Expression "$nuGetPath install `"$packagePath`" -ExcludeVersion -OutputDirectory `"$toolsPath`"";
}
if (!(Test-Path $cakePath)) {
  # Install Cake if not part of packages.config.
  Write-Host "Installing Cake...";
  Invoke-Expression "$nuGetPath install Cake -ExcludeVersion -OutputDirectory `"$toolsPath`"";
}
Pop-Location;

# Make sure that Cake has been installed.
if (!(Test-Path $cakePath)) {
    Throw "Could not find Cake.exe at $cakePath";
}

# Start Cake
Invoke-Tool -Path $cakePath -Arguments "`"$script`" -target=`"$target`" -verbosity=`"$verbosity`" --paths_tools=`"$toolsPath`" $arguments";
