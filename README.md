# Screen Glosser

A free, open-source macOS menu-bar app that lays a subtle, even **matte**, **weave**,
**paper** or **e-ink** grain over your whole screen. It takes the glossy edge off a display and makes long
reading sessions feel more like paper.

## Features

- Four uniform, crisp textures that look the same on Retina and standard displays: Classic Matte, Fine Weave, Soft Paper and E-Ink. Each one
  also lowers contrast slightly and softens harsh highlights.
- Intensity and tint sliders, right in the menu bar
- Global hotkey **⌃⌥⌘P** to toggle the texture
- Works on every display, in every Space and over full-screen apps, with a per-display on/off switch
- Exclude apps (Photoshop, video players, …): the texture fades out while one of them is in front
- Left out of screenshots and screen recordings
- Click-through: the overlay never steals clicks, scrolling or focus
- About 0% CPU while idle. The texture is a static tile that only redraws when settings change.
- Launch at login
- No dependencies and no network access

## Build

You only need the Xcode **Command Line Tools** (`xcode-select --install`), not Xcode itself.

```sh
./scripts/bundle.sh          # builds build/ScreenGlosser.app (universal, ad-hoc signed)
open build/ScreenGlosser.app
cp -R build/ScreenGlosser.app /Applications/   # optional; required for "Launch at login"
```

A `Package.swift` is also included for working with the project in Xcode or with
`swift build`.

## How it works

Each display gets a borderless, transparent window at screen-saver level that ignores mouse
events and joins all Spaces. macOS composites windows using plain alpha blending, so the
overlay can't multiply against other apps. Instead the grain is encoded in alpha: dark
specks are translucent black and light specks are translucent white. A flat veil underneath
lifts the blacks and dims the highlights. Each texture is a 512×512 seamless tile of
*stationary* noise (no blotches or dust), sized in points, so a grain covers 1 pixel on a standard display and an exact 2×2 block on
Retina. It looks the same on a Retina laptop and on an external monitor, and stays crisp with
no moiré. Every texture is normalized to the same
strength, so the intensity slider feels the same whichever texture you pick.

## Limitations

- An excluded app hides the overlay on all screens while it is frontmost. macOS can't cut the
  overlay out around a single window.
- The overlay appears above the menu bar and Dock but below the mouse cursor.

## License

MIT
