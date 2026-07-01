#!/usr/bin/env bash
# verify-config.sh — Check NixOS + Hyprland config for common issues before rebuild
# Usage: ./verify-config.sh [--lua-only|--nix-only|--full]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Repo root is 4 levels up from .pi/skills/nixos-hyprland/scripts/
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
HOSTNAME="$(hostname)"
LUA_SRC="$REPO_ROOT/home/files/hyprland.lua"
LUA_DEPLOYED="$HOME/.config/hypr/hyprland.lua"

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARN=$((WARN + 1)); }

header() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

# ─── Source vs deployed comparison ───
compare_files() {
    header "Source vs Deployed"
    if [ -f "$LUA_SRC" ] && [ -f "$LUA_DEPLOYED" ]; then
        if diff -q "$LUA_SRC" "$LUA_DEPLOYED" &>/dev/null; then
            pass "hyprland.lua: source matches deployed"
        else
            warn "hyprland.lua: source differs from deployed (rebuild needed)"
            echo "    Source:    $LUA_SRC"
            echo "    Deployed:  $LUA_DEPLOYED"
            echo "    Run: diff $LUA_SRC $LUA_DEPLOYED"
        fi
    elif [ -f "$LUA_SRC" ]; then
        warn "hyprland.lua: source exists but not deployed yet"
    elif [ -f "$LUA_DEPLOYED" ]; then
        warn "hyprland.lua: deployed exists but no source found in repo"
    else
        fail "hyprland.lua: not found anywhere"
    fi
}

# ─── Lua syntax check ───
check_lua_syntax() {
    header "Lua Syntax Check"
    
    # Best check: use Hyprland's built-in --verify-config (full validation)
    if command -v Hyprland &>/dev/null; then
        if [ -f "$LUA_DEPLOYED" ]; then
            local result
            result=$(Hyprland --verify-config -c "$LUA_DEPLOYED" 2>&1) || true
            if echo "$result" | grep -q "config ok"; then
                pass "Hyprland --verify-config: config ok"
            else
                fail "Hyprland --verify-config: errors found"
                echo "$result" | grep -v "^\[" | head -10
            fi
        elif [ -f "$LUA_SRC" ]; then
            if Hyprland --verify-config -c "$LUA_SRC" 2>&1 | grep -q "config ok"; then
                pass "Hyprland --verify-config (source): config ok"
            else
                fail "Hyprland --verify-config (source): errors found"
            fi
        fi
        return
    fi
    
    # Fallback: basic Lua parse check (no Hyprland API context)
    local file_to_check=""
    if [ -f "$LUA_SRC" ]; then
        file_to_check="$LUA_SRC"
    elif [ -f "$LUA_DEPLOYED" ]; then
        file_to_check="$LUA_DEPLOYED"
    else
        fail "No hyprland.lua found to check"
        return
    fi

    if ! command -v lua &>/dev/null && ! command -v luajit &>/dev/null; then
        warn "lua/luajit not installed — cannot check syntax"
        return
    fi

    local lua_cmd="lua"
    command -v luajit &>/dev/null && lua_cmd="luajit"

    if "$lua_cmd" -e "
        local f, err = loadfile('$file_to_check')
        if not f then
            print('SYNTAX ERROR: ' .. err)
            os.exit(1)
        end
    " 2>&1; then
        pass "Lua syntax (basic): valid"
    else
        fail "Lua syntax (basic): errors found"
    fi
}

# ─── Check for duplicate keybinds ───
check_duplicate_binds() {
    header "Duplicate Keybind Check"
    
    local file="${1:-$LUA_SRC}"
    if [ ! -f "$file" ]; then
        file="$LUA_DEPLOYED"
        [ ! -f "$file" ] && { fail "No hyprland.lua to check"; return; }
    fi

    # Extract key combos from hl.bind() calls
    local binds
    binds=$(grep -oP 'hl\.bind\("([^"]+)"' "$file" | grep -oP '(?<=")[^"]+' | sort)
    
    local dups
    dups=$(echo "$binds" | uniq -d)
    
    if [ -z "$dups" ]; then
        pass "No duplicate keybinds found"
    else
        while IFS= read -r dup; do
            warn "Duplicate keybind: $dup"
        done <<< "$dups"
    fi
}

# ─── Check referenced commands exist ───
check_commands() {
    header "Command Availability Check"
    
    local file="${1:-$LUA_SRC}"
    if [ ! -f "$file" ]; then
        file="$LUA_DEPLOYED"
        [ ! -f "$file" ] && { fail "No hyprland.lua to check"; return; }
    fi

    # Extract commands from hl.dsp.exec_cmd() and hl.exec_cmd()
    local cmds
    cmds=$(grep -oP 'hl\.(?:dsp\.)?exec_cmd\("([^"]+)"' "$file" | grep -oP '(?<=")[^"]+' | grep -oP '^[^\s|;&]+' | sort -u)
    
    [ -z "$cmds" ] && { warn "No exec_cmd calls found"; return; }
    
    while IFS= read -r cmd; do
        # Skip compound commands (with |, ;, &&)
        if echo "$cmd" | grep -qE '[|;&]'; then
            # Extract the first command of a pipeline
            local first_cmd
            first_cmd=$(echo "$cmd" | awk '{print $1}')
            if command -v "$first_cmd" &>/dev/null; then
                pass "Pipeline: '$cmd' (first cmd '$first_cmd' found)"
            else
                warn "Pipeline: '$cmd' (first cmd '$first_cmd' not found in PATH)"
            fi
        elif command -v "$cmd" &>/dev/null; then
            pass "Command found: $cmd"
        else
            # Might be a path or not installed yet
            warn "Command not in PATH (may need rebuild): $cmd"
        fi
    done <<< "$cmds"
}

# ─── Check theme.json references ───
check_theme() {
    header "Theme Validation"
    
    local theme="$REPO_ROOT/theme.json"
    if [ ! -f "$theme" ]; then
        fail "theme.json not found"
        return
    fi

    if command -v jq &>/dev/null; then
        if jq empty "$theme" 2>/dev/null; then
            pass "theme.json: valid JSON"
        else
            fail "theme.json: invalid JSON"
            return
        fi
        
        local colors
        colors=$(jq -r '.colors | keys[]' "$theme" 2>/dev/null)
        if [ -n "$colors" ]; then
            pass "theme.json: $(echo "$colors" | wc -l) colors defined"
        fi
        
        local font
        font=$(jq -r '.font.family' "$theme" 2>/dev/null)
        [ -n "$font" ] && pass "theme.json: font family set ($font)"
        
        local opacity
        opacity=$(jq -r '.opacity' "$theme" 2>/dev/null)
        [ -n "$opacity" ] && pass "theme.json: opacity set ($opacity)"
    else
        warn "jq not installed — skipping theme validation"
    fi
}

# ─── Nix flake check ───
check_flake() {
    header "Nix Flake Validation"
    
    if ! command -v nix &>/dev/null; then
        fail "nix not found — is this a NixOS system?"
        return
    fi

    echo "  Running 'nix flake check' (may take a moment)..."
    cd "$REPO_ROOT"
    if nix flake check --no-build 2>&1; then
        pass "nix flake check: passed"
    else
        fail "nix flake check: failed"
    fi
}

# ─── Check host-specific files ───
check_host_files() {
    header "Host-specific Config ($HOSTNAME)"
    
    local host_lua_src="$REPO_ROOT/hosts/$HOSTNAME/home/hypr-host.lua"
    
    if [ -f "$host_lua_src" ]; then
        pass "Host Lua source: $host_lua_src"
        # Basic syntax check
        if command -v lua &>/dev/null || command -v luajit &>/dev/null; then
            local lua_cmd="lua"
            command -v luajit &>/dev/null && lua_cmd="luajit"
            if "$lua_cmd" -e "local f, err = loadfile('$host_lua_src'); if not f then print(err); os.exit(1) end" 2>&1; then
                pass "Host Lua syntax: valid"
            else
                fail "Host Lua syntax: errors found"
            fi
        fi
    else
        warn "No host-specific Lua file: $host_lua_src"
    fi
    
    local host_lua_deployed="$HOME/.config/hypr/host.lua"
    if [ -f "$host_lua_deployed" ]; then
        pass "Host Lua deployed: $host_lua_deployed"
    else
        info_icon=""
        [ -f "$host_lua_src" ] && warn "Host Lua not deployed (rebuild needed)"
    fi
}

# ─── Check running services ───
check_services() {
    header "Hyprland Services Status"
    
    # Only check if we're in a Hyprland session
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        warn "Not running in Hyprland — skipping service checks"
        return
    fi

    for svc in waybar hypridle hyprpaper swaync; do
        if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
            pass "Service running: $svc"
        else
            warn "Service not running: $svc"
        fi
    done
    
    # hyprshell
    if pgrep -x hyprshell &>/dev/null; then
        pass "Service running: hyprshell"
    else
        warn "Service not running: hyprshell"
    fi
}

# ─── Summary ───
summary() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Results: ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL failed${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$FAIL" -gt 0 ]; then
        echo -e "\n${RED}⚠ Some issues need attention before rebuild${NC}"
        exit 1
    elif [ "$WARN" -gt 0 ]; then
        echo -e "\n${YELLOW}⚠ Review warnings before rebuild${NC}"
        exit 0
    else
        echo -e "\n${GREEN}✓ All checks passed — ready to rebuild${NC}"
        exit 0
    fi
}

# ─── Main ───
MODE="${1:---full}"

case "$MODE" in
    --lua-only)
        check_lua_syntax
        check_duplicate_binds
        check_commands
        compare_files
        ;;
    --nix-only)
        check_flake
        check_theme
        ;;
    --full)
        check_lua_syntax
        check_duplicate_binds
        check_commands
        compare_files
        check_host_files
        check_theme
        check_flake
        check_services
        ;;
    --help|-h)
        echo "Usage: $0 [--lua-only|--nix-only|--full]"
        echo ""
        echo "  --lua-only   Check only Hyprland Lua config"
        echo "  --nix-only   Check only Nix/Flake config"
        echo "  --full       Run all checks (default)"
        exit 0
        ;;
    *)
        echo "Unknown option: $MODE"
        echo "Usage: $0 [--lua-only|--nix-only|--full]"
        exit 1
        ;;
esac

summary
