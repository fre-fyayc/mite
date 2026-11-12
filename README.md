# mite

A small macOS menu-bar timer for [mite](https://mite.de). It replaces the part of mite.nano that does not fit this workflow: a short list of customer-or-project plus service pairs, then a ticket or note, then the timer starts.

Version 0.4.

## What's new in 0.4

**Working time.** Start it in the morning, pause it for a break, and stop it when the day is done. The clock keeps running while the Mac is idle, asleep, or closed, and while the app is quit. It stops on its own after 10 hours and 45 minutes. This clock is the whole day, separate from the project timer, and it does not round. Set daily hours, such as 8, and the menu-bar time turns red after that. If the day is longer than the minutes booked on projects, add the exact difference to one pair.

## What's new in 0.3

**Pause, finish, and resume.** Pause stops the clock and keeps the minutes already tracked. Finish is what rounds the time up, and it rounds the whole entry, including earlier runs of the same task. **Today** lists those entries. Choose one to continue it, with the same note. Starting another pair, or resuming a different entry, also leaves the previous minutes unrounded.

## What's new in 0.2

**Round up to 15 minutes.** Stop saved the next full block instead of the exact elapsed time. One second through 15:00 became 15 minutes, and 15:01 became 30. The menu bar still showed the real elapsed time. In 0.2, stopping or starting another pair wrote that rounded block. Version 0.3 keeps the rounding for Finish only.

## What you can do

Click the timer icon in the menu bar and pick a saved pair, such as **Customer — Service**. Type a ticket id or a short note. Return starts the timer in your mite account. The icon shows how long this run has lasted.

**Pause** stops the run and leaves the minutes mite has counted. The entry stays under **Today**. Choose it to continue the same note and the same project. A coffee break does not add a full block. Starting another pair, or another entry from today, pauses the running one the same way.

**Round up to 15 minutes** is a menu switch. When it is on, **Finish · 30 min** is the block written when the task is done. One second through 15:00 becomes 15 minutes, and 15:01 becomes 30. That total includes time already saved on the entry. The menu bar still shows only the current run. When the switch is off, **Stop** saves the exact minutes.

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

Do this once, and again after you download a newer version. Afterward the timer starts like any other Mac app, and the Terminal window can be closed.

Open **Terminal**. Press Command-Space, type `Terminal`, and press Return. Paste this line and press Return. Change the path so it points at the folder where you downloaded this project.

```bash
~/path/to/mite-menu/install.sh
```

The script builds the app, replaces **Mite Menu**, and opens it. If the timer is already running, the script quits it first so the new version starts. The two lines about a missing search path can be ignored. Wait until the timer icon appears in the menu bar.

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
  "standardMinutes": 480,
  "differenceProjectId": 1002,
  "differenceServiceId": 12,
  "pairs": [
    { "label": "Customer — Consulting", "projectId": 1001, "serviceId": 10 },
    { "label": "Internal — Meetings", "projectId": 1002, "serviceId": 11 },
    { "label": "Internal — Administration", "projectId": 1002, "serviceId": 12 }
  ]
}
```

Each pair has a `label`, a `projectId`, and a `serviceId`. The same project can appear twice when it uses two services.

Leave out `roundUpMinutes`, or set it to `0`, to store the exact tracked minutes. Any positive number is the block size. The menu switch writes `15` or removes the key.

`standardMinutes` and the difference ids belong to working time, described below. Leave them out to skip both.

A pair whose project or service is no longer active is shown as unavailable.

## Working time

The project timer tracks one mite entry. Working time is the whole day. It does not round.

**Start working time** begins the day. **Pause working time** is a break. **Resume working time** continues it. **Stop working time** ends the day. The clock is the time of day. It keeps running while the Mac is idle, asleep, or shut down, and while this app is not open. Closing the notebook sleeps the Mac. The closed time is counted when it wakes. Quit does not end the day, so choose Stop when the day is done. After 10 hours and 45 minutes the clock stops at that time, and later time is left out, including time the Mac spent asleep. The menu then says stopped at 10:45. Resume on the same day continues past that limit. The time already counted is kept.

The menu bar shows this time in front of the project timer. Choose **Daily hours…** and enter a target, for example `8` or `7:30`. After that long, the time turns red.

Booked project time can be shorter than the day. Choose the pair that should receive the difference, then choose **Add 18 min to Customer — Service**. The minutes are exact. mite stores them on that pair with the note `Working time`. Choosing it again the same day adds any new difference to that entry.

The previous day stays in the menu until you start the next one, including after you open the Mac the next morning. The difference is written on that day. **Start working time** then begins the new day.

```json
"standardMinutes": 480,
"differenceProjectId": 1002,
"differenceServiceId": 12
```

`standardMinutes` is the daily target. 480 is 8 hours. Leave it out to keep the clock one color. The two ids pick a pair from the list. Leave them out until you want the difference written to mite. The settings window writes all three.

## License

MIT. See [LICENSE](LICENSE).
