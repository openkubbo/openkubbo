# OpenKubbo

OpenKubbo is a macOS menu bar app for lightweight developer workflows around repositories, task cards, and CLI-backed AI assistance.

It ships outside the Mac App Store as a notarized macOS app and is designed to stay close to the menu bar instead of behaving like a full Dock-first app.

## What It Does Today

### Menu Bar Launcher

The menu bar entry can open:

- `Kubbo Task`
- `Repository`
- `Terminal`
- `Kubbo Agent`
- `Settings`

It also includes a quick theme toggle.

### Kubbo Task

The task window is a compact floating panel for short-lived task management:

- add tasks quickly
- edit, reorder, complete, and delete tasks
- generate smart task cards from a single idea
- open multiple task windows

Task generation is backed by the AI provider selected in Settings. Codex can use a local CLI session or an OpenAI API key fallback. Gemini task generation currently depends on launching the local Gemini CLI.

### Kubbo Agent

The agent window combines a CLI-backed chat surface with a task sidebar:

- sends prompts through Codex or Gemini
- keeps provider sessions alive while the window stays open
- lets you switch providers with `/codex` or `/gemini`
- includes a small task list beside the conversation
- can generate task cards from an idea without leaving the window

Today, those CLI-backed actions are only available in unsandboxed runs such as the `Debug` build from Xcode.

### Repository

The repository window is focused on GitHub-backed repository workflows plus local actions:

- load repository data from GitHub after sign-in
- inspect issues, pull requests, branches, CI runs, tags, releases, discussions, contributors, and open commits
- create issues, add issue comments, create issue branches, and open pull requests
- open a repository on GitHub
- open a repository in Finder or Terminal when a local repositories folder is configured
- clone missing repositories into the configured local root
- switch worktrees and open Kubbo Agent from the repository panel

### Settings

Settings currently cover:

- theme mode and accent color
- app version and Sparkle update checks
- AI provider configuration for Codex, Gemini, and optional `node` runtime overrides
- GitHub device-flow login
- local repositories folder selection

`General` and `Shortcuts` are still marked as under construction in the UI.

## Current Scope

OpenKubbo is usable today, but it is still a focused utility rather than a fully polished desktop product.

Current constraints to be aware of:

- macOS only
- direct distribution only; not a Mac App Store app
- the direct-distribution `Release` build is sandboxed, so Kubbo Agent and Gemini CLI-backed flows currently require the unsandboxed `Debug` build from Xcode
- Codex task generation can still work in sandboxed builds when an OpenAI API key fallback is configured
- GitHub-backed features require a GitHub OAuth App Client ID
- local repository actions assume developer tools and a local repositories root are already set up
- task windows are created with in-memory task state per window session

## Download

Primary website:

- [openkubbo.com](https://openkubbo.com)

Typical installation flow:

1. Download `OpenKubbo.zip`.
2. Unzip the archive.
3. Move `OpenKubbo.app` to `/Applications`.
4. Open the app.
5. Look for the OpenKubbo icon in the macOS menu bar.

## Requirements

### Runtime

- macOS 26.2 or later
- Apple Silicon or Intel Mac

### Development

- Xcode 26.2 or newer
- a macOS machine
- an Apple Developer account if you want to sign and notarize release builds

Optional but useful for local development:

- `codex` CLI
- `gemini` CLI
- `node` when either CLI is installed through a JavaScript launcher

## Run Locally

Open the project in Xcode:

```sh
open OpenKubbo.xcodeproj
```

Then:

1. Select the `OpenKubbo` scheme.
2. Choose `My Mac`.
3. Build and run.

The app launches as a menu bar extra. Use the `Debug` configuration when you want local Codex or Gemini CLI integration.

## GitHub Setup

OpenKubbo uses GitHub Device Flow for authentication.

To enable GitHub-backed features:

1. Open `Settings`.
2. Go to the `GitHub` section.
3. Paste a GitHub OAuth App Client ID.
4. Start `Login with GitHub`.
5. Complete authorization on GitHub's device page.

GitHub tokens are stored in the macOS Keychain.

## AI Provider Setup

OpenKubbo supports two provider paths for task generation. Kubbo Agent uses local CLI execution directly, so the full agent experience currently requires an unsandboxed run.

### Codex

OpenKubbo prefers a local Codex CLI session in unsandboxed runs.

Recommended setup:

1. Install `codex`.
2. In Terminal, run `codex login`.
3. Choose ChatGPT.
4. In OpenKubbo Settings, confirm the detected executable path.

You can also store an OpenAI API key in Keychain as a fallback for task generation when local CLI launching is unavailable.

### Gemini

OpenKubbo can also generate task cards and answer prompts through Gemini CLI.

Recommended setup:

1. Install `gemini`.
2. Run `gemini` once in Terminal and sign in with Google.
3. In OpenKubbo Settings, confirm the detected executable path.

You can also store a Gemini API key in Keychain so OpenKubbo can inject `GEMINI_API_KEY` when it launches Gemini CLI. Gemini features still depend on being able to launch the local CLI, so they are currently limited to unsandboxed runs such as the `Debug` build.

### Node Runtime

If your Codex or Gemini executable is a JavaScript launcher, configure a `node` executable in Settings so OpenKubbo can launch it reliably in unsandboxed runs.

## Project Structure

- [`OpenKubbo/App`](OpenKubbo/App): app entry point, scenes, and dependency wiring
- [`OpenKubbo/Core`](OpenKubbo/Core): GitHub services, persistence, updates, AI provider integrations, and shared logic
- [`OpenKubbo/Features/MenuBar`](OpenKubbo/Features/MenuBar): menu bar UI and actions
- [`OpenKubbo/Features/Home`](OpenKubbo/Features/Home): placeholder root content kept from the project template
- [`OpenKubbo/Features/Task`](OpenKubbo/Features/Task): floating task panel
- [`OpenKubbo/Features/Agent`](OpenKubbo/Features/Agent): agent window and CLI-backed chat flow
- [`OpenKubbo/Features/Repository`](OpenKubbo/Features/Repository): repository browser and local repository actions
- [`OpenKubbo/Features/Settings`](OpenKubbo/Features/Settings): settings UI and provider configuration

## Distribution And Updates

OpenKubbo is intended to be distributed outside the Mac App Store.

Typical release flow:

1. Archive the app in Xcode.
2. Distribute using `Direct Distribution`.
3. Submit for notarization.
4. Export the notarized app.
5. Zip `OpenKubbo.app`.
6. Publish the archive and release notes.

The app is configured for Sparkle-based in-app updates.

The current direct-distribution `Release` build is still sandboxed, so local CLI-backed features should be validated in the unsandboxed `Debug` build.

Relevant release assets and settings:

- appcast feed: `https://openkubbo.com/appcast.xml`
- Sparkle helper scripts: [`scripts/release`](scripts/release)
- app metadata: [`OpenKubbo-Info.plist`](OpenKubbo-Info.plist)

## Versioning

Recommended versioning flow:

1. Commit the release-ready changes.
2. Create a tag such as `v1.1.2`.
3. Create a GitHub Release from that tag.
4. Attach the notarized `OpenKubbo.zip`.

## Notes

- Keep this README aligned with the current product, not the intended long-term vision.
- If you change authentication, AI provider setup, distribution, or minimum macOS version, update this file in the same branch.
