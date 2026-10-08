# spm-flutter-learn

Offline coffee list (hardcoded dummy data + favorites saved with
`shared_preferences`). The Dart side is deliberately tiny. The point is to see
how Flutter's iOS build moves from **CocoaPods** to **Swift Package Manager**.

- Flutter **3.47.6** (pinned in `.fvmrc`; run with `fvm flutter ...`)
- Xcode 27, iOS min **15.0**
- Doc followed: https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers

```bash
fvm flutter pub get
fvm flutter run          # pick an iOS simulator
```

## Learn by diff: each lesson is one commit

```bash
git log --oneline
git show 3079214 --stat   # Lesson 1
git show 579c0c4          # Lesson 2  <- the interesting one
git show e0b73be          # Lesson 3
```

| Commit | State | Plugin comes from |
|---|---|---|
| Lesson 1 | SPM **off**, CocoaPods only | `ios/Pods/` (via `Podfile`) |
| Lesson 2 | SPM **on**, CocoaPods still present | SPM package; `Flutter` pod is still in CocoaPods |
| Lesson 3 | SPM only, CocoaPods removed | SPM package; no `Podfile` |

### Lesson 1: CocoaPods baseline

`pubspec.yaml` contains:

```yaml
flutter:
  config:
    enable-swift-package-manager: false
```

This key overrides the global `flutter config` setting, for this project only.
Build it and Flutter runs `pod install`. You get `ios/Podfile`, `Podfile.lock`
and `ios/Pods/`, and Xcode embeds the plugin through the
`[CP] Embed Pods Frameworks` build phase.

### Lesson 2: turn SPM on

Change the key to `true` and run `flutter build ios` (or `flutter run`). Flutter
then **migrates the Xcode project for you**. Look at `git show 579c0c4`:

1. **`Runner.xcodeproj/project.pbxproj`**: adds an `XCLocalSwiftPackageReference`
   that points at `Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`,
   links that package's product into the Runner target, and removes the
   `[CP] Embed Pods Frameworks` phase.
2. **`Runner.xcscheme`**: adds a build **pre-action** named *Run Prepare
   Flutter Framework Script* (`xcode_backend.sh prepare`). It runs before
   Xcode resolves packages, so the generated package exists by then.
3. **`Podfile.lock`**: `shared_preferences_foundation` is no longer listed. It
   now comes from SPM. Only the `Flutter` pod is left, because a `Podfile`
   still exists.

The generated package (it is gitignored and rebuilt on every build) is the
part to understand:

```
ios/Flutter/ephemeral/Packages/
├── FlutterGeneratedPluginSwiftPackage/Package.swift   # one umbrella package
└── .packages/
    ├── FlutterFramework/                               # Flutter engine as a package
    └── shared_preferences_foundation-2.5.7 -> ~/.pub-cache/.../darwin/shared_preferences_foundation
```

`FlutterGeneratedPluginSwiftPackage/Package.swift` depends on every plugin
that has a `Package.swift`. Xcode links only this one package, so adding a
plugin with `flutter pub add` never requires editing the Xcode project.

How to tell whether a plugin supports SPM: look for
`<plugin>/darwin/<name>/Package.swift` (or `ios/<name>/Package.swift`) in
`~/.pub-cache`. If a plugin has no `Package.swift`, Flutter falls back to
CocoaPods for that plugin only.

### Lesson 3: remove CocoaPods

You can do this only when **every** plugin supports SPM:

```bash
cd ios && pod deintegrate
rm -rf Podfile Podfile.lock Pods .symlinks
# delete the `#include? "Pods/..."` line in Flutter/Debug.xcconfig and Flutter/Release.xcconfig
# delete the <FileRef location="group:Pods/Pods.xcodeproj"> entry in Runner.xcworkspace/contents.xcworkspacedata
cd .. && flutter clean && flutter pub get && flutter build ios --simulator
```

`pod deintegrate` leaves the Pods reference in the workspace behind. It says so
in its output.

## Experiments to try

- `fvm flutter pub add url_launcher`, build, then `cat` the generated
  `Package.swift`. A new dependency appears and you never touch Xcode.
- Add a plugin that has no `Package.swift`. Flutter should fall back to CocoaPods and
  bring back a `Podfile` for that plugin.
- Open `ios/Runner.xcworkspace` in Xcode, then look at **Package Dependencies**
  and **Product > Scheme > Edit Scheme > Build > Pre-actions**.
- Set the pubspec key back to `false` and see what Flutter does, and what it
  does not undo.

## Gotchas hit while building this (Oct 2026)

- **Xcode 27 rejects deployment targets below iOS 15.** The Flutter template
  still uses 13.0. Bumped `IPHONEOS_DEPLOYMENT_TARGET` to 15.0. With
  CocoaPods, the `Podfile` also had to force 15.0 on each pod target. With SPM
  this is not needed: plugin packages that declare `.iOS("13.0")` build fine
  under the app's 15.0 target.
- **Flutter 3.44.x + Xcode 27:** simulator builds fail with
  `Binary .../Flutter does not contain architectures "arm64 x86_64"`. The new
  `lipo -verify_arch` accepts only one arch per call. Fixed in 3.47.x, which
  checks each arch separately.
- On this machine, the global `flutter config` has
  `enable-swift-package-manager: false`. The pubspec key overrides it, so other
  projects are left unchanged.
