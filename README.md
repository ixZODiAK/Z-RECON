# Z-RECON
# [*Whoami*](https://ebrahim-hammad.vercel.app)

**All-in-one Bash reconnaissance toolkit for bug bounty & authorized security testing.**

```text
 ███████╗     ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
 ╚══███╔╝     ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
   ███╔╝█████╗██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
  ███╔╝ ╚════╝██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
 ███████╗     ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
 ╚══════╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
```

**Created by:** ZODiAK  

---

## Features

| Stage | What it does |
|-------|----------------|
| **Tool bootstrap** | Checks & installs missing tools (`go install` / `apt` / `pip`) |
| **Passive subs** | `subfinder` + crt.sh |
| **Active subs** | `dnsx` + SecLists wordlists |
| **Permutation** | `alterx` |
| **DNS resolve** | Clean resolved host list |
| **HTTP probing** | Live hosts, titles, tech (`httpx` / `httpx-toolkit`) |
| **WAF / CDN** | Detection + rough bypass difficulty (`wafw00f` / headers) |
| **Port scan** | Optional `naabu` (`--ports`) |
| **Directories** | `ffuf` with configurable match codes (`-mc`) |
| **403 bypass** | Path & header tricks on 403 hits |
| **Screenshots** | `gowitness` |
| **JS analysis** | Harvest JS → endpoints + secrets |
| **Parameters** | `arjun` or passive extraction |
| **Info disclosure** | Nuclei exposures + sensitive paths |
| **Takeover** | `subzy` + Nuclei takeover templates |
| **Historical URLs** | `waybackurls` + `gau` |
| **Dorks** | Google & GitHub dork lists |
| **Extra Nuclei** | Misconfig / vulns / tech |
| **Scope file** | Run against a full domain/subdomain list (`-f`) |
| **Rate control** | Global `-t`, `--delay`, host limits |
| **Notify** | Optional Discord/Slack webhook |

---

## Requirements

- Linux (Kali / Ubuntu recommended)
- Bash 4+
- `curl`, `jq`, `git`, `python3`
- Go toolchain (for most recon binaries)
- [SecLists](https://github.com/danielmiessler/SecLists) (recommended)

```bash
# SecLists
sudo git clone https://github.com/danielmiessler/SecLists /usr/share/seclists

# Go bin in PATH
export PATH="$PATH:$(go env GOPATH)/bin:$HOME/go/bin"
```

On **Kali**, the script prefers `httpx-toolkit` over the Python `httpx` package.

---

## Install

```bash
git clone https://github.com/ixZODiAK/z-recon.git
cd z-recon
chmod +x z-recon.sh
```

---

## Usage

```bash
./z-recon.sh -h
./z-recon.sh <domain> [options]
./z-recon.sh -f <scope.txt> [options]
```

### Single target

```bash
./z-recon.sh example.com
./z-recon.sh example.com -t 5
./z-recon.sh example.com -t 8 --ports --delay 2
./z-recon.sh example.com -mc 200,301,403
./z-recon.sh example.com -t 5 --skip-dirs --skip-screenshots
```

### Scope file (domains / subdomains)

```bash
./z-recon.sh -f scope.txt
./z-recon.sh --scope domains.txt -t 5 -mc 200
./z-recon.sh --file subs.txt --ports --delay 2

# or pass the file as first argument
./z-recon.sh scope.txt -t 8
```

**Example `scope.txt`:**

```text
# comments allowed
example.com
api.example.com
https://app.target.org
sub.domain.com
```

Empty lines and `#` comments are ignored. Each target gets its own output folder.

---

## Options

### Global threads

| Flag | Description | Default |
|------|-------------|---------|
| `-t <n>` / `--threads <n>` | Threads/rate for httpx, ffuf, dnsx, naabu | `20` |

### Scope

| Flag | Description |
|------|-------------|
| `-f <file>` / `--scope <file>` / `--file <file>` | Run on every host in the file |

### Directory match codes

| Flag | Description | Default |
|------|-------------|---------|
| `-mc <codes>` / `--match-codes <codes>` | ffuf `-mc` status codes | `200,201,202,203,204,301,302,307,401,403,500` |

```bash
./z-recon.sh example.com -mc 200
./z-recon.sh example.com -mc 200,301,403
```

### Skip modules

```text
--skip-active
--skip-permutation
--skip-dirs
--skip-js
--skip-screenshots
--skip-params
--skip-takeover
--skip-nuclei
--skip-waf
```

### Optional

| Flag | Description | Default |
|------|-------------|---------|
| `--ports` | Enable port scan | off |
| `--ports-top <n>` | Top N ports | `100` |
| `--ports-full` | Broader naabu scan | off |
| `--delay <sec>` | Delay between heavy requests | `1` |
| `--dir-hosts <n>` | Max hosts for directory fuzz | `5` |
| `--screenshot-limit <n>` | Max screenshots | `10` |
| `--param-hosts <n>` | Max hosts for param discovery | `5` |
| `--waf-hosts <n>` | Max hosts for wafw00f | `5` |
| `--webhook <url>` | Discord / Slack webhook | — |

### Anti-ban profile

```bash
./z-recon.sh target.com -t 5 --delay 2 --dir-hosts 3 --skip-screenshots
```

---

## Output structure

```text
recon_<domain>_YYYYMMDD_HHMMSS/
├── recon.log
├── subs/           # passive, active, permuted, resolved
├── http/           # live hosts, json, waf/cdn hints
├── dirs/           # ffuf json + 403_bypass.txt
├── waf/            # summary, report, bypass hints
├── ports/          # naabu results (if --ports)
├── screenshots/
├── js/             # js files, endpoints
├── secrets/
├── params/
├── info/
├── takeovers/
├── wayback/
├── dorks/
└── nuclei/
```

---

## Workflow (high level)

```text
Domain / Scope file
    → Passive + Active subs
    → Permutation + Resolve
    → HTTP live hosts
    → WAF detect
    → Ports (optional)
    → Directories + 403 bypass
    → Screenshots
    → JS / secrets / params
    → Info disclosure + Takeover
    → Wayback + Dorks + Nuclei
    → Summary + webhook
```

---

## Notes

- Port scanning is **off by default** — enable with `--ports`.
- WAF module is **detection + guidance**, not a full automated WAF bypass.
- 403 bypass only runs on paths ffuf reported as `403`.
- Missing tools are installed when possible.
- SecLists is auto-detected; prompted once when using a scope file.

---

**[*ZODiAK*](https://ebrahim-hammad.vercel.app) · Z-RECON**
