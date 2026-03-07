# OpenKubbo

OpenKubbo is a macOS menu bar app focused on lightweight GitHub and repository workflows.

It is currently distributed as a notarized macOS app outside the Mac App Store. The project is in active development and some areas are still demo-level or intentionally incomplete.

## What It Does

- Lives in the macOS menu bar instead of behaving like a standard Dock-first app.
- Opens a task panel, settings window, and repository panel from the menu bar.
- Supports GitHub device-flow login.
- Loads GitHub account and repository data.
- Includes local repository and worktree-oriented actions for repositories configured on disk.
- Persists app settings locally on the machine.

## Current Status

This project is usable, but it is not a fully polished product release yet.

- The app is best understood as a working demo / early utility.
- Some views and controls are still under construction.
- GitHub login currently depends on a GitHub OAuth App Client ID being configured.
- Some repository actions assume local developer tools and repository paths are already set up.

## Download

The recommended distribution format is a notarized `.zip` that contains `OpenKubbo.app`.

Primary website:

- [openkubbo.com](https://openkubbo.com)

Typical installation flow:

1. Download `OpenKubbo.zip`.
2. Unzip the file.
3. Move `OpenKubbo.app` to `/Applications`.
4. Open the app.
5. Look for the OpenKubbo icon in the macOS menu bar.

Because OpenKubbo is configured as a menu bar app, it may not behave like a normal Dock app.

## macOS Requirements

- macOS 26.2 or later
- Apple Silicon or Intel Mac

## Development

### Requirements

- Xcode 26 or newer
- A macOS machine
- Apple Developer account if you want to sign and notarize distribution builds

### Open The Project

```sh
open /Users/docs/openkubbo/OpenKubbo.xcodeproj
```

Or open [OpenKubbo.xcodeproj](/Users/docs/openkubbo/OpenKubbo.xcodeproj) directly in Xcode.

### Run Locally

1. Select the `OpenKubbo` scheme.
2. Choose `My Mac`.
3. Build and run from Xcode.

The app launches as a menu bar extra.

## GitHub Setup

OpenKubbo uses GitHub device flow for authentication.

To use GitHub-backed features:

1. Open the Settings window.
2. Go to the GitHub section.
3. Provide a GitHub OAuth App Client ID.
4. Start the GitHub login flow.
5. Complete authorization on GitHub.

GitHub tokens are stored in the macOS Keychain, not in the repository.

## Project Structure

- [OpenKubbo/App](/Users/docs/openkubbo/OpenKubbo/App): app entry point and dependency wiring
- [OpenKubbo/Core](/Users/docs/openkubbo/OpenKubbo/Core): GitHub services, persistence, theme, and shared logic
- [OpenKubbo/Features/MenuBar](/Users/docs/openkubbo/OpenKubbo/Features/MenuBar): menu bar entry and actions
- [OpenKubbo/Features/Task](/Users/docs/openkubbo/OpenKubbo/Features/Task): task panel UI
- [OpenKubbo/Features/Settings](/Users/docs/openkubbo/OpenKubbo/Features/Settings): settings UI and GitHub configuration
- [OpenKubbo/Features/Repository](/Users/docs/openkubbo/OpenKubbo/Features/Repository): repository browsing and local repository actions

## Direct Distribution

This project is intended to be distributed outside the Mac App Store.

Release flow:

1. Archive the app in Xcode.
2. Distribute using `Direct Distribution`.
3. Upload to Apple notarization.
4. Wait for `Ready to distribute`.
5. Export the notarized app.
6. Zip `OpenKubbo.app`.
7. Publish the zip on [openkubbo.com](https://openkubbo.com) or attach it to a GitHub Release.

## Versioning

Recommended release flow:

1. Commit the release-ready changes.
2. Create a tag such as `v1.0.0`.
3. Create a GitHub Release from that tag.
4. Attach the notarized `OpenKubbo.zip`.

## Notes

- `README` should track the product as it actually exists, not the intended long-term vision.
- If you change the authentication flow, distribution flow, or minimum macOS version, update this file.
