# Repository Guidelines

## Project Structure & Module Organization

This repository contains EdgeTX Lua scripts for configuring LED strip color and VTX settings over MSP/CRSF telemetry.

- `SCRIPTS/TOOLS/ledvtx.lua` is the main Tools menu entry point.
- `SCRIPTS/TOOLS/ledvtx/` contains implementation modules: `gui.lua`, `com.lua`, `msp.lua`, `config.lua`, and default `config.txt`.
- `SCRIPTS/TELEMETRY/ledvtx.lua` is a small telemetry-screen launcher that loads the Tools script.
- `SCREENSHOTS/` stores README images for SD and HD radio display layouts.
- `README.md` contains user installation and Betaflight setup instructions.

Keep runtime files in the same SD-card-compatible directory layout under `SCRIPTS/`.

## Build, Test, and Development Commands

There is no build step or package manager. Development is edit-and-copy Lua.

- `find . -maxdepth 3 -type f -not -path './.git/*' -print` lists tracked project files when `rg` is unavailable.
- `lua -p SCRIPTS/TOOLS/ledvtx.lua` can syntax-check files only if your local Lua version supports the target syntax; EdgeTX globals such as `lcd`, `loadScript`, and telemetry APIs are not available locally.
- To test on hardware or simulator, copy `SCRIPTS/TOOLS/*` to the radio SD card `SCRIPTS/TOOLS/`. Copy `SCRIPTS/TELEMETRY/ledvtx.lua` only when validating telemetry-screen launch behavior.

## Coding Style & Naming Conventions

Use Lua with two-space indentation, local variables/functions by default, and small modules that return tables of public functions. Follow existing naming: lower camel case for functions and variables (`drawSelector`, `sendLedVtxConfig`), uppercase constants for protocol IDs (`MSP_SET_LED_STRIP`), and menu item constants prefixed with `ITEM_`.

Avoid introducing dependencies; scripts must run in the constrained EdgeTX Lua environment. Preserve compatibility with SD-card paths and case-sensitive script loading.

## Testing Guidelines

No automated test suite is currently present. Validate changes manually in an EdgeTX simulator or on a radio with Betaflight telemetry enabled. For UI changes, check both small monochrome and larger color display layouts when possible. For MSP changes, verify VTX channel, power, LED count, Larson mode, Betaflight version selection, save success, retry behavior, and failure display.

## Commit & Pull Request Guidelines

Recent commits use short imperative or descriptive messages, for example `Set max LED count to 32`, `Bug fix, no return after fail`, and `Add screenshots`. Keep commits focused and explain user-visible behavior.

Pull requests should include a concise description, affected radio/display targets, manual test notes, and screenshots when UI layout changes. Link related issues if available and call out any Betaflight or EdgeTX version assumptions.
