# Dictation Music Bridge

[简体中文](README.md)

A macOS menu bar utility that pauses NetEase Cloud Music when you start macOS Dictation and resumes it from the same position when you finish or cancel. Music that was already paused stays paused.

## Install from source

The deployment target is macOS 14.4 or later. The app was tested on macOS 26.6.2 with NetEase Cloud Music 3.0.19 for Mac. Run `xcode-select --install` if you need the Xcode Command Line Tools.

From the project directory, build and open the app.

```bash
bash build.sh "$HOME/Applications/听写音乐联动.app"
open "$HOME/Applications/听写音乐联动.app"
```

1. Click the waveform icon in the menu bar and choose **授予辅助功能权限** (Grant Accessibility Permission). Enable **听写音乐联动** under **System Settings → Privacy & Security → Accessibility**.
2. Make sure **System Settings → Keyboard → Dictation** is on. Play a song, start Dictation with your usual shortcut, then end it to check that playback pauses and resumes.
3. To run the app at login, select **登录时启动** (Launch at Login) in the waveform menu.

To uninstall, turn off Launch at Login, quit the app, and move it to the Trash.

## Build and distribute

`bash build.sh` builds for your Mac's architecture. `bash build.sh --universal` builds for Apple silicon and Intel. Both default to `dist/听写音乐联动.app`. You can pass an absolute `.app` path that does not already exist.

The default build uses an ad hoc signature for local use. To distribute a prebuilt app, build with `SIGN_IDENTITY='Developer ID Application: …'` to sign with the hardened runtime, then submit it to Apple for notarization. [Apple's notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Privacy and compatibility

The app listens for built-in macOS Dictation events and uses Accessibility to operate the NetEase Cloud Music Controls menu. It processes events locally and checks the Dictation process's microphone activity when needed. Accessibility is the only required permission.

The app relies on undocumented macOS Dictation notifications and the player's menu labels. System or player updates may require changes to the integration.

Licensed under the [MIT License](LICENSE).
