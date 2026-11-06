# mite

A small macOS menu-bar timer for [mite](https://mite.de). It replaces the part of mite.nano that does not fit this workflow: a short list of customer-or-project plus service pairs, then a ticket or note, then the timer starts.

Version 0.1.

## What you can do

Click the timer icon in the menu bar and pick a saved pair, for example **Acme — Consulting** or **Internal — Meetings**. Type a ticket id or a short note. Return starts the timer in your mite account. The icon shows the elapsed time. **Stop** ends it. Starting another pair stops the one that is already running.

Pairs are not chosen in two steps. Each menu row is one project and the one service that belongs with it. External customers are saved once each, with Consulting. Internal work is the same project saved once for each service you use.

## Requirements

- macOS 13 or later
- Swift, from the Xcode Command Line Tools
- A mite user with API access turned on

## Run

```bash
swift run
```

Leave that terminal open. Quit from the menu.

## Connect once

1. In mite, open your user menu, allow API access, save, and copy the API key.
2. In the menu-bar app, choose **Connect…**.
3. Enter the account subdomain (`company` from `https://company.mite.de`) and the API key.
4. Choose **Save connection**. The app loads your active projects and services.

The API key is stored in the macOS Keychain. It is not written into this repository or into the config file.

## Pairs

**Add pair** asks for a project and a service, then appends one row. The suggested label is `Customer — Service` when the project has a customer, and `Project — Service` when it does not.

The list lives in `~/.config/mite-menu/config.json`. **Open config** reveals that file in Finder. The menu reads it every time it opens, so you can rename, reorder, or remove rows in any editor.

```json
{
  "account": "company",
  "pairs": [
    { "label": "Acme — Consulting", "projectId": 101, "serviceId": 3 },
    { "label": "Internal — Meetings", "projectId": 50, "serviceId": 8 },
    { "label": "Internal — Admin", "projectId": 50, "serviceId": 9 }
  ]
}
```

A pair whose project or service is no longer active is shown as unavailable.

## License

MIT. See [LICENSE](LICENSE).
