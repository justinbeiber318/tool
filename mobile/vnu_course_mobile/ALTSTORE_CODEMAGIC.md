# Build IPA for AltStore with Codemagic

This path is for users without a Mac. Codemagic supplies the macOS/Xcode build
machine, then AltStore signs and installs the `.ipa` on the iPhone.

## What This Produces

The workflow in `../../codemagic.yaml` creates:

```text
vnu_course_mobile_unsigned.ipa
```

This IPA is intended for AltStore/SideStore sideloading. It is not an App Store
or TestFlight IPA.

## Steps

1. Push this repository to GitHub, GitLab, or Bitbucket.
2. Create/sign in to Codemagic.
3. Add the repository in Codemagic.
4. Select the YAML workflow:

```text
iOS AltStore unsigned IPA
```

5. Start the build.
6. When the build finishes, download the `.ipa` from Artifacts.
7. Move the `.ipa` to the iPhone using Files/iCloud Drive/AirDrop.
8. Open the `.ipa` with AltStore.
9. AltStore signs and installs the app with your Apple ID.

## Refresh Rule

Free Apple ID sideloads usually need refresh before the 7-day development
signing window expires. Keep AltServer available on Windows and use AltStore's
Refresh action.

## If Codemagic Build Fails

Check the build log for:

- missing generated `ios/` runner
- plugin compatibility
- Flutter/Dart analyzer errors
- Xcode or CocoaPods errors

The workflow runs:

```bash
flutter create --platforms=ios .
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
```

Then it manually packages `Runner.app` into an unsigned IPA payload.
