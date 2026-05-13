# Kickoff Simplified

Simplified KDE Plasma 6 application launcher, forked from **Kickoff**.

Package ID: `org.kde.plasma.kickoff-simplified`

## Features

- Converted to JS+QML
- Compact sidebar layout with a small header (avatar + hover info).
- Fixed-width search field in the footer; search results replace only the
  application pane, so sidebar and footer stay put.
- Single **Leave** button — shutdown, restart, logout, lock, switch user,
  suspend and hibernate all live in one menu.
- Shutdown/restart/logout fade to black, then hand off to your configured
  Plasma splash screen (via `ksplashqml`), bridging smoothly into Plymouth.
- **ALT + drag** any popup edge to resize the window, or the sidebar
  separator to resize the sidebar. Sizes are persisted.
- No "keep open" pin button.
- Removed "highlight new apps" for backward compatibility

## Install

```sh
./install.sh
```

Uninstalls the previous copy, installs `package/`, clears the Plasma qmlcache
and restarts `plasmashell`.

## SLOP Disclaimer

All of this project is produced by AI.
