# Install LinuxRunner

Installing the IPA installs LinuxRunner. You then install a Linux distribution **inside the app**. No jailbreak or JIT activation is required.

## Requirements

The Build 910 device IPA is ARM64, configured for iPhone and iPad with a 15.0 deployment target. iOS/iPadOS 15 is an intended minimum, not broadly verified compatibility; development and testing primarily use newer releases. See [hardware, memory and storage guidance](../README.md#supported-devices-and-requirements). An older iPhone 11/iOS 17 startup-black-screen report remains unresolved.

## Download, Sign and Open

1. Download the IPA from [GitHub Releases](https://github.com/jacktembo/LinuxRunner/releases).
2. Compare the original file's SHA-256 with the checksum supplied for that release.
3. Install using your preferred compatible IPA sideloading tool, such as [Sideloadly](https://sideloadly.io/) or [AltStore Classic](https://altstore.io/).
4. Open the app, then **Distributions** and choose a distribution to install. Follow the [Linux installation walkthrough](GETTING_STARTED.md).

The 1.1.2 asset is **LinuxRunner-1.1.2-build910.ipa**. It has an ad-hoc signature and no Apple provisioning profile. A compatible tool must provide the signing/provisioning needed for ordinary device installation. Signing requirements, renewal intervals and compatibility depend on the tool and account; no service is guaranteed to work.

The bundle identifier is `dev.linuxrunner.app`. Optional App Group access uses `group.dev.linuxrunner.app` when provisioned; otherwise private application storage is used. **Ordinary interpreter execution does not require debugger/JIT permission.** Optional JIT activation has separate signing/OS restrictions; see [JIT](engine/IOS_JIT.md).

## Verify the Original Download

On macOS/Linux, using the actual downloaded filename:

```sh
shasum -a 256 LinuxRunner-1.1.2-build910.ipa
```

On Windows PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 .\LinuxRunner-1.1.2-build910.ipa
```

Build 910's verified original hash is:

```text
31f4ee6d1b89d6d4c4a968c3b625c2eada8374df7bcbc3be51cc28a187e16a10
```

Signing changes the file; compare before signing. A valid checksum confirms the downloaded bytes, not compatibility with every installer or device.

## Update Without Losing Environments

Back up important files and retain your previous IPA. Keep the existing bundle identifier and App Group/container configuration. Changing signing identity or storage entitlements can change access to existing data. Do not uninstall LinuxRunner or delete a root filesystem to diagnose a problem. See [Troubleshooting](TROUBLESHOOTING.md).
