## scatter 

scatter is a command line tool for uploading Minecraft mods to distribution platforms, currently CurseForge, Modrinth and GitHub Releases. For more in-depth documentation than this readme can provide, head to the [wiki](https://docs.wispforest.io/scatter/home/)

### Installation

scatter is written in Dart, meaning you require the Dart SDK to build it. You can either install that or 
download one of the precompiled scatter binaries from the [Actions](https://github.com/gliscowo/scatter-dart/actions) section

To compile scatter, execute the following commands from the root of this repository

```shell
dart pub get
dart compile exe bin/scatter.dart
```

Then take the generated `scatter.exe` file and move it somewhere convenient

### Usage

For first-time setup you need to 
- configure the default Minecraft versions which scatter will mark your uploaded files compatible with
- add your access tokens for CurseForge and Modrinth

To set the default versions run the following command and follow the prompt
```shell
scatter config --default-versions
```

To add your tokens, run the following command and paste your token when prompted
```shell
scatter config --tokens
```

***

To add a mod to the database run `scatter add <mod-id>` and follow the procedure. scatter will give you the option to provide an artifact location, 
consisting of the directory (usually your `build/libs` directory) and filename pattern. This pattern must contain a `{}` where your mod files contain their version. Together this information is used to automatically find your builds for you and let you select which version to upload.  

***

To upload a new version run either `scatter upload <mod-id> [version]` if you have provided an artifact location or
`scatter upload <mod-id> <file>` if you haven't.
