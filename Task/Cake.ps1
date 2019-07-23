$Script = Get-VstsInput -Name Script -Require;
$Target = Get-VstsInput -Name Target -Require;
$Verbosity = Get-VstsInput -Name Verbosity -Require;
$Arguments = Get-VstsInput -Name Arguments;
$useBuildAgentNuGetExe = Get-VstsInput -Name useBuildAgentNuGetExe -AsBool;
$nugetExeDownloadLocation = Get-VstsInput -Name nugetExeDownloadLocation;
$ToolFeedUrl = Get-VstsInput -Name ToolFeedUrl;

try {
  $useBuildAgentNuGetExeBool = [System.Convert]::ToBoolean($useBuildAgentNuGetExe) 
} catch [FormatException] {
  $useBuildAgentNuGetExeBool = $false
}

$RootPath = Split-Path -parent $Script;
$ToolPath = Join-Path $RootPath "tools";
$PackagePath = Join-Path $ToolPath "packages.config";
$ModulePath = Join-Path $ToolPath "Modules";
$ModulePackagePath = Join-Path $ModulePath "packages.config";
$CakePath = Join-Path $ToolPath "Cake/Cake.exe";
$NuGetPath = Join-Path $ToolPath "nuget.exe";

Write-Verbose "=============================================="
Write-Verbose "Root = $RootPath";
Write-Verbose "Tools = $ToolPath";
Write-Verbose "Packages = $PackagePath";
Write-Verbose "Modules = $ModulePath";
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

if($useBuildAgentNuGetExeBool)
{
    Write-Host "Using Build Agent nuget.exe";
    $nugetExeDownloadLocation = Get-ToolPath -Name 'NuGet.exe';
}

# Make sure NuGet exist.
if (!(Test-Path $NuGetPath)) {
  # Download NuGet.exe.
  # Reset $NuGetPath incase we changed it above.
  $NuGetPath = Join-Path $ToolPath "nuget.exe";
  
  # If we haven't been given a custom nuget.exe download location then download the latest version from nuget.org.
  if($nugetExeDownloadLocation -eq "") {
      $nugetExeDownloadLocation = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
  }
  Write-Verbose "Getting nuget.exe from $nugetExeDownloadLocation"
  (New-Object System.Net.WebClient).DownloadFile($nugetExeDownloadLocation, $NuGetPath);
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
  if($ToolFeedUrl -ne ""){
      Invoke-Expression "&`"$NuGetPath`" install `"$PackagePath`" -ExcludeVersion -OutputDirectory `"$ToolPath`" -Source $ToolFeedUrl";
  }else{
      Invoke-Expression "&`"$NuGetPath`" install `"$PackagePath`" -ExcludeVersion -OutputDirectory `"$ToolPath`"";
  }
}
if ((Test-Path $ModulePackagePath)) {
  # Install tools in Modules/packages.config
  Write-Host "Installing modules..."
  if($ToolFeedUrl -ne ""){
      Invoke-Expression "&`"$NuGetPath`" install `"$ModulePackagePath`" -ExcludeVersion -OutputDirectory `"$ModulePath`" -Source $ToolFeedUrl";
  }else{
      Invoke-Expression "&`"$NuGetPath`" install `"$ModulePackagePath`" -ExcludeVersion -OutputDirectory `"$ModulePath`"";
  }
}
if (!(Test-Path $CakePath)) {
  # Install Cake if not part of packages.config.
  Write-Host "Installing Cake...";
  if($ToolFeedUrl -ne ""){
      Invoke-Expression "&`"$NuGetPath`" install Cake -ExcludeVersion -OutputDirectory `"$ToolPath`" -Source $ToolFeedUrl";
  }else{
      Invoke-Expression "&`"$NuGetPath`" install Cake -ExcludeVersion -OutputDirectory `"$ToolPath`"";
  }
}
Pop-Location;

# Make sure that Cake has been installed.
if (!(Test-Path $CakePath)) {
    Throw "Could not find Cake.exe at $CakePath";
}

# Start Cake
Write-Host "Executing build script...";
Invoke-VstsTool -FileName $CakePath -Arguments "`"$Script`" -target=`"$Target`" -verbosity=`"$Verbosity`" --paths_tools=`"$ToolPath`" $Arguments" -RequireExitCodeZero;
