#!/bin/bash
# ============================================================
# Advanced Recon Script v1
#   ./recon.sh -h
#   ./recon.sh example.com
#   ./z-recon.sh example.com -t 5
#   ./z-recon.sh example.com -t 5 --ports --delay 2
#   ./z-recon.sh -f scope.txt -t 5
#   ./z-recon.sh --scope domains.txt -mc 200
# ============================================================

set -uo pipefail

# Force color output when stdout is a TTY; still OK in pipes (codes ignored by most logs)
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'
# ================ Start LOGO =====================
clear
echo """
		${BLUE}███████╗     ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗${NC}
		${BLUE}╚══███╔╝     ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║${NC}
		${BLUE}  ███╔╝█████╗██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║${NC}
		${BLUE} ███╔╝ ╚════╝██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║${NC}
		${BLUE}███████╗     ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║${NC}
		${BLUE}╚══════╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝${NC}
                                        
		${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
			   ${RED}B e s t   R e c o n   T o o l ${NC}
			   ${BOLD}Created By : ${RED}ZODiAK${NC} 
			   ${BOLD}${YELLOW}https://ebrahim-hammad.vercel.app${NC}
				   
"""

# ================ End   LOGO =====================
# Defaults (anti-ban)
THREADS=20
DIR_HOST_LIMIT=5
MATCH_CODES="200,201,202,203,204,301,302,307,401,403,404,500"
SCREENSHOT_LIMIT=10
PARAM_HOST_LIMIT=5
WAF_HOST_LIMIT=5
DELAY=1
WEBHOOK_URL="${WEBHOOK_URL:-}"
PORTS_TOP=100
PORTS_FULL=false
RUN_PORTS=false

SKIP_ACTIVE=false
SKIP_PERMUTATION=false
SKIP_DIRS=false
SKIP_JS=false
SKIP_SCREENSHOTS=false
SKIP_PARAMS=false
SKIP_TAKEOVER=false
SKIP_NUCLEI=false
SKIP_WAF=false

log() {
    printf '%s\n' "[$(date '+%H:%M:%S')] $*"
    if [ -n "${LOG_FILE:-}" ]; then
        printf '%s\n' "[$(date '+%H:%M:%S')] $*" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
    fi
}
ok()   { log "${GREEN}[+]${NC} $*"; }
info() { log "${BLUE}[*]${NC} $*"; }
warn() { log "${YELLOW}[!]${NC} $*"; }
err()  { log "${RED}[-]${NC} $*"; }
step() { log "${CYAN}${BOLD}=== $* ===${NC}"; }

notify() {
    [ -z "${WEBHOOK_URL:-}" ] && return 0
    curl -s -H "Content-Type: application/json" \
         -d "{\"content\": \"[${DOMAIN_CLEAN:-recon}] $1\"}" \
         "$WEBHOOK_URL" >/dev/null 2>&1 || true
}

usage() {
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo -e "${CYAN}${BOLD}  Advanced Recon Script v2.2${NC}"
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Usage:${NC}"
    echo -e "  $0 <domain> [options]"
    echo -e "  $0 -f <file> [options]"
    echo -e "  $0 --scope <file> [options]"
    echo -e "  $0 -h | --help"
    echo ""
    echo -e "${GREEN}${BOLD}Modules:${NC}"
    echo -e "  ${CYAN}[0]${NC}   Auto tool check/install (httpx / httpx-toolkit)"
    echo -e "  ${CYAN}[1]${NC}   Passive subdomains (subfinder + crt.sh)"
    echo -e "  ${CYAN}[2]${NC}   Active subdomains (dnsx + SecLists)"
    echo -e "  ${CYAN}[3]${NC}   Subdomain permutation (alterx)"
    echo -e "  ${CYAN}[4]${NC}   DNS resolve"
    echo -e "  ${CYAN}[5]${NC}   HTTP probing"
    echo -e "  ${CYAN}[6]${NC}   WAF/CDN detection + bypass rating"
    echo -e "  ${CYAN}[7]${NC}   Port scan naabu (${YELLOW}OFF${NC} → use --ports)"
    echo -e "  ${CYAN}[8]${NC}   Directory enumeration (ffuf)"
    echo -e "  ${CYAN}[9]${NC}   403 bypass"
    echo -e "  ${CYAN}[10]${NC}  Screenshots (gowitness)"
    echo -e "  ${CYAN}[11]${NC}  JS + endpoints + secrets"
    echo -e "  ${CYAN}[12]${NC}  Parameter discovery"
    echo -e "  ${CYAN}[13]${NC}  Information disclosure"
    echo -e "  ${CYAN}[14]${NC}  Subdomain takeover"
    echo -e "  ${CYAN}[15]${NC}  Historical URLs"
    echo -e "  ${CYAN}[16]${NC}  Google & GitHub dorks"
    echo -e "  ${CYAN}[17]${NC}  Extra Nuclei"
    echo -e "        ${DIM}+ recon.log + optional webhook${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Global threads (applies to ALL tools):${NC}"
    echo -e "  ${YELLOW}-t <n>${NC}  |  ${YELLOW}--threads <n>${NC}     default ${YELLOW}20${NC}"
    echo -e "  Example: ${DIM}$0 example.com -t 5${NC}"
    echo -e "  Sets httpx, ffuf, dnsx, naabu all to the same value."
    echo ""
    echo -e "${GREEN}${BOLD}Skip:${NC}"
    echo -e "  --skip-active  --skip-permutation  --skip-dirs  --skip-js"
    echo -e "  --skip-screenshots  --skip-params  --skip-takeover"
    echo -e "  --skip-nuclei  --skip-waf"
    echo ""
    echo -e "${GREEN}${BOLD}Scope file (domains / subdomains list):${NC}"
    echo -e "  ${YELLOW}-f <file>${NC}  |  ${YELLOW}--scope <file>${NC}  |  ${YELLOW}--file <file>${NC}"
    echo -e "  One domain or subdomain per line. # comments and empty lines ignored."
    echo -e "  You can also pass a file path as the first argument."
    echo ""
    echo -e "${GREEN}${BOLD}Optional:${NC}"
    echo -e "  --ports                 Enable port scan"
    echo -e "  --ports-top <n>         Top N ports (default 100)"
    echo -e "  --ports-full            Broader naabu scan"
    echo -e "  --delay <sec>           Delay between heavy requests (default 1)"
    echo -e "  --dir-hosts <n>         Max hosts for dir fuzz (default 5)"
    echo -e "  ${YELLOW}-mc <codes>${NC}  |  ${YELLOW}--match-codes <codes>${NC}"
    echo -e "                          ffuf status codes (default includes 200,301,403,...)"
    echo -e "                          Example: ${DIM}-mc 200${NC}  or  ${DIM}-mc 200,301,403${NC}"
    echo -e "  --screenshot-limit <n>  Max screenshots (default 10)"
    echo -e "  --param-hosts <n>       Max hosts for params (default 5)"
    echo -e "  --waf-hosts <n>         Max hosts for wafw00f (default 5)"
    echo -e "  --webhook <url>         Discord/Slack webhook"
    echo ""
    echo -e "${GREEN}${BOLD}Examples:${NC}"
    echo -e "  ${DIM}$0 example.com${NC}"
    echo -e "  ${DIM}$0 example.com -t 5${NC}"
    echo -e "  ${DIM}$0 example.com -t 8 --ports --delay 2${NC}"
    echo -e "  ${DIM}$0 example.com -t 5 --skip-dirs --skip-screenshots${NC}"
    echo -e "  ${DIM}$0 -f scope.txt -t 5${NC}"
    echo -e "  ${DIM}$0 --scope subs.txt -mc 200 --ports${NC}"
    echo -e "  ${DIM}$0 domains.txt -t 8 -mc 200,403${NC}"
    echo ""
    exit 0
}

if [ $# -lt 1 ]; then usage; fi
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then usage; fi

SCOPE_FILE=""
DOMAIN=""
PASS_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage ;;
        -f|--scope|--file)
            SCOPE_FILE="${2:-}"
            if [ -z "$SCOPE_FILE" ]; then
                echo -e "${RED}[-]${NC} Missing path after $1"
                exit 1
            fi
            shift
            ;;
        -t|--threads)
            THREADS="${2:-20}"
            PASS_ARGS+=("$1" "$2")
            shift
            ;;
        --ports-top|--delay|--dir-hosts|-mc|--match-codes|--screenshot-limit|--param-hosts|--waf-hosts|--webhook)
            PASS_ARGS+=("$1" "${2:-}")
            case "$1" in
                --ports-top) PORTS_TOP="${2:-100}"; RUN_PORTS=true ;;
                --delay) DELAY="${2:-1}" ;;
                --dir-hosts) DIR_HOST_LIMIT="${2:-5}" ;;
                -mc|--match-codes) MATCH_CODES="${2:-200}" ;;
                --screenshot-limit) SCREENSHOT_LIMIT="${2:-10}" ;;
                --param-hosts) PARAM_HOST_LIMIT="${2:-5}" ;;
                --waf-hosts) WAF_HOST_LIMIT="${2:-5}" ;;
                --webhook) WEBHOOK_URL="${2:-}" ;;
            esac
            shift
            ;;
        --skip-active)       SKIP_ACTIVE=true; PASS_ARGS+=("$1") ;;
        --skip-permutation)  SKIP_PERMUTATION=true; PASS_ARGS+=("$1") ;;
        --skip-dirs)         SKIP_DIRS=true; PASS_ARGS+=("$1") ;;
        --skip-js)           SKIP_JS=true; PASS_ARGS+=("$1") ;;
        --skip-screenshots)  SKIP_SCREENSHOTS=true; PASS_ARGS+=("$1") ;;
        --skip-params)       SKIP_PARAMS=true; PASS_ARGS+=("$1") ;;
        --skip-takeover)     SKIP_TAKEOVER=true; PASS_ARGS+=("$1") ;;
        --skip-nuclei)       SKIP_NUCLEI=true; PASS_ARGS+=("$1") ;;
        --skip-waf)          SKIP_WAF=true; PASS_ARGS+=("$1") ;;
        --ports)             RUN_PORTS=true; PASS_ARGS+=("$1") ;;
        --ports-full)        PORTS_FULL=true; RUN_PORTS=true; PASS_ARGS+=("$1") ;;
        -*)
            echo -e "${YELLOW}[!]${NC} Unknown option: $1"
            ;;
        *)
            if [ -z "$DOMAIN" ] && [ -z "$SCOPE_FILE" ]; then
                if [ -f "$1" ]; then
                    SCOPE_FILE="$1"
                else
                    DOMAIN="$1"
                fi
            else
                echo -e "${YELLOW}[!]${NC} Ignoring extra argument: $1"
            fi
            ;;
    esac
    shift
done

# ---- Multi-target from file ----
if [ -n "$SCOPE_FILE" ]; then
    if [ ! -f "$SCOPE_FILE" ]; then
        echo -e "${RED}[-]${NC} Scope file not found: $SCOPE_FILE"
        exit 1
    fi

    if [ -z "${RECON_SECLISTS_PATH:-}" ]; then
        _sf_paths=("/usr/share/seclists" "/usr/share/wordlists/seclists" "/opt/SecLists" "/opt/seclists"
                   "$HOME/SecLists" "$HOME/seclists" "$HOME/wordlists/SecLists" "/usr/share/wordlists/SecLists")
        for _p in "${_sf_paths[@]}"; do
            if [ -d "$_p/Discovery/DNS" ] || [ -d "$_p/Discovery/Web-Content" ]; then
                export RECON_SECLISTS_PATH="$_p"
                break
            fi
        done
        if [ -z "${RECON_SECLISTS_PATH:-}" ]; then
            echo -e "${YELLOW}[!]${NC} SecLists not found. Enter path (or Enter to skip):"
            read -r -p "Path: " _up
            _up=$(echo "$_up" | xargs)
            [ -n "$_up" ] && [ -d "$_up" ] && export RECON_SECLISTS_PATH="$_up"
        fi
    fi

    echo -e "${CYAN}${BOLD}==============================================${NC}"
    echo -e "${CYAN}${BOLD}  Scope file : ${SCOPE_FILE}${NC}"
    echo -e "${CYAN}${BOLD}==============================================${NC}"

    mapfile -t _targets < <(grep -v '^\s*#' "$SCOPE_FILE" | grep -v '^\s*$' | sed 's/^\s*//;s/\s*$//' | sed 's|https\?://||g;s|/.*||g' | tr '[:upper:]' '[:lower:]' | sort -u)
    _total=${#_targets[@]}
    if [ "$_total" -eq 0 ]; then
        echo -e "${RED}[-]${NC} No targets in scope file"
        exit 1
    fi
    echo -e "${BLUE}[*]${NC} Loaded ${_total} target(s)"
    [ -n "${RECON_SECLISTS_PATH:-}" ] && echo -e "${GREEN}[+]${NC} SecLists: $RECON_SECLISTS_PATH"

    _i=0
    for _t in "${_targets[@]}"; do
        _i=$((_i + 1))
        echo ""
        echo -e "${CYAN}${BOLD}>>>>>>>> [${_i}/${_total}] TARGET: ${_t} <<<<<<<<${NC}"
        if ! "$0" "$_t" "${PASS_ARGS[@]}"; then
            echo -e "${RED}[-]${NC} Failed on target: $_t (continuing)"
        fi
    done

    echo ""
    echo -e "${GREEN}${BOLD}[+] Scope finished: ${_total} target(s)${NC}"
    exit 0
fi

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[-]${NC} No domain or scope file provided"
    usage
fi

# Apply global threads to every tool
THREADS_HTTPX=$THREADS
THREADS_FFUF=$THREADS
THREADS_DNSX=$THREADS
THREADS_NAABU=$THREADS

DOMAIN_CLEAN=$(echo "$DOMAIN" | sed 's|https\?://||g;s|/.*||g' | tr '[:upper:]' '[:lower:]')
OUT="recon_${DOMAIN_CLEAN}_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$OUT/recon.log"
mkdir -p "$OUT"/{subs,http,dirs,js,secrets,takeovers,dorks,wayback,info,nuclei,screenshots,params,ports,waf}
touch "$LOG_FILE"

echo -e "${CYAN}${BOLD}==============================================${NC}"
echo -e "${CYAN}${BOLD}  Target        : ${DOMAIN_CLEAN}${NC}"
echo -e "${CYAN}${BOLD}  Output folder : ${OUT}${NC}"
echo -e "${CYAN}${BOLD}==============================================${NC}"
info "Threads=${YELLOW}${THREADS}${NC} (all tools) | delay=${YELLOW}${DELAY}s${NC} | ports=${YELLOW}${RUN_PORTS}${NC} | mc=${YELLOW}${MATCH_CODES}${NC}"

export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin:$HOME/go/bin:/usr/local/go/bin"

HTTPX_BIN=""
if command -v httpx-toolkit &>/dev/null; then
    HTTPX_BIN="httpx-toolkit"
    ok "Using ${BOLD}httpx-toolkit${NC}"
elif command -v httpx &>/dev/null; then
    if httpx -h 2>&1 | grep -qiE "projectdiscovery|-l |list of hosts"; then
        HTTPX_BIN="httpx"
        ok "Using ${BOLD}httpx${NC} (ProjectDiscovery)"
    else
        warn "httpx looks like Python package"
        command -v httpx-toolkit &>/dev/null && HTTPX_BIN="httpx-toolkit"
    fi
fi

ensure_tool() {
    local tool="$1" install_cmd="${2:-}"
    if command -v "$tool" &>/dev/null; then
        ok "$tool is installed"
        return 0
    fi
    warn "$tool not found"
    if [ -n "$install_cmd" ]; then
        info "Installing $tool ..."
        if eval "$install_cmd"; then
            export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin:$HOME/go/bin"
            if command -v "$tool" &>/dev/null; then
                ok "$tool installed"
                return 0
            fi
        fi
        err "Failed to install $tool"
        return 1
    fi
    return 1
}

step "[0] Tools"
declare -A TOOLS=(
    ["curl"]="sudo apt-get install -y curl"
    ["jq"]="sudo apt-get install -y jq"
    ["git"]="sudo apt-get install -y git"
    ["python3"]="sudo apt-get install -y python3 python3-pip"
    ["subfinder"]="go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    ["dnsx"]="go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    ["nuclei"]="go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    ["katana"]="go install github.com/projectdiscovery/katana/cmd/katana@latest"
    ["waybackurls"]="go install github.com/tomnomnom/waybackurls@latest"
    ["gau"]="go install github.com/lc/gau/v2/cmd/gau@latest"
    ["getJS"]="go install github.com/003random/getJS@latest"
    ["ffuf"]="go install github.com/ffuf/ffuf/v2@latest"
    ["subzy"]="go install -v github.com/PentestPad/subzy@latest"
    ["alterx"]="go install github.com/projectdiscovery/alterx/cmd/alterx@latest"
    ["gowitness"]="go install github.com/sensepost/gowitness@latest"
    ["naabu"]="go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
)
[ -z "$HTTPX_BIN" ] && TOOLS["httpx"]="go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"

for tool in "${!TOOLS[@]}"; do
    ensure_tool "$tool" "${TOOLS[$tool]}" || true
done

if [ -z "$HTTPX_BIN" ]; then
    if command -v httpx-toolkit &>/dev/null; then HTTPX_BIN="httpx-toolkit"
    elif command -v httpx &>/dev/null && httpx -h 2>&1 | grep -qiE "projectdiscovery|-l "; then HTTPX_BIN="httpx"
    fi
fi

command -v arjun &>/dev/null || pip3 install arjun --break-system-packages 2>/dev/null || true
command -v wafw00f &>/dev/null || pip3 install wafw00f --break-system-packages 2>/dev/null || true
[ -f /tmp/LinkFinder/linkfinder.py ] || git clone --depth 1 https://github.com/GerbenJavado/LinkFinder.git /tmp/LinkFinder 2>/dev/null || true

ok "httpx binary: ${BOLD}${HTTPX_BIN:-NOT FOUND}${NC}"

find_seclists() {
    local paths=("/usr/share/seclists" "/usr/share/wordlists/seclists" "/opt/SecLists" "/opt/seclists"
                 "$HOME/SecLists" "$HOME/seclists" "$HOME/wordlists/SecLists" "/usr/share/wordlists/SecLists")
    for p in "${paths[@]}"; do
        if [ -d "$p/Discovery/DNS" ] || [ -d "$p/Discovery/Web-Content" ]; then
            echo "$p"; return 0
        fi
    done
    return 1
}

step "SecLists"
SECLISTS_PATH=""
if [ -n "${RECON_SECLISTS_PATH:-}" ] && [ -d "${RECON_SECLISTS_PATH}" ]; then
    SECLISTS_PATH="$RECON_SECLISTS_PATH"
    ok "SecLists (from env/scope): ${BOLD}$SECLISTS_PATH${NC}"
else
    FOUND_PATH=$(find_seclists || true)
    if [ -n "$FOUND_PATH" ]; then
        SECLISTS_PATH="$FOUND_PATH"
        ok "SecLists: ${BOLD}$SECLISTS_PATH${NC}"
    else
        warn "Enter SecLists path (or Enter to skip):"
        read -r -p "Path: " USER_PATH
        USER_PATH=$(echo "$USER_PATH" | xargs)
        if [ -n "$USER_PATH" ] && [ -d "$USER_PATH" ]; then
            SECLISTS_PATH="$USER_PATH"
            ok "Using: $SECLISTS_PATH"
        else
            warn "Continuing without SecLists"
        fi
    fi
fi

DNS_WORDLIST=""; DIR_WORDLIST=""
if [ -n "$SECLISTS_PATH" ]; then
    for f in Discovery/DNS/subdomains-top1million-5000.txt Discovery/DNS/subdomains-top1million-20000.txt Discovery/DNS/dns-Jhaddix.txt; do
        [ -f "$SECLISTS_PATH/$f" ] && DNS_WORDLIST="$SECLISTS_PATH/$f" && break
    done
    for f in Discovery/Web-Content/common.txt Discovery/Web-Content/raft-medium-directories.txt Discovery/Web-Content/directory-list-2.3-medium.txt; do
        [ -f "$SECLISTS_PATH/$f" ] && DIR_WORDLIST="$SECLISTS_PATH/$f" && break
    done
    ok "DNS WL: ${DNS_WORDLIST:-N/A}"
    ok "Dir WL: ${DIR_WORDLIST:-N/A}"
fi

step "[1] Passive Subdomains"
command -v subfinder &>/dev/null && subfinder -d "$DOMAIN_CLEAN" -all -silent -o "$OUT/subs/subfinder.txt" 2>/dev/null || touch "$OUT/subs/subfinder.txt"
curl -s "https://crt.sh/?q=%25.${DOMAIN_CLEAN}&output=json" 2>/dev/null | jq -r '.[].name_value' 2>/dev/null | sed 's/\*\.//g' | sort -u > "$OUT/subs/crtsh.txt" || true
cat "$OUT/subs/"*.txt 2>/dev/null | grep -E "\.${DOMAIN_CLEAN}$|^${DOMAIN_CLEAN}$" | sort -u > "$OUT/subs/passive_all.txt" || true
PASSIVE_COUNT=$(wc -l < "$OUT/subs/passive_all.txt" 2>/dev/null | tr -d ' ' || echo 0)
ok "Passive: ${BOLD}$PASSIVE_COUNT${NC}"

step "[2] Active Subdomains"
if [ "$SKIP_ACTIVE" = true ]; then
    warn "skipped"; touch "$OUT/subs/active_dnsx.txt"
elif [ -n "$DNS_WORDLIST" ] && [ -f "$DNS_WORDLIST" ] && command -v dnsx &>/dev/null; then
    dnsx -d "$DOMAIN_CLEAN" -w "$DNS_WORDLIST" -silent -t "$THREADS_DNSX" -o "$OUT/subs/active_dnsx.txt" 2>/dev/null || true
else
    touch "$OUT/subs/active_dnsx.txt"
fi
cat "$OUT/subs/passive_all.txt" "$OUT/subs/active_dnsx.txt" 2>/dev/null | sort -u > "$OUT/subs/merged_raw.txt"

step "[2.5] Permutation"
if [ "$SKIP_PERMUTATION" = true ]; then
    warn "skipped"
    cp "$OUT/subs/merged_raw.txt" "$OUT/subs/all_unresolved.txt"
elif command -v alterx &>/dev/null && [ -s "$OUT/subs/merged_raw.txt" ]; then
    cat "$OUT/subs/merged_raw.txt" | alterx -silent 2>/dev/null | sort -u > "$OUT/subs/permuted.txt" || true
    cat "$OUT/subs/merged_raw.txt" "$OUT/subs/permuted.txt" 2>/dev/null | sort -u > "$OUT/subs/all_unresolved.txt"
    ok "After permutation: $(wc -l < "$OUT/subs/all_unresolved.txt" | tr -d ' ')"
else
    warn "alterx not available"
    cp "$OUT/subs/merged_raw.txt" "$OUT/subs/all_unresolved.txt"
fi

step "[2.6] Resolve"
if command -v dnsx &>/dev/null && [ -s "$OUT/subs/all_unresolved.txt" ]; then
    dnsx -l "$OUT/subs/all_unresolved.txt" -silent -a -aaaa -resp -o "$OUT/subs/resolved_raw.txt" 2>/dev/null || true
    awk '{print $1}' "$OUT/subs/resolved_raw.txt" 2>/dev/null | sort -u > "$OUT/subs/all_subs.txt"
else
    cp "$OUT/subs/all_unresolved.txt" "$OUT/subs/all_subs.txt"
fi
TOTAL_SUBS=$(wc -l < "$OUT/subs/all_subs.txt" 2>/dev/null | tr -d ' ' || echo 0)
ok "Resolved: ${BOLD}$TOTAL_SUBS${NC}"

step "[3] HTTP Probing"
LIVE_COUNT=0
if [ -z "$HTTPX_BIN" ] || [ ! -s "$OUT/subs/all_subs.txt" ]; then
    err "skip httpx"; touch "$OUT/http/live_urls.txt"
else
    $HTTPX_BIN -l "$OUT/subs/all_subs.txt" -silent -status-code -title -tech-detect -follow-redirects -t "$THREADS_HTTPX" -json -o "$OUT/http/live.json" 2>/dev/null || true
    $HTTPX_BIN -l "$OUT/subs/all_subs.txt" -silent -status-code -title -follow-redirects -t "$THREADS_HTTPX" -o "$OUT/http/live.txt" 2>/dev/null || true
    grep -oE 'https?://[^ ]+' "$OUT/http/live.txt" 2>/dev/null | sort -u > "$OUT/http/live_urls.txt" || true
    LIVE_COUNT=$(wc -l < "$OUT/http/live_urls.txt" 2>/dev/null | tr -d ' ' || echo 0)
    ok "Live hosts: ${BOLD}$LIVE_COUNT${NC}"
    if [ -f "$OUT/http/live.json" ]; then
        jq -r 'select(.tech != null) | "\(.url) \(.tech)"' "$OUT/http/live.json" 2>/dev/null | \
            grep -iE 'cloudflare|akamai|incapsula|sucuri|fastly|cloudfront|imperva|wordfence' > "$OUT/http/waf_cdn_hints.txt" || true
    fi
fi

step "[3.5] WAF Detection"
> "$OUT/waf/waf_report.txt"; > "$OUT/waf/waf_summary.txt"
if [ "$SKIP_WAF" = true ]; then
    warn "skipped"
elif [ ! -s "$OUT/http/live_urls.txt" ]; then
    warn "no live hosts"
else
    [ -s "$OUT/http/waf_cdn_hints.txt" ] && sort -u "$OUT/http/waf_cdn_hints.txt" >> "$OUT/waf/waf_report.txt" || true
    if command -v wafw00f &>/dev/null; then
        head -n "$WAF_HOST_LIMIT" "$OUT/http/live_urls.txt" | while read -r url; do
            [ -z "$url" ] && continue
            info "wafw00f → $url"
            result=$(wafw00f -a "$url" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' || true)
            echo "===== $url =====" >> "$OUT/waf/waf_report.txt"
            echo "$result" >> "$OUT/waf/waf_report.txt"
            if echo "$result" | grep -qi "is behind"; then
                echo "$result" | grep -i "is behind" >> "$OUT/waf/waf_summary.txt" || true
            elif echo "$result" | grep -qi "No WAF"; then
                echo "$url → No WAF detected" >> "$OUT/waf/waf_summary.txt"
            else
                echo "$url → see report" >> "$OUT/waf/waf_summary.txt"
            fi
            [ "${DELAY:-0}" -gt 0 ] 2>/dev/null && sleep "$DELAY"
        done
    else
        warn "wafw00f missing — header heuristics"
        head -n "$WAF_HOST_LIMIT" "$OUT/http/live_urls.txt" | while read -r url; do
            [ -z "$url" ] && continue
            headers=$(curl -sI -k --max-time 10 "$url" 2>/dev/null || true)
            detected=""
            echo "$headers" | grep -qi "cf-ray\|cloudflare" && detected="Cloudflare"
            echo "$headers" | grep -qi "akamai" && detected="${detected:+$detected+}Akamai"
            echo "$headers" | grep -qi "sucuri" && detected="${detected:+$detected+}Sucuri"
            echo "$headers" | grep -qi "incapsula" && detected="${detected:+$detected+}Incapsula"
            echo "$headers" | grep -qi "cloudfront\|x-amz-cf" && detected="${detected:+$detected+}CloudFront"
            if [ -n "$detected" ]; then
                echo "$url → $detected" | tee -a "$OUT/waf/waf_summary.txt"
            else
                echo "$url → No clear WAF headers" >> "$OUT/waf/waf_summary.txt"
            fi
        done
    fi
    cat > "$OUT/waf/bypass_hints.txt" << 'BHEOF'
WAF bypassability (guidance only — verify manually):

Cloudflare       → MEDIUM–HIGH | origin IP (Shodan/Censys, non-proxied subs, Host header)
Akamai/Imperva   → HIGH        | prefer logic/auth bugs over pure evasion
Sucuri/Wordfence → LOW–MEDIUM  | sometimes weaker on non-app paths
No WAF           → still expect rate-limits / mod_security / custom rules

Lower threads (-t 5) + delay reduce bans more than most "bypass" tricks.
Directory 403 bypass ≠ full WAF evasion.
BHEOF
    {
        echo ""
        echo "=== Auto rating ==="
        grep -qi cloudflare "$OUT/waf/waf_summary.txt" 2>/dev/null && echo "Cloudflare-like → MEDIUM–HIGH"
        grep -qiE "akamai|incapsula|imperva" "$OUT/waf/waf_summary.txt" 2>/dev/null && echo "Enterprise WAF → HIGH"
        grep -qiE "sucuri|wordfence" "$OUT/waf/waf_summary.txt" 2>/dev/null && echo "Sucuri/Wordfence-like → LOW–MEDIUM"
        grep -qi "No WAF" "$OUT/waf/waf_summary.txt" 2>/dev/null && echo "Some hosts: No WAF reported"
    } >> "$OUT/waf/bypass_hints.txt"
    ok "WAF results → ${BOLD}$OUT/waf/${NC}"
    [ -s "$OUT/waf/waf_summary.txt" ] && notify "WAF detection done"
fi

step "[3.6] Port Scan"
if [ "$RUN_PORTS" != true ]; then
    warn "OFF (enable with --ports)"
elif [ ! -s "$OUT/subs/all_subs.txt" ]; then
    warn "no hosts"
elif ! command -v naabu &>/dev/null; then
    err "naabu missing"
else
    if [ "$PORTS_FULL" = true ]; then
        naabu -list "$OUT/subs/all_subs.txt" -rate "$THREADS_NAABU" -silent -o "$OUT/ports/naabu.txt" 2>/dev/null || true
    else
        naabu -list "$OUT/subs/all_subs.txt" -top-ports "$PORTS_TOP" -rate "$THREADS_NAABU" -silent -o "$OUT/ports/naabu.txt" 2>/dev/null || true
    fi
    pc=$(wc -l < "$OUT/ports/naabu.txt" 2>/dev/null | tr -d ' ' || echo 0)
    ok "Port lines: ${BOLD}$pc${NC}"
    [ "$pc" -gt 0 ] 2>/dev/null && notify "Port scan: $pc results"
fi

step "[4] Directory Enum"
if [ "$SKIP_DIRS" = true ]; then
    warn "skipped"
elif [ -n "$DIR_WORDLIST" ] && [ -f "$DIR_WORDLIST" ] && [ -s "$OUT/http/live_urls.txt" ] && command -v ffuf &>/dev/null; then
    head -n "$DIR_HOST_LIMIT" "$OUT/http/live_urls.txt" | while read -r url; do
        [ -z "$url" ] && continue
        clean_name=$(echo "$url" | sed 's|https\?://||;s|/|_|g' | cut -c1-60)
        info "ffuf → $url"
        ffuf -u "${url}/FUZZ" -w "$DIR_WORDLIST" -mc "$MATCH_CODES" \
             -t "$THREADS_FFUF" -s -o "$OUT/dirs/${clean_name}.json" -of json 2>/dev/null || true
        [ "${DELAY:-0}" -gt 0 ] 2>/dev/null && sleep "$DELAY"
    done
else
    warn "skip dirs"
fi

step "[4.5] 403 Bypass"
BYPASS_OUT="$OUT/dirs/403_bypass.txt"
> "$BYPASS_OUT"
FOUND_403=0
if [ "$SKIP_DIRS" = true ]; then
    warn "skipped"
elif ls "$OUT/dirs/"*.json &>/dev/null; then
    for jsonfile in "$OUT/dirs/"*.json; do
        [ -f "$jsonfile" ] || continue
        base_url=$(jq -r '.commandline // empty' "$jsonfile" 2>/dev/null | grep -oE 'https?://[^ ]+' | head -n1 | sed 's|/FUZZ||')
        [ -z "$base_url" ] && base_url=$(jq -r '.results[0].url // empty' "$jsonfile" 2>/dev/null | sed -E 's|/[^/]+$||')
        [ -z "$base_url" ] && continue
        while IFS= read -r path; do
            [ -z "$path" ] && continue
            FOUND_403=$((FOUND_403 + 1))
            original="${base_url}/${path}"
            for payload in "${path}/" "${path}//" "./${path}" "${path}%20" "${path}?" "${path}#" "${path}..;/" "%2e/${path}" "//${path}" "/./${path}"; do
                code=$(curl -s -o /dev/null -w "%{http_code}" -k --max-time 8 "${base_url}/${payload}" 2>/dev/null || echo 000)
                if [[ "$code" =~ ^(200|301|302|307)$ ]]; then
                    ok "PATH ${base_url}/${payload} [${code}]"
                    echo "PATH | $original | ${base_url}/${payload} | $code" >> "$BYPASS_OUT"
                fi
            done
            for hdr in "X-Original-URL: /${path}" "X-Rewrite-URL: /${path}" "X-Forwarded-For: 127.0.0.1" "X-Custom-IP-Authorization: 127.0.0.1" "X-Originating-IP: 127.0.0.1" "X-Client-IP: 127.0.0.1"; do
                code=$(curl -s -o /dev/null -w "%{http_code}" -k --max-time 8 -H "$hdr" "$original" 2>/dev/null || echo 000)
                if [[ "$code" =~ ^(200|301|302|307)$ ]]; then
                    ok "HDR $hdr [${code}]"
                    echo "HEADER | $original | $hdr | $code" >> "$BYPASS_OUT"
                fi
            done
        done < <(jq -r '.results[]? | select(.status == 403) | .input.FUZZ // empty' "$jsonfile" 2>/dev/null)
    done
    bc=$(wc -l < "$BYPASS_OUT" 2>/dev/null | tr -d ' ' || echo 0)
    ok "403 tested=${FOUND_403} bypasses=${BOLD}${bc}${NC}"
    [ "$bc" -gt 0 ] 2>/dev/null && notify "403 bypass x$bc"
else
    warn "no ffuf json"
fi

step "[5] Screenshots"
if [ "$SKIP_SCREENSHOTS" = true ]; then
    warn "skipped"
elif [ -s "$OUT/http/live_urls.txt" ] && command -v gowitness &>/dev/null; then
    head -n "$SCREENSHOT_LIMIT" "$OUT/http/live_urls.txt" > "$OUT/screenshots/targets.txt"
    gowitness scan file -f "$OUT/screenshots/targets.txt" --screenshot-path "$OUT/screenshots" --delay 2 2>/dev/null || \
    gowitness file -f "$OUT/screenshots/targets.txt" -P "$OUT/screenshots" 2>/dev/null || true
    ok "screenshots saved"
else
    warn "skip screenshots"
fi

step "[6] JS Analysis"
if [ "$SKIP_JS" = true ]; then
    warn "skipped"
elif [ -s "$OUT/http/live_urls.txt" ]; then
    > "$OUT/js/js_files.txt"
    command -v getJS &>/dev/null && cat "$OUT/http/live_urls.txt" | getJS --complete 2>/dev/null >> "$OUT/js/js_files.txt" || true
    if command -v katana &>/dev/null; then
        katana -list "$OUT/http/live_urls.txt" -jc -d 2 -silent -o "$OUT/js/katana.txt" 2>/dev/null || true
        grep -E '\.js(\?|$)' "$OUT/js/katana.txt" 2>/dev/null >> "$OUT/js/js_files.txt" || true
    fi
    sort -u "$OUT/js/js_files.txt" -o "$OUT/js/js_files.txt"
    > "$OUT/js/endpoints.txt"; > "$OUT/secrets/js_secrets.txt"
    if [ -s "$OUT/js/js_files.txt" ] && [ -f /tmp/LinkFinder/linkfinder.py ]; then
        while read -r jsurl; do
            [ -z "$jsurl" ] && continue
            python3 /tmp/LinkFinder/linkfinder.py -i "$jsurl" -o cli 2>/dev/null >> "$OUT/js/linkfinder.txt" || true
        done < <(head -n 30 "$OUT/js/js_files.txt")
        grep -oE '/[a-zA-Z0-9_./?=&%-]+' "$OUT/js/linkfinder.txt" 2>/dev/null >> "$OUT/js/endpoints.txt" || true
    fi
    if [ -s "$OUT/js/js_files.txt" ]; then
        while read -r jsurl; do
            [ -z "$jsurl" ] && continue
            content=$(curl -sL --max-time 12 -k "$jsurl" 2>/dev/null || true)
            [ -z "$content" ] && continue
            echo "$content" | grep -oE '["'\''`](/[a-zA-Z0-9_./?=&%-]{2,})["'\''`]' | tr -d '"'\''`' >> "$OUT/js/endpoints.txt"
            echo "$content" | grep -EiO '.{0,40}(api[_-]?key|access[_-]?token|secret[_-]?key|client[_-]?secret|aws_access|aws_secret|authorization|bearer[[:space:]]+[a-zA-Z0-9._-]{20,}|private[_-]?key|password[[:space:]]*[:=]).{0,40}' >> "$OUT/secrets/js_secrets.txt" 2>/dev/null || true
        done < "$OUT/js/js_files.txt"
    fi
    command -v nuclei &>/dev/null && nuclei -l "$OUT/http/live_urls.txt" -t http/exposures/tokens/ -t http/exposures/configs/ -silent -o "$OUT/secrets/nuclei_tokens.txt" 2>/dev/null || true
    sort -u "$OUT/js/endpoints.txt" -o "$OUT/js/endpoints.txt"
    sort -u "$OUT/secrets/js_secrets.txt" -o "$OUT/secrets/js_secrets.txt"
    ok "JS=$(wc -l < "$OUT/js/js_files.txt" 2>/dev/null | tr -d ' ') endpoints=$(wc -l < "$OUT/js/endpoints.txt" 2>/dev/null | tr -d ' ') secrets=$(wc -l < "$OUT/secrets/js_secrets.txt" 2>/dev/null | tr -d ' ')"
    [ -s "$OUT/secrets/js_secrets.txt" ] && notify "JS secrets found"
else
    warn "skip JS"
fi

step "[7] Parameters"
if [ "$SKIP_PARAMS" = true ]; then
    warn "skipped"
elif [ -s "$OUT/http/live_urls.txt" ]; then
    head -n "$PARAM_HOST_LIMIT" "$OUT/http/live_urls.txt" > "$OUT/params/targets.txt"
    if command -v arjun &>/dev/null; then
        while read -r url; do
            [ -z "$url" ] && continue
            safe=$(echo "$url" | md5sum | cut -c1-8)
            arjun -u "$url" -oT "$OUT/params/arjun_${safe}.txt" -q 2>/dev/null || true
            [ "${DELAY:-0}" -gt 0 ] 2>/dev/null && sleep "$DELAY"
        done < "$OUT/params/targets.txt"
        cat "$OUT/params/"arjun_*.txt 2>/dev/null | sort -u > "$OUT/params/all_params.txt" || true
    else
        cat "$OUT/wayback/all_historical.txt" "$OUT/js/katana.txt" 2>/dev/null | grep -oE '\?[a-zA-Z0-9_&=%-]+' | tr '&' '\n' | sed 's/^[?]//' | cut -d= -f1 | sort -u > "$OUT/params/all_params.txt" || true
    fi
    ok "params=$(wc -l < "$OUT/params/all_params.txt" 2>/dev/null | tr -d ' ' || echo 0)"
else
    warn "skip params"
fi

step "[8] Info Disclosure"
if [ -s "$OUT/http/live_urls.txt" ]; then
    command -v nuclei &>/dev/null && nuclei -l "$OUT/http/live_urls.txt" -t http/exposures/ -silent -o "$OUT/info/nuclei_exposures.txt" 2>/dev/null || true
    > "$OUT/info/sensitive_files.txt"
    while read -r url; do
        [ -z "$url" ] && continue
        for path in .env .git/config backup.sql phpinfo.php config.yml web.config .DS_Store robots.txt sitemap.xml actuator/env server-status debug .svn/entries .htaccess wp-config.php config.php .aws/credentials docker-compose.yml; do
            code=$(curl -s -o /dev/null -w "%{http_code}" -k --max-time 8 "${url}/${path}" 2>/dev/null || echo 000)
            [[ "$code" =~ ^(200|403)$ ]] && echo "${url}/${path} → $code" >> "$OUT/info/sensitive_files.txt"
        done
    done < <(head -n 15 "$OUT/http/live_urls.txt")
    ok "info disclosure saved"
    { [ -s "$OUT/info/sensitive_files.txt" ] || [ -s "$OUT/info/nuclei_exposures.txt" ]; } && notify "Info disclosure findings"
else
    warn "skip info"
fi

step "[9] Takeover"
if [ "$SKIP_TAKEOVER" = true ]; then
    warn "skipped"
elif [ -s "$OUT/subs/all_subs.txt" ]; then
    command -v subzy &>/dev/null && subzy run --targets "$OUT/subs/all_subs.txt" --hide_fails --concurrency 40 --output "$OUT/takeovers/subzy.txt" 2>/dev/null || true
    command -v nuclei &>/dev/null && nuclei -l "$OUT/subs/all_subs.txt" -t http/takeovers/ -silent -o "$OUT/takeovers/nuclei_takeovers.txt" 2>/dev/null || true
    ok "takeover done"
    { [ -s "$OUT/takeovers/subzy.txt" ] || [ -s "$OUT/takeovers/nuclei_takeovers.txt" ]; } && notify "Possible takeover"
else
    warn "skip takeover"
fi

step "[10] Historical URLs"
command -v waybackurls &>/dev/null && echo "$DOMAIN_CLEAN" | waybackurls 2>/dev/null | sort -u > "$OUT/wayback/waybackurls.txt" || touch "$OUT/wayback/waybackurls.txt"
command -v gau &>/dev/null && echo "$DOMAIN_CLEAN" | gau --subs 2>/dev/null | sort -u > "$OUT/wayback/gau.txt" || touch "$OUT/wayback/gau.txt"
cat "$OUT/wayback/"*.txt 2>/dev/null | sort -u > "$OUT/wayback/all_historical.txt"
ok "historical=$(wc -l < "$OUT/wayback/all_historical.txt" 2>/dev/null | tr -d ' ' || echo 0)"

step "[11] Dorks"
cat > "$OUT/dorks/google_dorks.txt" << EOF
site:${DOMAIN_CLEAN} ext:env
site:${DOMAIN_CLEAN} ext:sql | ext:db | ext:bak
site:${DOMAIN_CLEAN} ext:log
site:${DOMAIN_CLEAN} inurl:admin | inurl:login | inurl:dashboard
site:${DOMAIN_CLEAN} inurl:api | inurl:v1 | inurl:graphql
site:${DOMAIN_CLEAN} "index of /"
site:${DOMAIN_CLEAN} ext:xml | ext:conf | ext:config
site:${DOMAIN_CLEAN} intext:"password" | intext:"api_key" | intext:"secret"
site:${DOMAIN_CLEAN} inurl:.git
site:pastebin.com "${DOMAIN_CLEAN}"
site:*.${DOMAIN_CLEAN} ext:js
EOF
cat > "$OUT/dorks/github_dorks.txt" << EOF
"${DOMAIN_CLEAN}" password
"${DOMAIN_CLEAN}" api_key
"${DOMAIN_CLEAN}" secret
"${DOMAIN_CLEAN}" aws_access_key
"${DOMAIN_CLEAN}" filename:.env
"${DOMAIN_CLEAN}" filename:config.js
"${DOMAIN_CLEAN}" filename:credentials
"${DOMAIN_CLEAN}" "BEGIN RSA PRIVATE KEY"
"${DOMAIN_CLEAN}" language:JSON password
"${DOMAIN_CLEAN}" npmrc _auth
EOF
ok "dorks saved"

step "[12] Extra Nuclei"
if [ "$SKIP_NUCLEI" = true ]; then
    warn "skipped"
elif [ -s "$OUT/http/live_urls.txt" ] && command -v nuclei &>/dev/null; then
    nuclei -l "$OUT/http/live_urls.txt" -t http/misconfiguration/ -t http/vulnerabilities/ -t http/technologies/ -silent -o "$OUT/nuclei/extra.txt" 2>/dev/null || true
    ok "nuclei extra done"
    [ -s "$OUT/nuclei/extra.txt" ] && notify "Nuclei findings"
else
    warn "skip nuclei"
fi

echo ""
echo -e "${CYAN}${BOLD}==============================================${NC}"
echo -e "${CYAN}${BOLD}                 SCAN SUMMARY${NC}"
echo -e "${CYAN}${BOLD}==============================================${NC}"
printf "${BOLD}%-22s${NC} %s\n" "Target:" "$DOMAIN_CLEAN"
printf "${BOLD}%-22s${NC} %s\n" "Output:" "$OUT"
printf "${BOLD}%-22s${NC} %s\n" "Threads (-t):" "$THREADS"
printf "${BOLD}%-22s${NC} %s\n" "Match codes (-mc):" "$MATCH_CODES"
printf "${BOLD}%-22s${NC} %s\n" "httpx:" "${HTTPX_BIN:-N/A}"
printf "${BOLD}%-22s${NC} %s\n" "Passive subs:" "$PASSIVE_COUNT"
printf "${BOLD}%-22s${NC} %s\n" "Resolved subs:" "$TOTAL_SUBS"
printf "${BOLD}%-22s${NC} %s\n" "Live hosts:" "$LIVE_COUNT"
printf "${BOLD}%-22s${NC} %s\n" "JS files:" "$(wc -l < "$OUT/js/js_files.txt" 2>/dev/null | tr -d ' ' || echo 0)"
printf "${BOLD}%-22s${NC} %s\n" "Endpoints:" "$(wc -l < "$OUT/js/endpoints.txt" 2>/dev/null | tr -d ' ' || echo 0)"
printf "${BOLD}%-22s${NC} %s\n" "JS secrets:" "$(wc -l < "$OUT/secrets/js_secrets.txt" 2>/dev/null | tr -d ' ' || echo 0)"
printf "${BOLD}%-22s${NC} %s\n" "403 bypasses:" "$(wc -l < "$OUT/dirs/403_bypass.txt" 2>/dev/null | tr -d ' ' || echo 0)"
printf "${BOLD}%-22s${NC} %s\n" "Params:" "$(wc -l < "$OUT/params/all_params.txt" 2>/dev/null | tr -d ' ' || echo 0)"
printf "${BOLD}%-22s${NC} %s\n" "Historical URLs:" "$(wc -l < "$OUT/wayback/all_historical.txt" 2>/dev/null | tr -d ' ' || echo 0)"
printf "${BOLD}%-22s${NC} %s\n" "Port results:" "$(wc -l < "$OUT/ports/naabu.txt" 2>/dev/null | tr -d ' ' || echo 0)"
printf "${BOLD}%-22s${NC} %s\n" "WAF summary lines:" "$(wc -l < "$OUT/waf/waf_summary.txt" 2>/dev/null | tr -d ' ' || echo 0)"
echo -e "${CYAN}${BOLD}==============================================${NC}"
ok "Done → ${BOLD}${GREEN}$OUT${NC}"
notify "Recon finished for $DOMAIN_CLEAN → $OUT"
