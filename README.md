# socr

Capture a screenshot, OCR it with the Apple Vision framework, and print the recognized text to stdout. Single binary, zero dependencies.

This is a Swift reimplementation of [mekedron/ocr](https://github.com/mekedron/ocr). The original is written in Go with a cgo bridge into Vision. This one does the same thing in about 150 lines of Swift, so there is no Go toolchain and no cgo involved. Same idea, same flags, native all the way down.

## Install

```bash
brew install avichandra2k1/tap/socr
```

Or build from source (requires macOS and Xcode or the Command Line Tools):

```bash
git clone https://github.com/avichandra2k1/socr.git
cd socr
make build
# binary is at .build/release/socr
```

If you don't want SwiftPM, a single swiftc call works too:

```bash
swiftc -O -o socr Sources/socr/main.swift
```

## Usage

```bash
# Capture a region and OCR it (English)
socr

# Specify language(s)
socr -l de-DE
socr -l en-US+de-DE

# Copy to clipboard
socr -c
socr | pbcopy

# Faster, less accurate recognition
socr --fast

# OCR an existing image instead of capturing
socr screenshot.png

# List supported languages
socr languages

# Show version
socr -v
```

When you run `socr`, the macOS screenshot selection UI appears. Select a region and the recognized text is printed to stdout. Press Escape to cancel. Cancelling, or selecting a region with no text, prints nothing and exits 0.

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-l, --lang` | `en-US` | OCR language(s), e.g. `en-US+de-DE` |
| `-x, --silent` | | Do not play the screenshot sound |
| `-c, --clipboard` | | Also copy the text to the clipboard |
| `--fast` | | Use the fast recognition level |
| `-v, --version` | | Show version and exit |
| `-h, --help` | | Show help and exit |

## Languages

Apple Vision does not auto-detect languages. You must specify them with `-l`. To recognize multiple languages at once, join them with `+`:

```bash
socr -l en-US+de-DE
socr -l en-US+fr-FR+ja-JP
```

To see which languages are supported:

```bash
socr languages
```

The `--fast` level supports fewer languages than the default. Run `socr languages --fast` to see that list.

## Keyboard Shortcut

You can bind `socr` to a global hotkey using [Hammerspoon](https://www.hammerspoon.org/) (`brew install hammerspoon`).

Add this to your `~/.hammerspoon/init.lua`:

```lua
-- Cmd+Shift+2: screenshot OCR to clipboard
hs.hotkey.bind({ "cmd", "shift" }, "2", nil, function()
  -- Wait for the shortcut keys to be released, otherwise the selection
  -- crosshair ignores the first drag while Cmd and Shift are still held.
  hs.timer.doAfter(0.1, function()
    hs.execute("/opt/homebrew/bin/socr -x -c -l en-US")
  end)
end)
```

Adjust the language and keybinding to your preference. `-x` suppresses the screenshot sound and `-c` puts the text on the clipboard.

The small delay matters. If you call `socr` directly from the hotkey handler, the screenshot UI comes up while the modifier keys are still down and your first drag does nothing. 0.1 seconds is enough on most setups. If the first drag still gets swallowed, bump it up a little.

## Credits

The idea, the CLI shape, and the flags come from [mekedron/ocr](https://github.com/mekedron/ocr). This is just the same tool without Go.

## License

MIT
