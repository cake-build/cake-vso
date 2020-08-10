//////////////////////////////////////////////////////////////////////
// ADDINS
//////////////////////////////////////////////////////////////////////

#addin "nuget:?package=MagicChunks&version=2.0.0.119"
#addin "nuget:?package=Cake.Tfx&version=0.9.1"
#addin "nuget:?package=Cake.Npm&version=0.17.0"
#addin "nuget:?package=Cake.AppVeyor&version=4.0.0"
#addin "nuget:?package=Cake.Gitter&version=0.11.1"
#addin "nuget:?package=Cake.Twitter&version=0.10.1"

//////////////////////////////////////////////////////////////////////
// TOOLS
//////////////////////////////////////////////////////////////////////

#tool "nuget:?package=gitreleasemanager&version=0.10.3"
#tool "nuget:?package=GitVersion.CommandLine&version=3.6.4"

// Load other scripts.
#load "./build/parameters.cake"
#load "./build/gitter.cake"
#load "./build/twitter.cake"

//////////////////////////////////////////////////////////////////////
// PARAMETERS
//////////////////////////////////////////////////////////////////////

BuildParameters parameters = BuildParameters.GetParameters(Context, BuildSystem);
bool publishingError = false;

///////////////////////////////////////////////////////////////////////////////
// SETUP / TEARDOWN
///////////////////////////////////////////////////////////////////////////////

Setup(context =>
{
    parameters.SetBuildVersion(
        BuildVersion.CalculatingSemanticVersion(
            context: Context,
            parameters: parameters
        )
    );

    // Increase verbosity?
    if(parameters.IsMasterBranch && (context.Log.Verbosity != Verbosity.Diagnostic)) {
        Information("Increasing verbosity to diagnostic.");
        context.Log.Verbosity = Verbosity.Diagnostic;
    }

    Information("Building version {0} of cake-vso ({1}, {2}) using version {3} of Cake. (IsTagged: {4})",
        parameters.Version.SemVersion,
        parameters.Configuration,
        parameters.Target,
        parameters.Version.CakeVersion,
        parameters.IsTagged);
});

Teardown(context =>
{
    Information("Starting Teardown...");

    if(context.Successful)
    {
        if(!parameters.IsLocalBuild && !parameters.IsPullRequest && parameters.IsMasterRepo && (parameters.IsMasterBranch || ((parameters.IsReleaseBranch || parameters.IsHotFixBranch))) && parameters.IsTagged)
        {
            if(parameters.CanPostToTwitter)
            {
                SendMessageToTwitter();
            }

            if(parameters.CanPostToGitter)
            {
                SendMessageToGitterRoom();
            }
        }
    }

    Information("Finished running tasks.");
});

//////////////////////////////////////////////////////////////////////
// TASKS
//////////////////////////////////////////////////////////////////////

Task("Clean")
    .Does(() =>
{
    CleanDirectories(new[] { "./build-results", "./build-temp" });
});

Task("Npm-Install")
    .Does(() =>
{
    var settings = new NpmInstallSettings();
    settings.LogLevel = NpmLogLevel.Silent;
    NpmInstall(settings);
});

Task("Npm-Run-Build-Script")
    .IsDependentOn("Install-Npm-Packages")
    .Does(() =>
{
    var settings = new NpmRunScriptSettings();
    settings.LogLevel = NpmLogLevel.Silent;
    settings.ScriptName = "build";
    NpmRunScript(settings);
});

Task("Install-Npm-Packages")
    .IsDependentOn("Npm-Install")
    .Does(() =>
{
    var settings = new NpmInstallSettings();
    settings.Global = true;
    settings.AddPackage("tfx-cli", "0.6.3");
    settings.AddPackage("@zeit/ncc", "0.21.1");
    settings.LogLevel = NpmLogLevel.Silent;
    NpmInstall(settings);
});

Task("Create-Release-Notes")
    .Does(() =>
{
    GitReleaseManagerCreate(parameters.GitHub.Token, "cake-build", "cake-vso", new GitReleaseManagerCreateSettings {
        Milestone         = parameters.Version.Milestone,
        Name              = parameters.Version.Milestone,
        Prerelease        = true,
        TargetCommitish   = "master"
    });
});

Task("Update-Json-Versions")
    .Does(() =>
{
    var projectToPackagePackageJson = "extension-manifest.json";
    Information("Updating {0} version -> {1}", projectToPackagePackageJson, parameters.Version.SemVersion);

    TransformConfig(projectToPackagePackageJson, projectToPackagePackageJson, new TransformationCollection {
        { "version", parameters.Version.SemVersion }
    });

    var taskJson = "Task/task.json";
    Information("Updating {0} version -> {1}", taskJson, parameters.Version.SemVersion);

    TransformConfig(taskJson, taskJson, new TransformationCollection {
        { "version/Major", parameters.Version.Major }
    });

    TransformConfig(taskJson, taskJson, new TransformationCollection {
        { "version/Minor", parameters.Version.Minor }
    });

    TransformConfig(taskJson, taskJson, new TransformationCollection {
        { "version/Patch", parameters.Version.Patch }
    });

    var packageJson = "package.json";
    Information("Updating {0} version -> {1}", packageJson, parameters.Version.SemVersion);

    TransformConfig(packageJson, packageJson, new TransformationCollection {
        { "version", parameters.Version.SemVersion }
    });
});

Task("Package-Extension")
    .IsDependentOn("Update-Json-Versions")
    .IsDependentOn("Npm-Run-Build-Script")
    .IsDependentOn("Clean")
    .Does(() =>
{
    var buildTempDir = Directory("./build-temp");
    var buildResultDir = Directory("./build-results");

    var vstsTaskSdkVersion = "0.11.0";

    NuGetInstall("VstsTaskSdk", new NuGetInstallSettings {
        NoCache = true,
        OutputDirectory = buildTempDir,
        Source = new [] { "https://www.powershellgallery.com/api/v2/ "},
        Version = vstsTaskSdkVersion
    });

    TfxExtensionCreate(new TfxExtensionCreateSettings()
    {
        ManifestGlobs = new List<string>(){ "./extension-manifest.json" },
        OutputPath = buildResultDir
    });
});

Task("Upload-AppVeyor-Artifacts")
    .IsDependentOn("Package-Extension")
    .WithCriteria(() => parameters.IsRunningOnAppVeyor)
.Does(() =>
{
    var buildResultDir = Directory("./build-results");
    var packageFile = File("cake-build.cake-" + parameters.Version.SemVersion + ".vsix");
    AppVeyor.UploadArtifact(buildResultDir + packageFile);
});

Task("Publish-GitHub-Release")
    .WithCriteria(() => parameters.ShouldPublish)
    .Does(() =>
{
    var buildResultDir = Directory("./build-results");
    var packageFile = File("cake-build.cake-" + parameters.Version.SemVersion + ".vsix");

    GitReleaseManagerAddAssets(parameters.GitHub.Token, "cake-build", "cake-vso", parameters.Version.Milestone, buildResultDir + packageFile);
    GitReleaseManagerClose(parameters.GitHub.Token, "cake-build", "cake-vso", parameters.Version.Milestone);
})
.OnError(exception =>
{
    Information("Publish-GitHub-Release Task failed, but continuing with next Task...");
    publishingError = true;
});

Task("Publish-Extension")
    .IsDependentOn("Package-Extension")
    .WithCriteria(() => parameters.ShouldPublish)
    .Does(() =>
{
    var buildResultDir = Directory("./build-results");
    var packageFile = File("cake-build.cake-" + parameters.Version.SemVersion + ".vsix");

    TfxExtensionPublish(buildResultDir + packageFile, new TfxExtensionPublishSettings()
    {
        AuthType = TfxAuthType.Pat,
        Token = parameters.Marketplace.Token
    });
})
.OnError(exception =>
{
    Information("Publish-Extension Task failed, but continuing with next Task...");
    publishingError = true;
});

//////////////////////////////////////////////////////////////////////
// TASK TARGETS
//////////////////////////////////////////////////////////////////////

Task("Default")
    .IsDependentOn("Package-Extension");

Task("Appveyor")
    .IsDependentOn("Upload-AppVeyor-Artifacts")
    .IsDependentOn("Publish-Extension")
    .IsDependentOn("Publish-GitHub-Release")
    .Finally(() =>
{
    if(publishingError)
    {
        throw new Exception("An error occurred during the publishing of cake-vscode.  All publishing tasks have been attempted.");
    }
});

Task("ReleaseNotes")
  .IsDependentOn("Create-Release-Notes");

//////////////////////////////////////////////////////////////////////
// EXECUTION
//////////////////////////////////////////////////////////////////////

RunTarget(parameters.Target);
