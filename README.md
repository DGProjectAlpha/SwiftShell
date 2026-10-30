# SwiftShell

A minimalist, keyboard-first desktop shell for Hyprland, built with Quickshell and QML.

## Design direction

- Transparent top bar with a subtle optional legibility gradient, without visible borders or chunky backgrounds.
- Lightweight, monochrome interface with wallpaper-adaptive tint and strong text contrast.
- Gaussian-blurred popovers, flat controls, compact notifications, and a Spotlight-inspired launcher.
- Integrated workspace indicators, system tray, clock, media, network, audio, power and settings controls.
- GUI configuration for appearance, displays, shortcuts, audio and networking.
- Rounded, borderless windows and an unobtrusive desktop, configured through Hyprland where supported.
- Future exploration: blurred wallpaper behind tiling gaps, fluid window rearrangement and drag-to-edge workspace moves.

## Development principles

1. Preserve the user's existing CachyOS, Hyprland, and Noctalia configuration. No automatic system-wide changes.
2. Start with isolated Quickshell components and test on the secondary monitor before any full-session switch.
3. Keep modules small, changes reviewable, and provide a reliable exit/recovery path.
4. Prefer native Hyprland and Linux APIs; identify compositor limitations rather than promising unsupported features.
5. Keep the interface visually restrained: no Material Design-inspired oversized controls or excessive accent colors.

## Target environment

- CachyOS / Arch Linux, Hyprland (Lua configuration), Quickshell/QML.
- NVIDIA RTX 4070.
- DP-1: 2560×1440 at approximately 165 Hz; workspaces 1–3.
- HDMI-A-1: 1920×1080 at 60 Hz, scale 1.5; workspaces 4–6.
- Preserve existing keyboard shortcuts and window behavior unless changes are explicitly approved.

## First milestone

Create a standalone transparent top bar prototype for HDMI-A-1, with workspace indicators and a clock. Do not replace Noctalia, change autostart, capture global shortcuts, or modify existing Hyprland configuration. Include a simple launch/stop procedure and validation steps.

## Project status

Repository initialized. Implementation has not started.
