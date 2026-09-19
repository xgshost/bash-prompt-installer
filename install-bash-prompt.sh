#!/usr/bin/env bash
set -Eeuo pipefail

PROMPT_FILE="/etc/profile.d/xgs-prompt.sh"
BASHRC_FILE="/etc/bash.bashrc"

SYSTEM_BEGIN="# >>> XGS MANAGED BASH PROMPT >>>"
SYSTEM_END="# <<< XGS MANAGED BASH PROMPT <<<"

USER_BEGIN="# >>> XGS USER BASH PROMPT >>>"
USER_END="# <<< XGS USER BASH PROMPT <<<"

if [[ $EUID -ne 0 ]]; then
    printf 'Error: run with sudo or as root.\n' >&2
    exit 1
fi

if [[ ! -f "$BASHRC_FILE" ]]; then
    printf 'Error: %s does not exist; this script is for Ubuntu/Debian systems.\n' \
        "$BASHRC_FILE" >&2
    exit 1
fi

if ! command -v bash >/dev/null 2>&1; then
    printf 'Error: Bash is not installed.\n' >&2
    exit 1
fi

TMP_PROMPT="$(mktemp)"
TMP_SYSTEM_LOADER="$(mktemp)"
TMP_USER_LOADER="$(mktemp)"
BACKUP_DIR=""

cleanup() {
    rm -f "$TMP_PROMPT" "$TMP_SYSTEM_LOADER" "$TMP_USER_LOADER"
}
trap cleanup EXIT

make_backup_dir() {
    if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="/root/xgs-prompt-backups/$(date +%Y%m%d-%H%M%S)"
        install -d -o root -g root -m 0700 "$BACKUP_DIR"
        printf 'Backup directory: %s\n' "$BACKUP_DIR"
    fi
}

backup_file() {
    local source_file="$1"
    local backup_name="$2"

    [[ -e "$source_file" ]] || return 0

    make_backup_dir

    if [[ ! -e "$BACKUP_DIR/$backup_name" ]]; then
        cp -a "$source_file" "$BACKUP_DIR/$backup_name"
    fi
}

has_complete_block() {
    local file="$1"
    local begin="$2"
    local end="$3"

    [[ -f "$file" ]] &&
        grep -Fqx "$begin" "$file" &&
        grep -Fqx "$end" "$file"
}

replace_managed_block() {
    local file="$1"
    local begin="$2"
    local end="$3"
    local new_block="$4"
    local temp_file

    temp_file="$(mktemp)"

    awk -v begin="$begin" -v end="$end" '
        $0 == begin { skip=1; next }
        $0 == end   { skip=0; next }
        !skip       { print }
    ' "$file" > "$temp_file"

    printf '\n' >> "$temp_file"
    cat "$new_block" >> "$temp_file"

    cat "$temp_file" > "$file"
    rm -f "$temp_file"
}

cat > "$TMP_PROMPT" <<'PROMPT_EOF'
# ── XGS two-line Bash prompt ────────────────────────────────────────────────
# Managed system-wide interactive Bash prompt.
# Normal user: lime green, single chevron, $
# Root: red, double chevron, #

case $- in
    *i*) ;;
    *) return ;;
esac

# Show no more than the final four directory components in the prompt path.
PROMPT_DIRTRIM=4

# Colors. Non-printing ANSI escape sequences must remain inside \[ and \].
C_RESET='\[\e[0m\]'
C_NEUTRAL='\[\e[0;37m\]'   # Frame, badge edges, colon, $ / #
C_LIME='\[\e[1;92m\]'      # Normal-user identity
C_RED='\[\e[1;91m\]'       # Root identity
C_HOST='\[\e[1;96m\]'      # Bright cyan hostname
C_PATH='\[\e[0;36m\]'      # Standard/darker cyan path

if [[ $EUID -eq 0 ]]; then
    C_ID="$C_RED"
    PRIV_MARK='»'
    PROMPT_CHAR='#'
else
    C_ID="$C_LIME"
    PRIV_MARK='›'
    PROMPT_CHAR='$'
fi

# Normal:
# ╭─⛨ ❮hostname❯›❮username❯
# ╰─➤ [.../last/four/directories] : $
#
# Root:
# ╭─⛨ ❮hostname❯»❮root❯
# ╰─➤ [.../last/four/directories] : #
PS1="${C_NEUTRAL}╭─${C_ID}⛨${C_NEUTRAL} ❮${C_HOST}\h${C_NEUTRAL}❯${C_ID}${PRIV_MARK}${C_NEUTRAL}❮${C_ID}\u${C_NEUTRAL}❯\n${C_NEUTRAL}╰─➤ ${C_PATH}[\w]${C_NEUTRAL} : ${C_ID}${PROMPT_CHAR}${C_RESET} "
PROMPT_EOF

cat > "$TMP_SYSTEM_LOADER" <<SYSTEM_LOADER_EOF
$SYSTEM_BEGIN
# Load the managed XGS prompt for every interactive Bash session.
if [[ -r $PROMPT_FILE ]]; then
    source $PROMPT_FILE
fi
$SYSTEM_END
SYSTEM_LOADER_EOF

cat > "$TMP_USER_LOADER" <<USER_LOADER_EOF
$USER_BEGIN
# Load the system-wide XGS prompt after the user's own PS1 configuration.
if [[ -r $PROMPT_FILE ]]; then
    source $PROMPT_FILE
fi
$USER_END
USER_LOADER_EOF

# ── Install/update the shared prompt file ───────────────────────────────────
if [[ ! -f "$PROMPT_FILE" ]]; then
    printf 'Prompt file is missing: will create %s\n' "$PROMPT_FILE"
    install -o root -g root -m 0644 "$TMP_PROMPT" "$PROMPT_FILE"
    printf 'Installed prompt file: %s\n' "$PROMPT_FILE"
elif cmp -s "$TMP_PROMPT" "$PROMPT_FILE"; then
    printf 'Prompt file is already current: %s\n' "$PROMPT_FILE"
else
    printf 'Prompt file differs: will update %s\n' "$PROMPT_FILE"
    backup_file "$PROMPT_FILE" "xgs-prompt.sh"
    install -o root -g root -m 0644 "$TMP_PROMPT" "$PROMPT_FILE"
    printf 'Updated prompt file: %s\n' "$PROMPT_FILE"
fi

# ── Install/update the system-wide loader ───────────────────────────────────
if has_complete_block "$BASHRC_FILE" "$SYSTEM_BEGIN" "$SYSTEM_END"; then
    current_system_loader="$(mktemp)"
    sed -n "/^$(printf '%s' "$SYSTEM_BEGIN" | sed 's/[][\/.^$*]/\\&/g')\$/,/^$(printf '%s' "$SYSTEM_END" | sed 's/[][\/.^$*]/\\&/g')\$/p" \
        "$BASHRC_FILE" > "$current_system_loader"

    if cmp -s "$TMP_SYSTEM_LOADER" "$current_system_loader"; then
        printf 'System loader is already current: %s\n' "$BASHRC_FILE"
    else
        printf 'System loader differs: will update %s\n' "$BASHRC_FILE"
        backup_file "$BASHRC_FILE" "bash.bashrc"
        replace_managed_block "$BASHRC_FILE" "$SYSTEM_BEGIN" "$SYSTEM_END" "$TMP_SYSTEM_LOADER"
        printf 'Updated system loader in %s\n' "$BASHRC_FILE"
    fi

    rm -f "$current_system_loader"
else
    printf 'System loader is missing:
