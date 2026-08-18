#!/bin/bash

# Package Installation Script
# Leser pacman-packages.txt og aur-packages.txt og installerer alt
# Respekterer INSTALL_MODE=auto|interaktiv fra run-install.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Hent modus — default auto om ikke satt
INSTALL_MODE="${INSTALL_MODE:-auto}"

echo -e "${GREEN}=== Package Installation ===${NC}"
echo -e "${CYAN}    Modus: ${INSTALL_MODE^^}${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$SCRIPT_DIR/pacman-packages.txt"
AUR_LIST="$SCRIPT_DIR/aur-packages.txt"

# Hjelpefunksjon: les pakkeliste (ignorerer kommentarer og tomme linjer)
read_package_list() {
    local file="$1"
    [ ! -f "$file" ] && return
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$' | awk '{print $1}'
}

# Hjelpefunksjon: spør kun i interaktiv modus
spor() {
    local sporsmal="$1"
    if [ "$INSTALL_MODE" = "interaktiv" ]; then
        read -rp "$sporsmal [J/n]: " svar
        svar=${svar:-J}
        [[ "$svar" =~ ^[JjYy]$ ]]
    else
        return 0  # AUTO: alltid ja
    fi
}

# ── Pacman pakker ─────────────────────────────────────────────────────────────
if [ -f "$PACMAN_LIST" ]; then
    echo -e "${CYAN}=== Installerer Pacman pakker ===${NC}"
    echo ""

    PACMAN_PKGS=$(read_package_list "$PACMAN_LIST")

    if [ -n "$PACMAN_PKGS" ]; then
        echo -e "${YELLOW}Pakker som vil bli installert:${NC}"
        echo "$PACMAN_PKGS" | tr '\n' ' '
        echo ""
        echo ""

        if spor "Installer alle pacman-pakker?"; then
            PKG_STRING=$(echo "$PACMAN_PKGS" | tr '\n' ' ')
            echo -e "${GREEN}Installerer...${NC}"
            sudo pacman -S --needed --noconfirm $PKG_STRING

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Pacman pakker installert${NC}"
            else
                echo -e "${RED}✗ Noen pakker feilet${NC}"
            fi
        else
            echo -e "${YELLOW}Hoppet over pacman pakker${NC}"
        fi
    else
        echo -e "${YELLOW}Ingen pacman pakker å installere${NC}"
    fi
else
    echo -e "${YELLOW}Ingen pacman-packages.txt fil funnet${NC}"
fi

echo ""

# ── Sjekk / installer yay ─────────────────────────────────────────────────────
if ! command -v yay &> /dev/null && ! command -v paru &> /dev/null; then
    echo -e "${YELLOW}Ingen AUR helper (yay/paru) funnet${NC}"

    if spor "Installer yay (AUR helper)?"; then
        echo -e "${GREEN}Installerer yay...${NC}"
        sudo pacman -S --needed --noconfirm base-devel git
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd "$SCRIPT_DIR"

        if command -v yay &> /dev/null; then
            echo -e "${GREEN}✓ yay installert${NC}"
        else
            echo -e "${RED}✗ yay installasjon feilet${NC}"
            echo -e "${YELLOW}Hopper over AUR pakker${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}Hopper over AUR pakker (ingen AUR helper)${NC}"
        exit 0
    fi
fi

# ── AUR pakker ────────────────────────────────────────────────────────────────
if [ -f "$AUR_LIST" ]; then
    echo ""
    echo -e "${CYAN}=== Installerer AUR pakker ===${NC}"
    echo ""

    AUR_PKGS=$(read_package_list "$AUR_LIST")

    if [ -n "$AUR_PKGS" ]; then
        echo -e "${YELLOW}Pakker som vil bli installert:${NC}"
        echo "$AUR_PKGS" | tr '\n' ' '
        echo ""
        echo ""

        if spor "Installer alle AUR-pakker?"; then
            while IFS= read -r pkg; do
                if [ -n "$pkg" ]; then
                    echo ""
                    echo -e "${GREEN}Installerer: $pkg${NC}"
                    if command -v yay &> /dev/null; then
                        yay -S --needed --noconfirm --answerdiff=None --answerclean=None --answeredit=None --answerupgrade=None "$pkg"
                    elif command -v paru &> /dev/null; then
                        paru -S --needed --noconfirm "$pkg"
                    fi
                fi
            done <<< "$AUR_PKGS"
            echo ""
            echo -e "${GREEN}✓ AUR pakker installert${NC}"
        else
            echo -e "${YELLOW}Hoppet over AUR pakker${NC}"
        fi
    else
        echo -e "${YELLOW}Ingen AUR pakker å installere${NC}"
    fi
else
    echo -e "${YELLOW}Ingen aur-packages.txt fil funnet${NC}"
fi

echo ""
echo -e "${GREEN}=== Installasjon fullført! ===${NC}"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  - Rediger pacman-packages.txt for å legge til/fjerne pakker"
echo "  - Rediger aur-packages.txt for å legge til/fjerne AUR pakker"
echo "  - Kjør scriptet igjen for å installere nye pakker"
echo "  - Pakker som allerede er installert hoppes over (--needed)"
