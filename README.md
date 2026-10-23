<div align="center">

<image src="icon.png" height="100"/>

# Baells Chrono

### A modern and powerful clock, alarms, timer and stopwatch app for Android.
![alt text](cover.png)

[<img src="https://i.ibb.co/q0mdc4Z/get-it-on-github.png" alt="Get it on Github" height=64/>](https://github.com/amiraliksr3-ops/Chrono-The-Better/releases/latest)

</div>

Baells Chrono is a fork of the excellent open-source app [Chrono](https://github.com/vicolo-dev/chrono)
by vicolo-dev, with additional tweaks. Note: this fork is a WIP — test it thoroughly on
your device before relying on it for critical alarms.

## Changes over upstream
- 30-second alarm mute with mission-interaction countdown
- Hardened full-screen alarm: harder to accidentally dismiss from lock screen
- Fixed signed release builds and CI release workflow (APKs published per release)

## Build
```sh
flutter run --flavor dev                                  # development
flutter build apk --release --split-per-abi --flavor prod # production
```

## Credits
All original work by [vicolo-dev](https://github.com/vicolo-dev) and
[contributors](https://github.com/vicolo-dev/chrono/graphs/contributors). Licensed under GPLv3.
