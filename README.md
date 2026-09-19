# Bash Prompt Installer

An idempotent installer for a colorful two-line Bash prompt on Ubuntu and Debian systems.

## Prompt preview

Normal user:

```text
╭─⛨ ❮server-01❯›❮admin❯
╰─➤ [.../project/current-directory] : $
```

Root:

```text
╭─⛨ ❮server-01❯»❮root❯
╰─➤ [.../etc/nginx/sites-enabled] : #
```

## Features

- System-wide prompt definition in `/etc/profile.d/xgs-prompt.sh`
- Ubuntu/Debian Bash loader in `/etc/bash.bashrc`
- Final user-level loader in `/root/.bashrc`
- Final user-level loader for the account that runs the installer with `sudo`
- Lime-green normal-user identity and red root identity
- Bright-cyan hostname and darker-cyan path
- Last four directory components in the prompt path
- Timestamped backups before files are changed
- Idempotent: safe to run repeatedly without duplicate loader blocks

## Install

Download the script, inspect it, then run it:

```bash
curl -fsSLO [https://raw.githubusercontent.com/xgshost/bash-prompt-installer/main/install-bash-prompt.sh](https://raw.githubusercontent.com/xgshost/bash-prompt-installer/main/install-bash-prompt.sh)
less install-bash-prompt.sh
sudo bash install-bash-prompt.sh
```

Start a fresh Bash session after installation:

```bash
exec bash
```

Test the root prompt:

```bash
sudo -i
```

## Files changed

The installer may create or update:

```text
/etc/profile.d/xgs-prompt.sh
/etc/bash.bashrc
/root/.bashrc
/home/YOUR-USER/.bashrc
```

Backups are stored beneath:

```text
/root/bash-prompt-backups/
```

## Requirements

- Ubuntu or Debian
- Bash
- `sudo` access
- UTF-8 terminal font with support for the prompt glyphs

## Security note

Review downloaded scripts before running them with `sudo`. Do not run code from a repository you do not trust.

## License

MIT
