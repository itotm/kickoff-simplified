# Kickoff Simplified

A KDE Plasma 6 application launcher, forked from the standard **Kickoff** and
rebuilt in pure **QML / JavaScript** on top of the public Plasma, Kirigami and
kicker modules — no custom C++ backend.

Package ID: `org.kde.plasma.kickoff-simplified`

## Features

- **Compact, sidebar-style layout** with a smaller header (avatar + hover info,
  no large profile block) and reduced paddings.
- **Search field in the footer** at a fixed 12 grid-units width, with the
  Configure button placed next to it.
- **Single "Session" button** — shutdown, restart, log out, lock, switch user,
  suspend and hibernate are all collapsed into one overflow menu.
- **Fade-to-black overlay** on shutdown / restart / logout (1 s, cancel with
  click or `Esc`). Toggle in *Configure → General → Fade to black on exit*.
- **ALT + drag** on any popup edge to resize the window, and on the sidebar
  separator to resize the sidebar. Sizes are persisted (`customWidth`,
  `customHeight`, `customSideBarWidth`).
- **Pin / "keep open" button removed**; minimum popup width keeps the search
  field always fully usable.

## Install

```sh
bash install.sh
```

Removes any previous install, installs `package/`, clears the Plasma qmlcache
and restarts `plasmashell`.

## License

Same as upstream Kickoff: **GPL-2.0-or-later**.

## Disclaimer

This fork — including the refactors, the fade-to-black overlay, the ALT-drag
resize logic and this README — was produced with heavy assistance from an AI
coding assistant. It has been tested on a KDE Plasma 6 Wayland session, but
please review the diff before installing it on a machine you care about.
