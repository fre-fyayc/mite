# mite

A small macOS menu-bar timer for [mite](https://mite.de). It replaces the part of mite.nano that does not fit this workflow: a short list of customer-or-project plus service pairs, then a ticket or note, then the timer starts.

Version 0.2.

## What's new in 0.2

**Round up to 15 minutes.** Stop saves the next full block instead of the exact elapsed time. One second through 15:00 becomes 15 minutes, and 15:01 becomes 30. The menu bar still shows the real elapsed time. **Stop · 30 min** is the amount written to mite. Starting another pair rounds the running entry before the new one starts. The menu switch turns this on and off.

## What you can do

Click the timer icon in the menu bar and pick a saved pair, such as **Customer — Service**. Type a ticket id or a short note. Return starts the timer in your mite account. The icon shows the elapsed time. **Stop** ends it. Starting another pair stops the one that is already running.

**Round up to 15 minutes** is a menu switch. When it is on, Stop saves the next full block: 1 second through 15:00 becomes 15 minutes, and 15:01 becomes 30. The menu bar still shows the real elapsed time. **Stop · 30 min** is the amount that will be written to mite. Starting another pair rounds the running entry the same way before the new one starts.

Pairs are not chosen in two steps. Each menu row is one project and one service. The same project can be saved again with a different service.

## Requirements

- macOS 13 or later
- Swift, from the Xcode Command Line Tools
- A mite user with API access turned on

## Run

```bash
swift run
```

Leave that terminal open. Quit from the menu.

## Install the app

Do this once, and again only after you download a newer version. Afterward the timer starts like any other Mac app, and the Terminal window can be closed.

1. If a timer is already running, open its menu and choose **Quit**.
2. Open **Terminal**. Press Command-Space, type `Terminal`, and press Return.
3. Copy this whole block, paste it into Terminal, and press Return. The two lines about a missing search path can be ignored. Wait until the last line finishes and the timer icon appears in the menu bar.

```bash
cd ~/path/to/mite-menu
swift build -c release
APP="$HOME/Applications/Mite Menu.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/MiteMenu "$APP/Contents/MacOS/Mite Menu"
cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Mite Menu</string>
  <key>CFBundleIdentifier</key>
  <string>de.mite.menu</string>
  <key>CFBundleName</key>
  <string>Mite Menu</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF
codesign -s - "$APP"
open "$APP"
```

Change the first line so it points at the folder where you downloaded this project.

The app is saved as **Mite Menu** inside the Applications folder in your home folder. In Finder, choose **Go → Home**, then open **Applications**. Double-click **Mite Menu** to start it later. The timer stays in the menu bar at the top of the screen.

To start it every time you log in:

1. Open **System Settings → General → Login Items & Extensions**.
2. Under **Open at Login**, click **+**.
3. Press **Command-Shift-G**, paste the path below, and press Return.

```text
~/Applications/Mite Menu.app
```

Choose **Mite Menu** and confirm.

## Connect once

1. In mite, open your user menu, allow API access, save, and copy the API key.
2. In the menu-bar app, choose **Connect…**.
3. Enter the account subdomain (`your-account` from `https://your-account.mite.de`) and the API key.
4. Choose **Save connection**. The app loads your active projects and services.

The API key is stored in the macOS Keychain. It is not written into this repository or into the config file.

## Pairs

**Add pair** asks for a project and a service, then appends one row. The suggested label is `Customer — Service` when the project has a customer, and `Project — Service` when it does not.

The list lives in `~/.config/mite-menu/config.json`, outside this repository. **Open config** reveals that file in Finder. The menu reads it every time it opens, so you can rename, reorder, or remove rows in any editor.

Use **Add pair** so the app writes each project and service id from your account. `your-account` is the subdomain from `your-account.mite.de`. The numbers below only show the shape of the file. They are not real mite ids.

```json
{
  "account": "your-account",
  "roundUpMinutes": 15,
  "pairs": [
    { "label": "Customer — Consulting", "projectId": 1001, "serviceId": 10 },
    { "label": "Internal — Meetings", "projectId": 1002, "serviceId": 11 },
    { "label": "Internal — Administration", "projectId": 1002, "serviceId": 12 }
  ]
}
```

Each pair has a `label`, a `projectId`, and a `serviceId`. The same project can appear twice when it uses two services.

Leave out `roundUpMinutes`, or set it to `0`, to store the exact tracked minutes. Any positive number is the block size. The menu switch writes `15` or removes the key.

A pair whose project or service is no longer active is shown as unavailable.

## License

MIT. See [LICENSE](LICENSE).
