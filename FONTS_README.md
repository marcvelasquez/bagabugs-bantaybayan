# BantayBayan - Font Installation Guide

The app is configured to use **Inter** and **Roboto** fonts for optimal readability in emergency situations.

## Font Files Needed

You need to download and place the following font files in the `fonts/` directory:

### Inter Font
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

Download from: https://fonts.google.com/specimen/Inter

### Roboto Font
- `Roboto-Regular.ttf`
- `Roboto-Medium.ttf`
- `Roboto-Bold.ttf`

Download from: https://fonts.google.com/specimen/Roboto

## Installation Steps

1. Create a `fonts` directory in the project root (if not exists)
2. Download the font files from Google Fonts
3. Extract and copy the `.ttf` files to the `fonts/` directory
4. The fonts are already configured in `pubspec.yaml`

## Alternative: Use System Fonts

If you prefer to use system fonts temporarily, you can comment out the font configuration in `pubspec.yaml` and the app will fall back to system default fonts.

The design will still work, but custom fonts provide better readability and consistency across devices.
