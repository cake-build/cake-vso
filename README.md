# cake-vso
Cake integration for TFS/VSTS.

This extension contains a custom build task that runs Cake build scripts for you.

Cake (C# Make) is a cross platform build automation system with a C# DSL to do things like compiling code, copy files/folders, running unit tests, compress files and build NuGet packages.

Run Cake scripts easily
-----------------------

The Cake VSTS build tasks makes it easy to run a Cake script directly without having to invoke PowerShell or other commands line scripts. This makes it easy even for team members not familiar with Cake to add or adjust parameters passed to your build scripts.

How to use the build task
-------------------------

After installing this extension, a new task will become available called "Cake Task" when you add a new build step for a build definition.

![Add Cake Task](https://raw.githubusercontent.com/cake-build/cake-vso/develop/Images/addtasks.png)

By default, the Cake build step (when added to a build) will try to run the `build.cake` build script (found in the root of your repository) with the target `Default`. If you wish to run another build script or build target you can change this in the build step settings.

![Configure Custom Build Step](https://raw.githubusercontent.com/cake-build/cake-vso/develop/Images/configurebuildstep.png)

At the moment, only Windows build agents are supported, but we expect to add support for other build agents soon.

Learn more
----------

For more information about Cake, please see the [Cake website](https://cakebuild.net) or the Cake [source code repository](https://github.com/cake-build/cake).

## Thanks

A big thank you has to go to [JetBrains](https://www.jetbrains.com) who provide each of the Cake Developers with an [Open Source License](https://www.jetbrains.com/support/community/#section=open-source) for [ReSharper](https://www.jetbrains.com/resharper/) that helps with the development of Cake.

## Code of Conduct

This project has adopted the code of conduct defined by the [Contributor Covenant](http://contributor-covenant.org/)
to clarify expected behavior in our community.
For more information see the [.NET Foundation Code of Conduct](http://www.dotnetfoundation.org/code-of-conduct).

## .NET Foundation

This project is supported by the [.NET Foundation](http://www.dotnetfoundation.org).
