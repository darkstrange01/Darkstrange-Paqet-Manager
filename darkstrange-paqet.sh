#!/bin/bash

################################################################################
#                                                                              #
#                          DARKSTRANGE PAQET MANAGER                           #
#                    Complete Paqet Tunnel Management System                   #
#                                 Version 2.3.0                                #
#                                                                              #
################################################################################

VERSION="2.3.0"
CONFIG_DIR="/etc/darkstrange-paqet"
CONFIG_FILE="${CONFIG_DIR}/tunnels.conf"
PAQET_VERSION_FILE="${CONFIG_DIR}/paqet_version"
LOG_FILE="/var/log/darkstrange-paqet.log"
SERVICE_DIR="/etc/systemd/system"
PAQET_BIN="/usr/local/bin/paqet"
PAQET_CONFIG_DIR="/etc/paqet"
SCRIPT_PATH="$(readlink -f "$0")"
GITHUB_REPO="hanselime/paqet"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Global
_SELECTED_CRON=""

################################################################################
# ASCII Art Banner
################################################################################
show_banner() {
    clear

    local has_figlet=0
    local has_lolcat=0

    if timeout 2 command -v figlet &>/dev/null; then
        has_figlet=1
    fi

    if timeout 2 command -v lolcat &>/dev/null; then
        has_lolcat=1
    fi

    if [ $has_figlet -eq 1 ] && [ $has_lolcat -eq 1 ]; then
        timeout 3 figlet -w 236 -f slant "DARKSTRANGE" 2>/dev/null | lolcat -F 0.3 2>/dev/null || show_banner_fallback
    else
        show_banner_fallback
    fi

    echo ""

    local paqet_ver=$(get_installed_version)
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}           Paqet Tunnel Management System v${VERSION}${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}Paqet Core: ${GREEN}${paqet_ver}${WHITE}    |    Script: ${GREEN}v${VERSION}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_banner_fallback() {
    echo -e "${PURPLE}"
    cat << "EOF"
    ____  ___    ____  __ _________________  ___    _   ______________
   / __ \/   |  / __ \/ //_/ ___/_  __/ __ \/   |  / | / / ____/ ____/
  / / / / /| | / /_/ / ,<  \__ \ / / / /_/ / /| | /  |/ / / __/ __/
 / /_/ / ___ |/ _, _/ /| |___/ // / / _, _/ ___ |/ /|  / /_/ / /___
/_____/_/  |_/_/ |_/_/ |_/____//_/ /_/ |_/_/  |_/_/ |_/\____/_____/
EOF
    echo -e "${NC}"
}

################################################################################
# Logging
################################################################################
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
    log "ERROR: $1"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
    log "SUCCESS: $1"
}

print_info() {
    echo -e "${YELLOW}[i] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

################################################################################
# Root Check
################################################################################
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        echo -e "${YELLOW}Try: sudo $0${NC}"
        exit 1
    fi
}

################################################################################
# Network Helpers
################################################################################
download_file() {
    local url="$1"
    local output="$2"

    if command -v wget &>/dev/null; then
        wget -q "$url" -O "$output" 2>/dev/null
        return $?
    elif command -v curl &>/dev/null; then
        curl -sL "$url" -o "$output" 2>/dev/null
        return $?
    fi
    return 1
}

fetch_url() {
    local url="$1"

    if command -v curl &>/dev/null; then
        curl -s "$url" 2>/dev/null
        return $?
    elif command -v wget &>/dev/null; then
        wget -qO- "$url" 2>/dev/null
        return $?
    fi
    return 1
}

################################################################################
# OS & Architecture Detection
################################################################################
detect_os() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$os" in
        linux)  echo "linux" ;;
        darwin) echo "darwin" ;;
        *)      echo "" ;;
    esac
}

detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)              echo "amd64" ;;
        aarch64|arm64)       echo "arm64" ;;
        armv7*|armv6*)       echo "arm32" ;;
        mips64el|mips64le)   echo "mips64le" ;;
        mips64)              echo "mips64" ;;
        mipsel|mipsle)       echo "mipsle" ;;
        mips)                echo "mips" ;;
        *)                   echo "" ;;
    esac
}

################################################################################
# Paqet Version Management
################################################################################
get_installed_version() {
    if [ -f "$PAQET_VERSION_FILE" ]; then
        cat "$PAQET_VERSION_FILE"
    elif [ -f "$PAQET_BIN" ]; then
        echo "unknown"
    else
        echo "not installed"
    fi
}

get_latest_version() {
    local response=$(fetch_url "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")
    echo "$response" | grep '"tag_name"' | head -1 | cut -d'"' -f4
}

get_available_versions() {
    local response=$(fetch_url "https://api.github.com/repos/${GITHUB_REPO}/releases")
    echo "$response" | grep '"tag_name"' | cut -d'"' -f4
}

install_paqet_version() {
    local version="$1"
    local os=$(detect_os)
    local arch=$(detect_arch)

    if [ -z "$os" ]; then
        print_error "Unsupported operating system: $(uname -s)"
        return 1
    fi

    if [ -z "$arch" ]; then
        print_error "Unsupported architecture: $(uname -m)"
        return 1
    fi

    print_info "Detected platform: ${os}-${arch}"

    local filename="paqet-${os}-${arch}-${version}.tar.gz"
    local url="https://github.com/${GITHUB_REPO}/releases/download/${version}/${filename}"

    cd /tmp || return 1
    rm -f paqet-*.tar.gz paqet_* 2>/dev/null

    print_info "Downloading ${filename}..."
    download_file "$url" "$filename"

    if [ $? -ne 0 ] || [ ! -s "$filename" ]; then
        print_error "Failed to download paqet ${version}"
        rm -f "$filename" 2>/dev/null
        return 1
    fi

    print_info "Extracting..."
    tar -xzf "$filename" 2>/dev/null

    if [ $? -ne 0 ]; then
        print_error "Failed to extract archive"
        rm -f "$filename" 2>/dev/null
        return 1
    fi

    # FIX: look for binary more reliably
    local binary_name=""
    local candidates=(
        "paqet_${os}_${arch}"
        "paqet-${os}-${arch}"
        "paqet"
    )

    for candidate in "${candidates[@]}"; do
        if [ -f "/tmp/${candidate}" ]; then
            binary_name="/tmp/${candidate}"
            break
        fi
    done

    if [ -z "$binary_name" ]; then
        binary_name=$(find /tmp -maxdepth 2 -name "paqet*" ! -name "*.tar.gz" ! -name "*.zip" -type f 2>/dev/null | head -1)
    fi

    if [ -z "$binary_name" ] || [ ! -f "$binary_name" ]; then
        print_error "Could not find paqet binary after extraction"
        rm -f "$filename" 2>/dev/null
        return 1
    fi

    chmod +x "$binary_name"
    mv "$binary_name" "$PAQET_BIN"
    rm -f "$filename" 2>/dev/null

    mkdir -p "$CONFIG_DIR"
    echo "$version" > "$PAQET_VERSION_FILE"

    print_success "Paqet ${version} installed successfully (${os}-${arch})"
    log "Paqet ${version} installed (${os}-${arch})"
    return 0
}

################################################################################
# Initialize System
################################################################################
initialize() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$PAQET_CONFIG_DIR"

    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        log "Configuration file created"
    fi

    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    if [ ! -f "$PAQET_BIN" ]; then
        print_info "Paqet not installed. Installing latest version..."
        local latest=$(get_latest_version)
        if [ -n "$latest" ]; then
            install_paqet_version "$latest"
        else
            print_warning "Could not install automatically. Use menu option 7."
        fi
    fi

    import_old_tunnels
}

################################################################################
# Import Old Tunnels
################################################################################
import_old_tunnels() {
    [ -d "$PAQET_CONFIG_DIR" ] || return 0
    ls "$PAQET_CONFIG_DIR"/*.yaml &>/dev/null || return 0

    for yaml_file in "$PAQET_CONFIG_DIR"/*.yaml; do
        [ -f "$yaml_file" ] || continue
        local tunnel_name=$(basename "$yaml_file" .yaml)

        if ! tunnel_exists "$tunnel_name"; then
            local role=$(grep "^role:" "$yaml_file" 2>/dev/null | awk '{print $2}' | tr -d '"')

            if [ "$role" = "client" ]; then
                import_client_tunnel "$tunnel_name" "$yaml_file"
            elif [ "$role" = "server" ]; then
                import_server_tunnel "$tunnel_name" "$yaml_file"
            fi
        fi
    done
}

# FIX: rewritten to avoid nested `read` inside `while read` (caused parse bugs)
import_client_tunnel() {
    local name="$1"
    local yaml_file="$2"

    local local_ip=$(grep "addr:" "$yaml_file" | head -1 | awk '{print $2}' | tr -d '"' | cut -d':' -f1)
    local remote_ip=$(grep "addr:" "$yaml_file" | grep -v "0\.0\.0\.0\|127\.0\.0\.1\|:0\"" | tail -1 | awk '{print $2}' | tr -d '"' | cut -d':' -f1)
    local tunnel_port=$(grep -A1 "^server:" "$yaml_file" | grep "addr:" | awk '{print $2}' | tr -d '"' | cut -d':' -f2)
    local tunnel_key=$(grep "key:" "$yaml_file" | awk '{print $2}' | tr -d '"')
    local conn=$(grep "^  conn:" "$yaml_file" | awk '{print $2}')
    local mtu=$(grep "mtu:" "$yaml_file" | awk '{print $2}')
    local mode=$(grep "mode:" "$yaml_file" | awk '{print $2}' | tr -d '"')
    mode=${mode:-fast}

    # Detect protocol
    local has_tcp=$(grep -c 'protocol:.*"tcp"' "$yaml_file" 2>/dev/null || echo 0)
    local has_udp=$(grep -c 'protocol:.*"udp"' "$yaml_file" 2>/dev/null || echo 0)
    local detected_protocol="tcp"
    if [ "$has_tcp" -gt 0 ] && [ "$has_udp" -gt 0 ]; then
        detected_protocol="tcp/udp"
    elif [ "$has_udp" -gt 0 ]; then
        detected_protocol="udp"
    fi

    # FIX: load entire file into array, then parse listen/target pairs safely
    local ports=""
    local -a file_lines=()
    while IFS= read -r line; do
        file_lines+=("$line")
    done < "$yaml_file"

    local total_lines=${#file_lines[@]}
    local in_forward=0

    for (( idx=0; idx<total_lines; idx++ )); do
        local line="${file_lines[$idx]}"

        if [[ "$line" =~ ^forward: ]]; then
            in_forward=1
            continue
        fi

        # If we hit a new top-level key (not indented), stop
        if [[ "$line" =~ ^[a-zA-Z] ]] && [[ ! "$line" =~ ^forward: ]] && [ $in_forward -eq 1 ]; then
            break
        fi

        if [ $in_forward -eq 1 ] && [[ "$line" =~ listen:.*:([0-9]+) ]]; then
            local listen_port="${BASH_REMATCH[1]}"
            local target_port=""

            # Look ahead for the target line (within next 3 lines)
            for (( lookahead=idx+1; lookahead<=idx+3 && lookahead<total_lines; lookahead++ )); do
                local next_line="${file_lines[$lookahead]}"
                if [[ "$next_line" =~ target:.*:([0-9]+) ]]; then
                    target_port="${BASH_REMATCH[1]}"
                    break
                fi
            done

            if [ -z "$target_port" ]; then
                target_port="$listen_port"
            fi

            local entry=""
            if [ "$listen_port" = "$target_port" ]; then
                entry="$listen_port"
            else
                entry="${listen_port}=${target_port}"
            fi

            # Deduplicate
            if [[ ! ",$ports," == *",${entry},"* ]]; then
                ports="${ports:+$ports,}${entry}"
            fi
        fi
    done

    save_tunnel_config "$name" "client" "$local_ip" "$remote_ip" "$tunnel_port" "$tunnel_key" "$ports" "$conn" "$mtu" "$mode" "$detected_protocol"
}

import_server_tunnel() {
    local name="$1"
    local yaml_file="$2"

    local local_ip=$(grep "addr:" "$yaml_file" | head -1 | awk '{print $2}' | tr -d '"' | cut -d':' -f1)
    local tunnel_port=$(grep -A1 "^listen:" "$yaml_file" | grep "addr:" | awk '{print $2}' | tr -d '"' | sed 's/.*://')
    local tunnel_key=$(grep "key:" "$yaml_file" | awk '{print $2}' | tr -d '"')
    local conn=$(grep "^  conn:" "$yaml_file" | awk '{print $2}')
    local mtu=$(grep "mtu:" "$yaml_file" | awk '{print $2}')
    local mode=$(grep "mode:" "$yaml_file" | awk '{print $2}' | tr -d '"')
    mode=${mode:-fast}

    save_tunnel_config "$name" "server" "$local_ip" "" "$tunnel_port" "$tunnel_key" "" "$conn" "$mtu" "$mode" "tcp"
}

################################################################################
# Helper Functions
################################################################################
get_server_ip() {
    local ip=""

    ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
    if [ -n "$ip" ] && [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"; return 0
    fi

    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$ip" ] && [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"; return 0
    fi

    ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)
    if [ -n "$ip" ] && [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$ip"; return 0
    fi

    echo ""
}

get_interface() {
    ip route | grep default | awk '{print $5}' | head -n1
}

# FIX: validate MAC format before returning; fallback gracefully
get_router_mac() {
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}' | head -n1)

    if [ -z "$gateway" ]; then
        echo ""
        return
    fi

    # ping once to populate ARP cache
    ping -c 1 -W 1 "$gateway" &>/dev/null 2>&1 || true

    local mac
    mac=$(ip neigh show "$gateway" 2>/dev/null | awk '{print $5}' | grep -E '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$' | head -n1)

    if [ -z "$mac" ] && command -v arp &>/dev/null; then
        mac=$(arp -n "$gateway" 2>/dev/null | awk '/^[0-9]/{print $3}' | grep -E '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$' | head -n1)
    fi

    echo "${mac:-}"
}

generate_token() {
    cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 64
}

################################################################################
# Validation Functions
################################################################################
validate_tunnel_name() {
    local name="$1"
    local length=${#name}

    if [ $length -lt 3 ] || [ $length -gt 15 ]; then
        return 1
    fi

    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi

    return 0
}

validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    return 1
}

################################################################################
# Tunnel Config Management
################################################################################
tunnel_exists() {
    local name="$1"
    grep -q "^TUNNEL_NAME=${name}$" "$CONFIG_FILE" 2>/dev/null
}

get_tunnel_config() {
    local name="$1"
    awk "/^TUNNEL_NAME=${name}$/,/^$/" "$CONFIG_FILE"
}

get_tunnel_field() {
    local name="$1"
    local field="$2"
    awk "/^TUNNEL_NAME=${name}$/,/^$/" "$CONFIG_FILE" | grep "^${field}=" | cut -d'=' -f2-
}

# FIX: ensure consistent blank-line separation so sed-based delete never merges entries
save_tunnel_config() {
    local name="$1"
    local role="$2"
    local local_ip="$3"
    local remote_ip="$4"
    local tunnel_port="$5"
    local tunnel_key="$6"
    local ports="$7"
    local conn="$8"
    local mtu="$9"
    local mode="${10}"
    local protocol="${11}"

    # Ensure file ends with newline before appending
    if [ -s "$CONFIG_FILE" ]; then
        local last_char
        last_char=$(tail -c1 "$CONFIG_FILE" | wc -c)
        if [ "$last_char" -gt 0 ]; then
            echo "" >> "$CONFIG_FILE"
        fi
    fi

    cat >> "$CONFIG_FILE" << EOF
TUNNEL_NAME=${name}
ROLE=${role}
LOCAL_IP=${local_ip}
REMOTE_IP=${remote_ip}
TUNNEL_PORT=${tunnel_port}
TUNNEL_KEY=${tunnel_key}
PORTS=${ports}
CONN=${conn}
MTU=${mtu}
MODE=${mode}
PROTOCOL=${protocol}

EOF
}

delete_tunnel_config() {
    local name="$1"
    # FIX: use a temp file to avoid sed -i portability issues and accidental merging
    local tmpfile
    tmpfile=$(mktemp)
    awk "
        /^TUNNEL_NAME=${name}$/ { skip=1 }
        skip && /^$/ { skip=0; next }
        !skip { print }
    " "$CONFIG_FILE" > "$tmpfile"
    mv "$tmpfile" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

get_tunnel_by_number() {
    local num="$1"
    grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2 | sed -n "${num}p"
}

get_tunnel_count() {
    local count=$(grep -c "^TUNNEL_NAME=" "$CONFIG_FILE" 2>/dev/null || echo 0)
    echo "${count:-0}"
}

get_tunnel_status() {
    local name="$1"
    if systemctl is-active "${name}.service" &>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

################################################################################
# Update Tunnel Field
################################################################################
update_tunnel_field_value() {
    local name="$1"
    local field="$2"
    local new_value="$3"

    local role=$(get_tunnel_field "$name" "ROLE")
    local local_ip=$(get_tunnel_field "$name" "LOCAL_IP")
    local remote_ip=$(get_tunnel_field "$name" "REMOTE_IP")
    local tunnel_port=$(get_tunnel_field "$name" "TUNNEL_PORT")
    local tunnel_key=$(get_tunnel_field "$name" "TUNNEL_KEY")
    local ports=$(get_tunnel_field "$name" "PORTS")
    local conn=$(get_tunnel_field "$name" "CONN")
    local mtu=$(get_tunnel_field "$name" "MTU")
    local mode=$(get_tunnel_field "$name" "MODE")
    local protocol=$(get_tunnel_field "$name" "PROTOCOL")
    mode=${mode:-fast}
    protocol=${protocol:-tcp}

    case "$field" in
        "ROLE")        role="$new_value" ;;
        "LOCAL_IP")    local_ip="$new_value" ;;
        "REMOTE_IP")   remote_ip="$new_value" ;;
        "TUNNEL_PORT") tunnel_port="$new_value" ;;
        "TUNNEL_KEY")  tunnel_key="$new_value" ;;
        "PORTS")       ports="$new_value" ;;
        "CONN")        conn="$new_value" ;;
        "MTU")         mtu="$new_value" ;;
        "MODE")        mode="$new_value" ;;
        "PROTOCOL")    protocol="$new_value" ;;
    esac

    delete_tunnel_config "$name"
    save_tunnel_config "$name" "$role" "$local_ip" "$remote_ip" "$tunnel_port" "$tunnel_key" "$ports" "$conn" "$mtu" "$mode" "$protocol"
}

################################################################################
# Create YAML Config
################################################################################
create_yaml_config() {
    local name="$1"
    local role="$2"
    local local_ip="$3"
    local remote_ip="$4"
    local tunnel_port="$5"
    local tunnel_key="$6"
    local ports="$7"
    local conn="$8"
    local mtu="$9"
    local mode="${10}"
    local protocol="${11}"

    local interface
    interface=$(get_interface)
    local router_mac
    router_mac=$(get_router_mac)
    local yaml_file="$PAQET_CONFIG_DIR/${name}.yaml"

    mkdir -p "$PAQET_CONFIG_DIR"

    if [ "$role" = "client" ]; then
        local forward_section=""
        IFS=',' read -ra PORT_ARRAY <<< "$ports"

        for port_entry in "${PORT_ARRAY[@]}"; do
            [ -z "$port_entry" ] && continue
            local listen_port=""
            local target_port=""

            if [[ $port_entry == *"="* ]]; then
                listen_port=$(echo "$port_entry" | cut -d'=' -f1)
                target_port=$(echo "$port_entry" | cut -d'=' -f2)
            else
                listen_port="$port_entry"
                target_port="$port_entry"
            fi

            case "$protocol" in
                tcp)
                    forward_section+="  - listen: \"0.0.0.0:${listen_port}\"
    target: \"127.0.0.1:${target_port}\"
    protocol: \"tcp\"
"
                    ;;
                udp)
                    forward_section+="  - listen: \"0.0.0.0:${listen_port}\"
    target: \"127.0.0.1:${target_port}\"
    protocol: \"udp\"
"
                    ;;
                tcp/udp)
                    forward_section+="  - listen: \"0.0.0.0:${listen_port}\"
    target: \"127.0.0.1:${target_port}\"
    protocol: \"tcp\"
  - listen: \"0.0.0.0:${listen_port}\"
    target: \"127.0.0.1:${target_port}\"
    protocol: \"udp\"
"
                    ;;
            esac
        done

        # FIX: only add router_mac line when we actually have a valid MAC
        local network_ipv4_block="    addr: \"${local_ip}:0\""
        if [ -n "$router_mac" ]; then
            network_ipv4_block+="
    router_mac: \"${router_mac}\""
        fi

        cat > "$yaml_file" << EOF
role: "client"

log:
  level: "info"

forward:
${forward_section}
network:
  interface: "${interface}"
  ipv4:
${network_ipv4_block}
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

server:
  addr: "${remote_ip}:${tunnel_port}"

transport:
  protocol: "kcp"
  conn: ${conn}
  kcp:
    mode: "${mode}"
    key: "${tunnel_key}"
    block: "aes-128-gcm"
    mtu: ${mtu}
EOF

    else
        # Server role
        local network_ipv4_block="    addr: \"${local_ip}:${tunnel_port}\""
        if [ -n "$router_mac" ]; then
            network_ipv4_block+="
    router_mac: \"${router_mac}\""
        fi

        cat > "$yaml_file" << EOF
role: "server"

log:
  level: "info"

listen:
  addr: ":${tunnel_port}"

network:
  interface: "${interface}"
  ipv4:
${network_ipv4_block}
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

transport:
  protocol: "kcp"
  conn: ${conn}
  kcp:
    mode: "${mode}"
    key: "${tunnel_key}"
    block: "aes-128-gcm"
    mtu: ${mtu}
EOF
    fi
}

################################################################################
# Create Systemd Service
################################################################################
create_systemd_service() {
    local tunnel_name="$1"
    local service_file="${SERVICE_DIR}/${tunnel_name}.service"

    cat > "$service_file" << EOF
[Unit]
Description=DARKSTRANGE Paqet Tunnel - ${tunnel_name}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${PAQET_BIN} run -c ${PAQET_CONFIG_DIR}/${tunnel_name}.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$service_file"
    systemctl daemon-reload
    systemctl enable "${tunnel_name}.service" 2>/dev/null
    systemctl start "${tunnel_name}.service" 2>/dev/null

    log "Service created: ${tunnel_name}.service"
}

################################################################################
# Rebuild Tunnel
################################################################################
rebuild_tunnel() {
    local name="$1"

    local role=$(get_tunnel_field "$name" "ROLE")
    local local_ip=$(get_tunnel_field "$name" "LOCAL_IP")
    local remote_ip=$(get_tunnel_field "$name" "REMOTE_IP")
    local tunnel_port=$(get_tunnel_field "$name" "TUNNEL_PORT")
    local tunnel_key=$(get_tunnel_field "$name" "TUNNEL_KEY")
    local ports=$(get_tunnel_field "$name" "PORTS")
    local conn=$(get_tunnel_field "$name" "CONN")
    local mtu=$(get_tunnel_field "$name" "MTU")
    local mode=$(get_tunnel_field "$name" "MODE")
    local protocol=$(get_tunnel_field "$name" "PROTOCOL")
    mode=${mode:-fast}
    protocol=${protocol:-tcp}

    systemctl stop "${name}.service" 2>/dev/null

    create_yaml_config "$name" "$role" "$local_ip" "$remote_ip" "$tunnel_port" "$tunnel_key" "$ports" "$conn" "$mtu" "$mode" "$protocol"
    create_systemd_service "$name"

    sleep 2

    if systemctl is-active "${name}.service" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Protocol Selection Helper
################################################################################
select_protocol() {
    echo "" >&2
    echo -e "${CYAN}Select forward protocol (default TCP):${NC}" >&2
    echo -e "  ${GREEN}1)${NC} TCP" >&2
    echo -e "  ${GREEN}2)${NC} UDP" >&2
    echo -e "  ${GREEN}3)${NC} TCP/UDP" >&2
    echo "" >&2

    while true; do
        read -p "$(echo -e ${YELLOW}"Select [1-3] (default: 1): "${NC})" proto_choice
        proto_choice=${proto_choice:-1}
        case $proto_choice in
            1) echo "tcp";     return ;;
            2) echo "udp";     return ;;
            3) echo "tcp/udp"; return ;;
            *) echo -e "${RED}[✗] Invalid selection!${NC}" >&2 ;;
        esac
    done
}

################################################################################
# 1) Configure a New Tunnel
################################################################################
create_tunnel() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      CONFIGURE A NEW PAQET TUNNEL      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    # --- Tunnel Name ---
    while true; do
        read -e -p "$(echo -e ${YELLOW}"Tunnel Name (3-15 chars): "${NC})" tunnel_name
        if validate_tunnel_name "$tunnel_name"; then
            if tunnel_exists "$tunnel_name"; then
                print_error "Tunnel '$tunnel_name' already exists!"
                continue
            fi
            break
        else
            print_error "Invalid name! Use 3-15 alphanumeric characters, - or _"
        fi
    done

    # --- Role ---
    echo ""
    echo -e "${CYAN}Select Server Type:${NC}"
    echo -e "  ${GREEN}1)${NC} Iran Server (Client)"
    echo -e "  ${GREEN}2)${NC} Foreign Server (Server)"
    echo ""

    local role=""
    while true; do
        read -p "$(echo -e ${YELLOW}"Select [1-2]: "${NC})" server_type
        case $server_type in
            1) role="client"; break ;;
            2) role="server"; break ;;
            *) print_error "Invalid selection!" ;;
        esac
    done

    # --- Local IP ---
    local detected_ip=$(get_server_ip)
    local local_ip=""

    while true; do
        if [ -n "$detected_ip" ]; then
            read -e -p "$(echo -e ${YELLOW}"Local IP [${detected_ip}]: "${NC})" local_ip
            local_ip=${local_ip:-$detected_ip}
        else
            read -e -p "$(echo -e ${YELLOW}"Local IP: "${NC})" local_ip
        fi

        if validate_ip "$local_ip"; then
            break
        else
            print_error "Invalid IP address!"
        fi
    done

    # --- Remote IP (client only) ---
    local remote_ip=""
    if [ "$role" = "client" ]; then
        while true; do
            read -e -p "$(echo -e ${YELLOW}"Remote IP: "${NC})" remote_ip
            if validate_ip "$remote_ip"; then
                break
            else
                print_error "Invalid IP address!"
            fi
        done
    fi

    # --- Tunnel Port ---
    local tunnel_port=""
    while true; do
        read -e -p "$(echo -e ${YELLOW}"Tunnel Port: "${NC})" tunnel_port
        if validate_port "$tunnel_port"; then
            break
        else
            print_error "Invalid port! Must be 1-65535"
        fi
    done

    # --- Tunnel Key ---
    local tunnel_key=""
    if [ "$role" = "client" ]; then
        echo ""
        read -e -p "$(echo -e ${YELLOW}"Enter your key token (press Enter to generate): "${NC})" tunnel_key

        if [ -z "$tunnel_key" ]; then
            tunnel_key=$(generate_token)
            echo ""
            print_success "Generated Tunnel Key:"
            echo -e "${GREEN}${tunnel_key}${NC}"
            echo ""
            print_warning "Save this key! You'll need it for the foreign server."
            echo ""
            read -p "Press Enter to continue..."
        fi
    else
        echo ""
        read -e -p "$(echo -e ${YELLOW}"Enter Tunnel Key (from Iran server): "${NC})" tunnel_key

        if [ -z "$tunnel_key" ]; then
            print_error "Key is required for server!"
            read -p "Press Enter to continue..."
            return
        fi

        if [ ${#tunnel_key} -ne 64 ]; then
            print_warning "Key is ${#tunnel_key} chars (expected 64), continuing anyway..."
        fi
    fi

    # --- Protocol & Ports (client only) ---
    local protocol="tcp"
    local ports=""
    if [ "$role" = "client" ]; then
        protocol=$(select_protocol)

        echo ""
        while true; do
            read -e -p "$(echo -e ${YELLOW}"Ports (comma-separated, e.g. 443,8080,2020=2021): "${NC})" ports
            if [ -n "$ports" ]; then
                break
            else
                print_error "Ports are required for client!"
            fi
        done
    fi

    # --- KCP Mode ---
    echo ""
    echo -e "${CYAN}Select KCP Mode:${NC}"
    echo -e "  ${GREEN}1)${NC} fast   - Standard fast mode"
    echo -e "  ${GREEN}2)${NC} fast2  - Enhanced fast mode"
    echo -e "  ${GREEN}3)${NC} fast3  - Maximum speed mode"
    echo ""

    local mode="fast"
    while true; do
        read -p "$(echo -e ${YELLOW}"Select [1-3] (default: 1): "${NC})" mode_choice
        mode_choice=${mode_choice:-1}
        case $mode_choice in
            1) mode="fast";  break ;;
            2) mode="fast2"; break ;;
            3) mode="fast3"; break ;;
            *) print_error "Invalid selection!" ;;
        esac
    done

    # --- Connection count (1-10, default 8) ---
    echo ""
    local conn=""
    while true; do
        read -e -p "$(echo -e ${YELLOW}"Connection count 1-10 [8]: "${NC})" conn
        conn=${conn:-8}

        if [[ "$conn" =~ ^[0-9]+$ ]] && [ "$conn" -ge 1 ] && [ "$conn" -le 10 ]; then
            break
        else
            print_error "Connection count must be between 1 and 10!"
        fi
    done

    # --- MTU (64-1340, default 1320) ---
    local mtu=""
    while true; do
        read -e -p "$(echo -e ${YELLOW}"MTU 64-1340 [1320]: "${NC})" mtu
        mtu=${mtu:-1320}

        if [[ "$mtu" =~ ^[0-9]+$ ]] && [ "$mtu" -ge 64 ] && [ "$mtu" -le 1340 ]; then
            break
        else
            print_error "MTU must be between 64 and 1340!"
        fi
    done

    echo ""
    print_info "Creating tunnel '${tunnel_name}'..."

    save_tunnel_config "$tunnel_name" "$role" "$local_ip" "$remote_ip" "$tunnel_port" "$tunnel_key" "$ports" "$conn" "$mtu" "$mode" "$protocol"
    create_yaml_config "$tunnel_name" "$role" "$local_ip" "$remote_ip" "$tunnel_port" "$tunnel_key" "$ports" "$conn" "$mtu" "$mode" "$protocol"
    create_systemd_service "$tunnel_name"

    sleep 2

    if systemctl is-active "${tunnel_name}.service" &>/dev/null; then
        print_success "Tunnel '${tunnel_name}' created and running!"
    else
        print_error "Service failed to start. Check: journalctl -u ${tunnel_name}.service"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# 2) Tunnel Management Menu
################################################################################
tunnel_management_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║       TUNNEL MANAGEMENT MENU           ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""

        local total=$(get_tunnel_count)

        if [ "$total" -eq 0 ]; then
            print_warning "No tunnels configured"
            echo ""
            read -p "Press Enter to return..."
            return
        fi

        local i=1
        while IFS= read -r tunnel_name; do
            local status=$(get_tunnel_status "$tunnel_name")
            local t_port=$(get_tunnel_field "$tunnel_name" "TUNNEL_PORT")

            if [ "$status" = "active" ]; then
                echo -e "  ${GREEN}${i})${NC} ${WHITE}${tunnel_name}${NC} - ${GREEN}Active${NC} - tunnel port: ${YELLOW}${t_port}${NC}"
            else
                echo -e "  ${GREEN}${i})${NC} ${WHITE}${tunnel_name}${NC} - ${RED}Inactive${NC} - tunnel port: ${YELLOW}${t_port}${NC}"
            fi
            ((i++))
        done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)

        echo ""
        echo -e "  ${RED}0)${NC} Return to main menu"
        echo ""

        read -p "$(echo -e ${YELLOW}"Enter your choice (0 to return): "${NC})" choice

        if [ "$choice" = "0" ]; then
            return
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
            local selected_tunnel=$(get_tunnel_by_number "$choice")
            tunnel_submenu "$selected_tunnel"
        else
            print_error "Invalid selection!"
            sleep 1
        fi
    done
}

################################################################################
# Tunnel Sub-Menu
################################################################################
tunnel_submenu() {
    local tunnel_name="$1"

    while true; do
        if ! tunnel_exists "$tunnel_name"; then
            return
        fi

        show_banner

        local status=$(get_tunnel_status "$tunnel_name")
        local t_port=$(get_tunnel_field "$tunnel_name" "TUNNEL_PORT")
        local role=$(get_tunnel_field "$tunnel_name" "ROLE")
        local protocol=$(get_tunnel_field "$tunnel_name" "PROTOCOL")
        protocol=${protocol:-tcp}

        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        if [ "$status" = "active" ]; then
            echo -e "  ${WHITE}${tunnel_name}${NC} - ${GREEN}Active${NC} - port: ${YELLOW}${t_port}${NC} - role: ${YELLOW}${role}${NC}"
        else
            echo -e "  ${WHITE}${tunnel_name}${NC} - ${RED}Inactive${NC} - port: ${YELLOW}${t_port}${NC} - role: ${YELLOW}${role}${NC}"
        fi
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""

        if [ "$role" = "client" ]; then
            echo -e "  ${RED}1)${NC} Remove this tunnel"
            echo -e "  ${BLUE}2)${NC} Restart this tunnel"
            echo -e "  ${PURPLE}3)${NC} Edit tunnel port"
            echo -e "  ${GREEN}4)${NC} Edit configs port"
            echo -e "  ${GREEN}5)${NC} Edit protocol"
            echo -e "  ${GREEN}6)${NC} Edit KCP mode"
            echo -e "  ${GREEN}7)${NC} Edit key token"
            echo -e "  ${GREEN}8)${NC} Edit MTU & max connection"
            echo -e "  ${CYAN}9)${NC} View service logs"
            echo ""
            echo -e "  ${RED}0)${NC} Return"
            echo ""

            read -p "$(echo -e ${YELLOW}"Enter your choice (0 to return): "${NC})" choice

            case $choice in
                1) remove_single_tunnel "$tunnel_name"
                   ! tunnel_exists "$tunnel_name" && return ;;
                2) restart_single_tunnel "$tunnel_name" ;;
                3) edit_tunnel_port "$tunnel_name" ;;
                4) edit_configs_port "$tunnel_name" ;;
                5) edit_protocol "$tunnel_name" ;;
                6) edit_kcp_mode "$tunnel_name" ;;
                7) edit_key_token "$tunnel_name" ;;
                8) edit_mtu_conn "$tunnel_name" ;;
                9) view_service_logs "$tunnel_name" ;;
                0) return ;;
                *) print_error "Invalid selection!"; sleep 1 ;;
            esac
        else
            echo -e "  ${RED}1)${NC} Remove this tunnel"
            echo -e "  ${BLUE}2)${NC} Restart this tunnel"
            echo -e "  ${PURPLE}3)${NC} Edit tunnel port"
            echo -e "  ${GREEN}4)${NC} Edit KCP mode"
            echo -e "  ${GREEN}5)${NC} Edit key token"
            echo -e "  ${GREEN}6)${NC} Edit MTU & max connection"
            echo -e "  ${CYAN}7)${NC} View service logs"
            echo ""
            echo -e "  ${RED}0)${NC} Return"
            echo ""

            read -p "$(echo -e ${YELLOW}"Enter your choice (0 to return): "${NC})" choice

            case $choice in
                1) remove_single_tunnel "$tunnel_name"
                   ! tunnel_exists "$tunnel_name" && return ;;
                2) restart_single_tunnel "$tunnel_name" ;;
                3) edit_tunnel_port "$tunnel_name" ;;
                4) edit_kcp_mode "$tunnel_name" ;;
                5) edit_key_token "$tunnel_name" ;;
                6) edit_mtu_conn "$tunnel_name" ;;
                7) view_service_logs "$tunnel_name" ;;
                0) return ;;
                *) print_error "Invalid selection!"; sleep 1 ;;
            esac
        fi
    done
}

################################################################################
# Tunnel Sub-Menu Actions
################################################################################
remove_single_tunnel() {
    local tunnel_name="$1"

    echo ""
    print_warning "This will permanently delete tunnel '${tunnel_name}'"
    read -p "$(echo -e ${RED}"Type 'yes' to confirm: "${NC})" confirm

    if [ "$confirm" != "yes" ]; then
        print_warning "Operation cancelled"
        sleep 1
        return
    fi

    print_info "Deleting tunnel..."

    systemctl stop "${tunnel_name}.service" 2>/dev/null
    systemctl disable "${tunnel_name}.service" 2>/dev/null
    rm -f "${SERVICE_DIR}/${tunnel_name}.service" 2>/dev/null
    rm -f "${PAQET_CONFIG_DIR}/${tunnel_name}.yaml" 2>/dev/null
    systemctl daemon-reload

    crontab -l 2>/dev/null | grep -v "darkstrange-paqet:${tunnel_name}" | crontab - 2>/dev/null

    delete_tunnel_config "$tunnel_name"

    print_success "Tunnel '${tunnel_name}' deleted successfully!"
    sleep 1
}

restart_single_tunnel() {
    local tunnel_name="$1"

    print_info "Restarting tunnel '${tunnel_name}'..."

    systemctl daemon-reload
    systemctl restart "${tunnel_name}.service" 2>/dev/null

    sleep 2

    if systemctl is-active "${tunnel_name}.service" &>/dev/null; then
        print_success "Tunnel restarted successfully!"
    else
        print_error "Tunnel service failed to start"
    fi

    sleep 1
}

edit_tunnel_port() {
    local tunnel_name="$1"
    local current_port=$(get_tunnel_field "$tunnel_name" "TUNNEL_PORT")

    echo ""
    echo -e "  Current tunnel port: ${YELLOW}${current_port}${NC}"
    echo ""

    while true; do
        read -e -p "$(echo -e ${YELLOW}"New tunnel port: "${NC})" new_port
        if validate_port "$new_port"; then
            break
        else
            print_error "Invalid port! Must be 1-65535"
        fi
    done

    update_tunnel_field_value "$tunnel_name" "TUNNEL_PORT" "$new_port"

    print_info "Applying changes..."
    if rebuild_tunnel "$tunnel_name"; then
        print_success "Tunnel port updated and service restarted!"
    else
        print_error "Service failed to start with new configuration"
    fi

    sleep 1
}

edit_configs_port() {
    local tunnel_name="$1"
    local role=$(get_tunnel_field "$tunnel_name" "ROLE")

    if [ "$role" != "client" ]; then
        print_warning "Config ports are only applicable for client tunnels"
        sleep 2
        return
    fi

    local current_ports=$(get_tunnel_field "$tunnel_name" "PORTS")

    echo ""
    echo -e "  Current ports: ${YELLOW}${current_ports}${NC}"
    echo ""

    while true; do
        read -e -p "$(echo -e ${YELLOW}"New ports (comma-separated, e.g. 443,8080,2020=2021): "${NC})" new_ports
        if [ -n "$new_ports" ]; then
            break
        else
            print_error "Ports cannot be empty!"
        fi
    done

    update_tunnel_field_value "$tunnel_name" "PORTS" "$new_ports"

    print_info "Applying changes..."
    if rebuild_tunnel "$tunnel_name"; then
        print_success "Config ports updated and service restarted!"
    else
        print_error "Service failed to start with new configuration"
    fi

    sleep 1
}

edit_protocol() {
    local tunnel_name="$1"
    local role=$(get_tunnel_field "$tunnel_name" "ROLE")

    if [ "$role" != "client" ]; then
        print_warning "Protocol editing is only applicable for client tunnels"
        sleep 2
        return
    fi

    local current_protocol=$(get_tunnel_field "$tunnel_name" "PROTOCOL")
    current_protocol=${current_protocol:-tcp}

    echo ""
    echo -e "  Current forward protocol: ${YELLOW}${current_protocol}${NC}"

    local new_protocol=$(select_protocol)

    update_tunnel_field_value "$tunnel_name" "PROTOCOL" "$new_protocol"

    print_info "Applying changes..."
    if rebuild_tunnel "$tunnel_name"; then
        print_success "Forward protocol updated and service restarted!"
    else
        print_error "Service failed to start with new configuration"
    fi

    sleep 1
}

edit_kcp_mode() {
    local tunnel_name="$1"
    local current_mode=$(get_tunnel_field "$tunnel_name" "MODE")
    current_mode=${current_mode:-fast}

    echo ""
    echo -e "  Current KCP mode: ${YELLOW}${current_mode}${NC}"
    echo ""
    echo -e "${CYAN}Select new KCP Mode:${NC}"
    echo -e "  ${GREEN}1)${NC} fast   - Standard fast mode"
    echo -e "  ${GREEN}2)${NC} fast2  - Enhanced fast mode"
    echo -e "  ${GREEN}3)${NC} fast3  - Maximum speed mode"
    echo ""

    local new_mode=""
    while true; do
        read -p "$(echo -e ${YELLOW}"Select [1-3]: "${NC})" mode_choice
        case $mode_choice in
            1) new_mode="fast";  break ;;
            2) new_mode="fast2"; break ;;
            3) new_mode="fast3"; break ;;
            *) print_error "Invalid selection!" ;;
        esac
    done

    update_tunnel_field_value "$tunnel_name" "MODE" "$new_mode"

    print_info "Applying changes..."
    if rebuild_tunnel "$tunnel_name"; then
        print_success "KCP mode updated and service restarted!"
    else
        print_error "Service failed to start with new configuration"
    fi

    sleep 1
}

edit_key_token() {
    local tunnel_name="$1"
    local current_key=$(get_tunnel_field "$tunnel_name" "TUNNEL_KEY")

    echo ""
    echo -e "  Current key: ${YELLOW}${current_key}${NC}"
    echo ""

    read -e -p "$(echo -e ${YELLOW}"Enter your key token (press Enter to generate): "${NC})" new_key

    if [ -z "$new_key" ]; then
        new_key=$(generate_token)
        echo ""
        print_success "Generated new key:"
        echo -e "${GREEN}${new_key}${NC}"
        echo ""
        print_warning "Save this key! You'll need it for the other server."
        echo ""
        read -p "Press Enter to apply and continue..."
    fi

    update_tunnel_field_value "$tunnel_name" "TUNNEL_KEY" "$new_key"

    print_info "Applying changes..."
    if rebuild_tunnel "$tunnel_name"; then
        print_success "Key token updated and service restarted!"
    else
        print_error "Service failed to start with new configuration"
    fi

    sleep 1
}

edit_mtu_conn() {
    local tunnel_name="$1"
    local current_mtu=$(get_tunnel_field "$tunnel_name" "MTU")
    local current_conn=$(get_tunnel_field "$tunnel_name" "CONN")
    current_mtu=${current_mtu:-1320}
    current_conn=${current_conn:-8}

    echo ""
    echo -e "  Current MTU:         ${YELLOW}${current_mtu}${NC}"
    echo -e "  Current Connections: ${YELLOW}${current_conn}${NC}"
    echo ""

    local new_mtu=""
    while true; do
        read -e -p "$(echo -e ${YELLOW}"New MTU 64-1340 [${current_mtu}]: "${NC})" new_mtu
        new_mtu=${new_mtu:-$current_mtu}

        if [[ "$new_mtu" =~ ^[0-9]+$ ]] && [ "$new_mtu" -ge 64 ] && [ "$new_mtu" -le 1340 ]; then
            break
        else
            print_error "MTU must be between 64 and 1340!"
        fi
    done

    local new_conn=""
    while true; do
        read -e -p "$(echo -e ${YELLOW}"New connection count 1-10 [${current_conn}]: "${NC})" new_conn
        new_conn=${new_conn:-$current_conn}

        if [[ "$new_conn" =~ ^[0-9]+$ ]] && [ "$new_conn" -ge 1 ] && [ "$new_conn" -le 10 ]; then
            break
        else
            print_error "Connection count must be between 1 and 10!"
        fi
    done

    local role=$(get_tunnel_field "$tunnel_name" "ROLE")
    local local_ip=$(get_tunnel_field "$tunnel_name" "LOCAL_IP")
    local remote_ip=$(get_tunnel_field "$tunnel_name" "REMOTE_IP")
    local tunnel_port=$(get_tunnel_field "$tunnel_name" "TUNNEL_PORT")
    local tunnel_key=$(get_tunnel_field "$tunnel_name" "TUNNEL_KEY")
    local ports=$(get_tunnel_field "$tunnel_name" "PORTS")
    local mode=$(get_tunnel_field "$tunnel_name" "MODE")
    local protocol=$(get_tunnel_field "$tunnel_name" "PROTOCOL")
    mode=${mode:-fast}
    protocol=${protocol:-tcp}

    delete_tunnel_config "$tunnel_name"
    save_tunnel_config "$tunnel_name" "$role" "$local_ip" "$remote_ip" "$tunnel_port" "$tunnel_key" "$ports" "$new_conn" "$new_mtu" "$mode" "$protocol"

    print_info "Applying changes..."
    if rebuild_tunnel "$tunnel_name"; then
        print_success "MTU & connection count updated and service restarted!"
    else
        print_error "Service failed to start with new configuration"
    fi

    sleep 1
}

view_service_logs() {
    local tunnel_name="$1"

    show_banner
    echo -e "${CYAN}Service logs for: ${WHITE}${tunnel_name}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    journalctl -u "${tunnel_name}.service" --no-pager -n 50 2>/dev/null || echo "No logs available"

    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# 3) Check Tunnels Status
################################################################################
check_tunnels_status() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        CHECK TUNNELS STATUS            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    local total=$(get_tunnel_count)

    if [ "$total" -eq 0 ]; then
        print_warning "No tunnels configured"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    local i=1
    while IFS= read -r tunnel_name; do
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}[$i] Tunnel: ${GREEN}${tunnel_name}${NC}"

        local role=$(get_tunnel_field "$tunnel_name" "ROLE")
        local local_ip=$(get_tunnel_field "$tunnel_name" "LOCAL_IP")
        local remote_ip=$(get_tunnel_field "$tunnel_name" "REMOTE_IP")
        local tunnel_port=$(get_tunnel_field "$tunnel_name" "TUNNEL_PORT")
        local ports=$(get_tunnel_field "$tunnel_name" "PORTS")
        local conn=$(get_tunnel_field "$tunnel_name" "CONN")
        local mtu=$(get_tunnel_field "$tunnel_name" "MTU")
        local mode=$(get_tunnel_field "$tunnel_name" "MODE")
        local protocol=$(get_tunnel_field "$tunnel_name" "PROTOCOL")
        mode=${mode:-fast}
        protocol=${protocol:-tcp}

        echo -e "    Role:         ${YELLOW}${role}${NC}"
        echo -e "    Local IP:     ${YELLOW}${local_ip}${NC}"
        [ -n "$remote_ip" ] && echo -e "    Remote IP:    ${YELLOW}${remote_ip}${NC}"
        echo -e "    Tunnel Port:  ${YELLOW}${tunnel_port}${NC}"
        if [ -n "$ports" ]; then
            echo -e "    Ports:        ${YELLOW}${ports}${NC}"
            echo -e "    Protocol:     ${YELLOW}${protocol}${NC}"
        fi
        echo -e "    KCP Mode:     ${YELLOW}${mode}${NC}"
        echo -e "    Connections:  ${YELLOW}${conn}${NC}"
        echo -e "    MTU:          ${YELLOW}${mtu}${NC}"

        if systemctl is-active "${tunnel_name}.service" &>/dev/null; then
            echo -e "    Service:      ${GREEN}ACTIVE ✓${NC}"
        else
            echo -e "    Service:      ${RED}INACTIVE ✗${NC}"
        fi

        echo ""
        ((i++))
    done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# 4) Restart All Tunnels
################################################################################
restart_all_tunnels() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        RESTART ALL TUNNELS             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    local total=$(get_tunnel_count)

    if [ "$total" -eq 0 ]; then
        print_warning "No tunnels configured"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    print_info "Restarting all tunnels..."
    echo ""

    systemctl daemon-reload

    while IFS= read -r tunnel_name; do
        systemctl restart "${tunnel_name}.service" 2>/dev/null
        sleep 1

        if systemctl is-active "${tunnel_name}.service" &>/dev/null; then
            print_success "${tunnel_name} - Restarted"
        else
            print_error "${tunnel_name} - Failed"
        fi
    done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)

    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# 5) Delete All Tunnels
################################################################################
delete_all_tunnels() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        DELETE ALL TUNNELS              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    local total=$(get_tunnel_count)

    if [ "$total" -eq 0 ]; then
        print_warning "No tunnels configured"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    print_warning "This will permanently delete ALL ${total} tunnel(s)!"
    echo ""
    read -p "$(echo -e ${RED}"Type 'yes' to confirm: "${NC})" confirm

    if [ "$confirm" != "yes" ]; then
        print_warning "Operation cancelled"
        read -p "Press Enter to continue..."
        return
    fi

    print_info "Deleting all tunnels..."
    echo ""

    while IFS= read -r tunnel_name; do
        systemctl stop "${tunnel_name}.service" 2>/dev/null
        systemctl disable "${tunnel_name}.service" 2>/dev/null
        rm -f "${SERVICE_DIR}/${tunnel_name}.service" 2>/dev/null
        rm -f "${PAQET_CONFIG_DIR}/${tunnel_name}.yaml" 2>/dev/null
        print_success "Deleted: ${tunnel_name}"
    done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)

    systemctl daemon-reload
    > "$CONFIG_FILE"
    crontab -l 2>/dev/null | grep -v "darkstrange-paqet" | crontab - 2>/dev/null

    echo ""
    print_success "All tunnels deleted!"
    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# 6) Cron Job Menu
################################################################################
cronjob_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║           CRON JOB MENU               ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} Setup cron for all tunnels"
        echo -e "  ${GREEN}2)${NC} Setup cron for specific tunnel"
        echo -e "  ${GREEN}3)${NC} View active cron jobs"
        echo -e "  ${GREEN}4)${NC} Change cron interval"
        echo -e "  ${GREEN}5)${NC} Remove cron for specific tunnel"
        echo -e "  ${GREEN}6)${NC} Remove all cron jobs"
        echo ""
        echo -e "  ${RED}0)${NC} Return to main menu"
        echo ""

        read -p "$(echo -e ${YELLOW}"Enter your choice (0 to return): "${NC})" choice

        case $choice in
            1) setup_cron_all ;;
            2) setup_cron_specific ;;
            3) view_cron_jobs ;;
            4) change_cron_interval ;;
            5) remove_cron_specific ;;
            6) remove_all_crons ;;
            0) return ;;
            *) print_error "Invalid selection!"; sleep 1 ;;
        esac
    done
}

select_cron_interval() {
    _SELECTED_CRON=""
    echo ""
    echo -e "${CYAN}Select restart interval:${NC}"
    echo -e "  ${GREEN}1)${NC} Every 30 minutes"
    echo -e "  ${GREEN}2)${NC} Every 1 hour"
    echo -e "  ${GREEN}3)${NC} Every 3 hours"
    echo -e "  ${GREEN}4)${NC} Every 6 hours"
    echo -e "  ${GREEN}5)${NC} Every 12 hours"
    echo -e "  ${GREEN}6)${NC} Custom (hours)"
    echo ""

    while true; do
        read -p "$(echo -e ${YELLOW}"Select [1-6]: "${NC})" interval_choice
        case $interval_choice in
            1) _SELECTED_CRON="*/30 * * * *"; return 0 ;;
            2) _SELECTED_CRON="0 * * * *";    return 0 ;;
            3) _SELECTED_CRON="0 */3 * * *";  return 0 ;;
            4) _SELECTED_CRON="0 */6 * * *";  return 0 ;;
            5) _SELECTED_CRON="0 */12 * * *"; return 0 ;;
            6)
                read -p "$(echo -e ${YELLOW}"Hours between restarts: "${NC})" hours
                if [[ "$hours" =~ ^[0-9]+$ ]] && [ "$hours" -ge 1 ]; then
                    _SELECTED_CRON="0 */${hours} * * *"
                    return 0
                else
                    print_error "Invalid number!"
                fi
                ;;
            *) print_error "Invalid selection!" ;;
        esac
    done
}

setup_cron_all() {
    local total=$(get_tunnel_count)

    if [ "$total" -eq 0 ]; then
        print_warning "No tunnels configured"
        sleep 2
        return
    fi

    select_cron_interval
    local cron_schedule="$_SELECTED_CRON"

    [ -z "$cron_schedule" ] && return

    crontab -l 2>/dev/null | grep -v "darkstrange-paqet:all" | crontab - 2>/dev/null

    local restart_cmd="systemctl daemon-reload"
    while IFS= read -r tunnel_name; do
        restart_cmd="${restart_cmd} && systemctl restart ${tunnel_name}.service"
    done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)

    (crontab -l 2>/dev/null; echo "${cron_schedule} ${restart_cmd} >/dev/null 2>&1 # darkstrange-paqet:all") | crontab -

    echo ""
    print_success "Cron job set for all tunnels"
    sleep 2
}

setup_cron_specific() {
    local total=$(get_tunnel_count)

    if [ "$total" -eq 0 ]; then
        print_warning "No tunnels configured"
        sleep 2
        return
    fi

    echo ""
    local i=1
    while IFS= read -r tunnel_name; do
        echo -e "  ${GREEN}${i})${NC} ${tunnel_name}"
        ((i++))
    done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)
    echo -e "  ${RED}0)${NC} Cancel"
    echo ""

    while true; do
        read -p "$(echo -e ${YELLOW}"Select tunnel [0-${total}]: "${NC})" choice

        [ "$choice" = "0" ] && return

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
            break
        else
            print_error "Invalid selection!"
        fi
    done

    local selected=$(get_tunnel_by_number "$choice")

    select_cron_interval
    local cron_schedule="$_SELECTED_CRON"

    [ -z "$cron_schedule" ] && return

    crontab -l 2>/dev/null | grep -v "darkstrange-paqet:${selected}" | crontab - 2>/dev/null
    (crontab -l 2>/dev/null; echo "${cron_schedule} systemctl restart ${selected}.service >/dev/null 2>&1 # darkstrange-paqet:${selected}") | crontab -

    echo ""
    print_success "Cron job set for '${selected}'"
    sleep 2
}

view_cron_jobs() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        ACTIVE CRON JOBS                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    local cron_entries=$(crontab -l 2>/dev/null | grep "darkstrange-paqet")

    if [ -z "$cron_entries" ]; then
        print_warning "No active cron jobs"
    else
        echo -e "${WHITE}Current cron jobs:${NC}"
        echo ""

        local i=1
        while IFS= read -r line; do
            local schedule=$(echo "$line" | awk '{print $1, $2, $3, $4, $5}')
            local identifier=$(echo "$line" | sed -n 's/.*darkstrange-paqet:\([^ ]*\).*/\1/p')

            local readable=""
            case "$schedule" in
                "*/30 * * * *") readable="Every 30 minutes" ;;
                "0 * * * *")    readable="Every 1 hour" ;;
                "0 */3 * * *")  readable="Every 3 hours" ;;
                "0 */6 * * *")  readable="Every 6 hours" ;;
                "0 */12 * * *") readable="Every 12 hours" ;;
                *)              readable="Custom: $schedule" ;;
            esac

            if [ "$identifier" = "all" ]; then
                echo -e "  ${GREEN}${i})${NC} ${YELLOW}All tunnels${NC} - ${readable}"
            else
                echo -e "  ${GREEN}${i})${NC} ${YELLOW}${identifier}${NC} - ${readable}"
            fi
            ((i++))
        done <<< "$cron_entries"
    fi

    echo ""
    read -p "Press Enter to continue..."
}

change_cron_interval() {
    local cron_entries=$(crontab -l 2>/dev/null | grep "darkstrange-paqet")

    if [ -z "$cron_entries" ]; then
        print_warning "No active cron jobs to change"
        sleep 2
        return
    fi

    echo ""
    echo -e "${WHITE}Active cron jobs:${NC}"
    echo ""

    local i=1
    local identifiers=()
    while IFS= read -r line; do
        local schedule=$(echo "$line" | awk '{print $1, $2, $3, $4, $5}')
        local identifier=$(echo "$line" | sed -n 's/.*darkstrange-paqet:\([^ ]*\).*/\1/p')
        identifiers+=("$identifier")

        local readable=""
        case "$schedule" in
            "*/30 * * * *") readable="Every 30 minutes" ;;
            "0 * * * *")    readable="Every 1 hour" ;;
            "0 */3 * * *")  readable="Every 3 hours" ;;
            "0 */6 * * *")  readable="Every 6 hours" ;;
            "0 */12 * * *") readable="Every 12 hours" ;;
            *)              readable="Custom: $schedule" ;;
        esac

        if [ "$identifier" = "all" ]; then
            echo -e "  ${GREEN}${i})${NC} ${YELLOW}All tunnels${NC} - ${readable}"
        else
            echo -e "  ${GREEN}${i})${NC} ${YELLOW}${identifier}${NC} - ${readable}"
        fi
        ((i++))
    done <<< "$cron_entries"

    echo -e "  ${RED}0)${NC} Cancel"
    echo ""

    local total_crons=${#identifiers[@]}

    while true; do
        read -p "$(echo -e ${YELLOW}"Select cron to change [0-${total_crons}]: "${NC})" choice

        [ "$choice" = "0" ] && return

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total_crons" ]; then
            break
        else
            print_error "Invalid selection!"
        fi
    done

    local selected_id="${identifiers[$((choice-1))]}"
    local old_line=$(crontab -l 2>/dev/null | grep "darkstrange-paqet:${selected_id}")
    local cmd_part=$(echo "$old_line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

    select_cron_interval
    local new_schedule="$_SELECTED_CRON"

    [ -z "$new_schedule" ] && return

    crontab -l 2>/dev/null | grep -v "darkstrange-paqet:${selected_id}" | crontab - 2>/dev/null
    (crontab -l 2>/dev/null; echo "${new_schedule} ${cmd_part}") | crontab -

    echo ""
    print_success "Cron interval updated for '${selected_id}'"
    sleep 2
}

remove_cron_specific() {
    local cron_entries=$(crontab -l 2>/dev/null | grep "darkstrange-paqet")

    if [ -z "$cron_entries" ]; then
        print_warning "No active cron jobs"
        sleep 2
        return
    fi

    echo ""
    echo -e "${WHITE}Active cron jobs:${NC}"
    echo ""

    local i=1
    local identifiers=()
    while IFS= read -r line; do
        local identifier=$(echo "$line" | sed -n 's/.*darkstrange-paqet:\([^ ]*\).*/\1/p')
        identifiers+=("$identifier")

        if [ "$identifier" = "all" ]; then
            echo -e "  ${GREEN}${i})${NC} All tunnels"
        else
            echo -e "  ${GREEN}${i})${NC} ${identifier}"
        fi
        ((i++))
    done <<< "$cron_entries"

    echo -e "  ${RED}0)${NC} Cancel"
    echo ""

    local total_crons=${#identifiers[@]}

    while true; do
        read -p "$(echo -e ${YELLOW}"Select cron to remove [0-${total_crons}]: "${NC})" choice

        [ "$choice" = "0" ] && return

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total_crons" ]; then
            break
        else
            print_error "Invalid selection!"
        fi
    done

    local selected_id="${identifiers[$((choice-1))]}"
    crontab -l 2>/dev/null | grep -v "darkstrange-paqet:${selected_id}" | crontab - 2>/dev/null

    print_success "Cron job for '${selected_id}' removed"
    sleep 2
}

remove_all_crons() {
    crontab -l 2>/dev/null | grep -v "darkstrange-paqet" | crontab - 2>/dev/null
    print_success "All cron jobs removed"
    sleep 2
}

################################################################################
# 7) Update & Install Paqet
################################################################################
update_install_paqet() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       UPDATE & INSTALL PAQET           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    local current=$(get_installed_version)
    echo -e "  ${WHITE}Current version: ${GREEN}${current}${NC}"
    echo ""

    print_info "Fetching latest version from GitHub..."
    local latest=$(get_latest_version)

    if [ -z "$latest" ]; then
        print_error "Could not fetch latest version from GitHub"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "  ${WHITE}Latest version:  ${GREEN}${latest}${NC}"
    echo ""

    if [ "$current" = "$latest" ]; then
        print_success "You already have the latest version!"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    print_info "Installing ${latest}..."
    echo ""

    if install_paqet_version "$latest"; then
        echo ""
        print_info "Restarting all tunnels with new version..."

        local total=$(get_tunnel_count)
        if [ "$total" -gt 0 ]; then
            systemctl daemon-reload
            while IFS= read -r tunnel_name; do
                systemctl restart "${tunnel_name}.service" 2>/dev/null
                sleep 1
                if systemctl is-active "${tunnel_name}.service" &>/dev/null; then
                    print_success "${tunnel_name} - Restarted"
                else
                    print_error "${tunnel_name} - Failed"
                fi
            done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)
        fi
    fi

    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# 8) Change Paqet Core Version
################################################################################
change_paqet_version() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     CHANGE PAQET CORE VERSION          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    local current=$(get_installed_version)
    echo -e "  ${WHITE}Current version: ${GREEN}${current}${NC}"
    echo ""

    print_info "Fetching available versions..."
    local versions=$(get_available_versions)

    if [ -z "$versions" ]; then
        print_error "Could not fetch versions from GitHub"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi

    echo ""
    echo -e "${CYAN}Available versions:${NC}"
    echo ""

    local i=1
    local version_array=()
    while IFS= read -r ver; do
        if [ -n "$ver" ]; then
            version_array+=("$ver")
            if [ "$ver" = "$current" ]; then
                echo -e "  ${GREEN}${i})${NC} ${ver} ${GREEN}(current)${NC}"
            else
                echo -e "  ${GREEN}${i})${NC} ${ver}"
            fi
            ((i++))
        fi
    done <<< "$versions"

    echo ""
    echo -e "  ${RED}0)${NC} Cancel"
    echo ""

    local total_versions=${#version_array[@]}

    while true; do
        read -p "$(echo -e ${YELLOW}"Select version [0-${total_versions}]: "${NC})" choice

        [ "$choice" = "0" ] && return

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$total_versions" ]; then
            break
        else
            print_error "Invalid selection!"
        fi
    done

    local selected_version="${version_array[$((choice-1))]}"

    if [ "$selected_version" = "$current" ]; then
        print_warning "This version is already installed"
        sleep 2
        return
    fi

    echo ""
    print_info "Installing ${selected_version}..."
    echo ""

    if install_paqet_version "$selected_version"; then
        echo ""
        print_info "Restarting all tunnels..."

        local total=$(get_tunnel_count)
        if [ "$total" -gt 0 ]; then
            systemctl daemon-reload
            while IFS= read -r tunnel_name; do
                systemctl restart "${tunnel_name}.service" 2>/dev/null
                sleep 1
                if systemctl is-active "${tunnel_name}.service" &>/dev/null; then
                    print_success "${tunnel_name} - Restarted"
                else
                    print_error "${tunnel_name} - Failed"
                fi
            done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)
        fi
    fi

    echo ""
    read -p "Press Enter to continue..."
}

################################################################################
# 9) Uninstall Paqet
################################################################################
uninstall_paqet() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         UNINSTALL PAQET                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""

    local total=$(get_tunnel_count)

    echo -e "${WHITE}This will:${NC}"
    echo -e "  ${RED}•${NC} Stop and remove all ${total} tunnel(s)"
    echo -e "  ${RED}•${NC} Remove paqet binary"
    echo -e "  ${RED}•${NC} Remove all configuration files"
    echo -e "  ${RED}•${NC} Remove all cron jobs"
    echo -e "  ${RED}•${NC} Remove systemd services"
    echo ""
    print_warning "THIS ACTION CANNOT BE UNDONE!"
    echo ""
    read -p "$(echo -e ${RED}"Type 'uninstall' to confirm: "${NC})" confirm

    if [ "$confirm" != "uninstall" ]; then
        print_warning "Operation cancelled"
        read -p "Press Enter to continue..."
        return
    fi

    echo ""
    print_info "Uninstalling paqet..."
    echo ""

    if [ "$total" -gt 0 ]; then
        while IFS= read -r tunnel_name; do
            systemctl stop "${tunnel_name}.service" 2>/dev/null
            systemctl disable "${tunnel_name}.service" 2>/dev/null
            rm -f "${SERVICE_DIR}/${tunnel_name}.service" 2>/dev/null
            print_success "Removed service: ${tunnel_name}"
        done < <(grep "^TUNNEL_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)
    fi

    systemctl daemon-reload

    crontab -l 2>/dev/null | grep -v "darkstrange-paqet" | crontab - 2>/dev/null
    print_success "Removed cron jobs"

    rm -f "$PAQET_BIN" 2>/dev/null
    print_success "Removed paqet binary"

    rm -rf "$PAQET_CONFIG_DIR" 2>/dev/null
    print_success "Removed paqet configs"

    rm -rf "$CONFIG_DIR" 2>/dev/null
    print_success "Removed darkstrange configs"

    rm -f "$LOG_FILE" 2>/dev/null
    print_success "Removed log file"

    echo ""
    print_success "Paqet has been completely uninstalled!"
    echo ""

    read -p "Press Enter to exit..."
    exit 0
}

################################################################################
# Main Menu
################################################################################
main_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║            MAIN MENU                   ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} Configure a new tunnel"
        echo -e "  ${GREEN}2)${NC} Tunnel management menu"
        echo -e "  ${GREEN}3)${NC} Check tunnels status"
        echo -e "  ${GREEN}4)${NC} Restart all tunnels"
        echo -e "  ${GREEN}5)${NC} Delete all tunnels"
        echo -e "  ${CYAN}6)${NC} Cron job menu"
        echo -e "  ${YELLOW}7)${NC} Update & install paqet"
        echo -e "  ${YELLOW}8)${NC} Change paqet core version"
        echo -e "  ${RED}9)${NC} Uninstall paqet"
        echo -e "  ${RED}0)${NC} Exit"
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""

        read -p "$(echo -e ${YELLOW}"Select option: "${NC})" choice

        case $choice in
            1) create_tunnel ;;
            2) tunnel_management_menu ;;
            3) check_tunnels_status ;;
            4) restart_all_tunnels ;;
            5) delete_all_tunnels ;;
            6) cronjob_menu ;;
            7) update_install_paqet ;;
            8) change_paqet_version ;;
            9) uninstall_paqet ;;
            0)
                clear
                echo -e "${GREEN}Thank you for using DARKSTRANGE Paqet Manager!${NC}"
                exit 0
                ;;
            *)
                print_error "Invalid option!"
                sleep 1
                ;;
        esac
    done
}

################################################################################
# Entry Point
################################################################################
check_root
initialize
main_menu