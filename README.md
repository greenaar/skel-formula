# skel formula

Manages `/etc/skel/.bashrc` (and `/etc/skel/.bashrc_default`) — the
template bash profile copied into **newly created** user home directories
(by `useradd`/`adduser` at account creation time). It does not touch
`~/.bashrc` for any account that already exists; re-running this formula
only changes what future `useradd` calls copy in.

## Usage

```yaml
base:
  '*':
    - skel
```

No pillar is required — see `pillar.example` for the optional knobs.

## How the two files fit together

`/etc/skel/.bashrc` is a small **loader** — it doesn't contain the actual
profile content, just a guarded, ordered series of
`[ -f FILE ] && . FILE` includes:

1. `/etc/skel/.bashrc_default`, if enabled — either this formula's
   built-in default body, or a `custom_source` you supply instead.
2. Whatever paths you list in `includes`, in order.

Keeping the loader separate from the content means replacing the default
body, or layering extra files on top, never means hand-editing the
managed loader file itself.

## Pillar keys

| Key | Default | Description |
|---|---|---|
| `enabled` | `True` | `True` manages both files; `False` removes them (`file.absent`). |
| `mode` | `'0644'` | File mode for both files. **Always quote this** — see below. |
| `editor` | `nano` | Sets `$EDITOR`/`$VISUAL` in the default body (built-in or `custom_source`). |
| `ssh_agent_autostart` | `False` | See below before turning this on. |
| `use_default` | `True` | `False` skips the built-in body entirely (ignored if `custom_source` is set). |
| `custom_source` | *(unset)* | A `salt://` path that fully replaces the built-in body. Rendered with `template: jinja` and the same `editor`/`ssh_agent_autostart` context, so it can use them too if useful — it doesn't have to. |
| `includes` | `[]` | Ordered list of extra paths conditionally sourced after the body, e.g. `$HOME/.bashrc_local` so each user can layer in their own tweaks without anyone touching the managed files. |

## Two things to watch for

**Quote `mode` anyway, even though Salt happens to save you here.**
Unquoted, a leading-zero number like `0644` is ambiguous YAML — plain
PyYAML reads it as octal (`493`). Salt's actual parser
(`SaltYamlSafeLoader`) instead strips the leading zero and reads it as
decimal (`644`), and `file.managed`'s `mode` handling
(`normalize_mode()`) re-pads whatever digits it gets back to 4 characters
— so `0644`/`644`/`'0644'` all end up chmod'd identically in practice.
That's a deliberate, if obscure, pairing inside Salt, not something to
depend on: `mode: '0644'` is unambiguous on sight and isn't relying on
that pairing existing everywhere the value might flow.

**`ssh_agent_autostart` is off by default on purpose.** The built-in
default body unconditionally auto-started an `ssh-agent` and ran
`ssh-add` on every new interactive shell that didn't already have one
running with a key loaded. That means a passphrase prompt — or an
`ssh-add` error, for accounts with no key at all — every time someone
opens a new terminal. Reasonable for a single personal workstation
account, surprising behavior to push out to every account on a
fleet-managed skel. It's gated behind `skel:ssh_agent_autostart` (default
`False`); flip it on only for the pillar target(s) where you actually
want it. This only affects the built-in default body — a `custom_source`
you supply is responsible for its own behavior.

## What else changed from the original file

- Fixed a stray leftover `7` token sitting in front of an `echo` in the
  `extract()` function's error branch — a copy-paste artifact that would
  have run `7` as a command (and failed) instead of printing the intended
  message.
- Removed a duplicated `shopt -s checkwinsize` line.
- Split the single static file into a loader (`.bashrc`) + body
  (`.bashrc_default`) so the body can be replaced or extended from
  pillar without editing the formula.

## Interaction with the `users` formula

If you also use a `users` formula (e.g. `saltstack-formulas/users-formula`)
to create accounts, two things matter:

1. **Ordering.** `/etc/skel/*` only affects a home directory at the moment
   the account is created (`useradd -m` / Salt's `user.present` with
   `createhome: True`). If a brand-new user is created in the *same*
   highstate run as this formula, make sure `skel` is applied — or at
   least ordered — before that user is created, otherwise the new account
   gets whatever `/etc/skel/.bashrc` already existed on disk (the OS
   default, not this formula's), and there's no going back without
   hand-editing that one account's `~/.bashrc` afterward.

2. **`manage_bashrc` wins, not merges.** If the `users` formula's
   `users:<name>:manage_bashrc: true` is set for an account, its
   `bashrc.sls` overwrites that user's `~/.bashrc` outright with its own
   content on every highstate — completely replacing whatever `/etc/skel`
   gave the account at creation time. The two mechanisms don't layer:
   pick one per account. If you want a user to get this formula's
   default *and* per-user management, point that account's
   `salt://users/files/bashrc/<name>/bashrc` override at a loader that
   sources `/etc/skel/.bashrc_default` itself, the same way this
   formula's own `.bashrc` does.

## Sample pillar

See `pillar.example`.

## Relationship to upstream

**This formula was written from scratch for one specific deployment. It is
not a fork of anything, and there is no upstream to fall back to.**

There is no formula of this name in the
[saltstack-formulas](https://github.com/saltstack-formulas) project. What it borrows from that project is
convention, not code: the `map.jinja` + `defaults.yaml` pattern, pillar as
the single override surface, and the general layout. Anything that did come
from elsewhere is noted in the file headers.

Its states, pillar keys, and defaults are shaped around the deployment it
was built for. Read `pillar.example` before pointing it at anything you
care about — it has had far less exposure than a widely-used formula, so
expect rough edges on platforms other than the ones it was written against.

### Credit

The structure and conventions come from the
[saltstack-formulas](https://github.com/saltstack-formulas) project; credit for that groundwork belongs to
its authors and contributors.

## License

Dedicated to the public domain under [CC0 1.0 Universal](LICENSE).
