#!/bin/bash

RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'

BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_WHITE='\033[1;37m'

OUTPUT_FILE="./all_subs.txt"

show_usage() {
    echo -e "${BOLD_GREEN}Usage: $0 -d <domain> [-o <output_file>]${RESET}"
    echo -e "${YELLOW}Options:${RESET}"
    echo -e "  -d <domain>    Target domain to enumerate"
    echo -e "  -o <file>      Output file (default: ./all_subs.txt)"
    echo -e ""
    echo -e "${BOLD_GREEN}Examples:${RESET}"
    echo -e "  $0 -d example.com"
    echo -e "  $0 -d example.com -o /home/user/subdomains.txt"
    exit 1
}

check_tools() {
    local tools=("subfinder" "assetfinder" "findomain" "chaos" "dnsrecon" "jq" "curl")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}[-] Missing tools: ${missing[*]}${RESET}"
        echo -e "${YELLOW}[+] Please install missing tools and try again${RESET}"
        exit 1
    fi
}

single_target() {
    local domain=$1
    local output_file="$OUTPUT_FILE"
    local temp_dir=$(mktemp -d)
    
    echo -e "${BOLD_GREEN}[+] Starting passive subdomain enumeration for: $domain${RESET}"
    echo -e "${BOLD_GREEN}[+] Output file: $output_file${RESET}"
    
    # 1. Subfinder
    echo -e "${GREEN}[+] subfinder working !${RESET}"
    subfinder -d "$domain" -silent > "$temp_dir/subfinder.txt" 2>/dev/null
    local subfinder_count=$(wc -l < "$temp_dir/subfinder.txt" 2>/dev/null || echo "0")
    echo -e "${GREEN}[+] subfinder done : $subfinder_count subdomains${RESET}"

    # 2. Assetfinder
    echo -e "${YELLOW}[+] assetfinder working !${RESET}"
    assetfinder --subs-only "$domain" > "$temp_dir/assetfinder.txt" 2>/dev/null
    local assetfinder_count=$(wc -l < "$temp_dir/assetfinder.txt" 2>/dev/null || echo "0")
    echo -e "${YELLOW}[+] assetfinder done : $assetfinder_count subdomains${RESET}"
    
    # 3. crt.sh
    echo -e "${BLUE}[+] crt.sh working !${RESET}"
    curl -s "https://crt.sh/?q=%25.$domain&output=json" | jq -r '.[].name_value // empty' 2>/dev/null | sed 's/\*\.//g' | sort -u > "$temp_dir/crtsh.txt" 2>/dev/null
    local crtsh_count=$(wc -l < "$temp_dir/crtsh.txt" 2>/dev/null || echo "0")
    echo -e "${BLUE}[+] crt.sh done : $crtsh_count subdomains${RESET}"

    # 4. Findomain
    echo -e "${CYAN}[+] findomain working !${RESET}"
    findomain -t "$domain" --quiet -u "$temp_dir/findomain.txt" > /dev/null 2>&1
    local findomain_count=$(wc -l < "$temp_dir/findomain.txt" 2>/dev/null || echo "0")
    echo -e "${CYAN}[+] findomain done : $findomain_count subdomains${RESET}"

    # 5. DNSRecon (Passive standard enumeration)
    echo -e "${BOLD_YELLOW}[+] dnsrecon working !${RESET}"
    dnsrecon -d "$domain" -t std > "$temp_dir/dnsrecon.txt" 2>/dev/null
    local dnsrecon_count=$(grep -c "$domain" "$temp_dir/dnsrecon.txt" 2>/dev/null || echo "0")
    echo -e "${BOLD_YELLOW}[+] dnsrecon done : $dnsrecon_count records${RESET}"

    # 6. Chaos
    echo -e "${BOLD_WHITE}[+] chaos working !${RESET}"
    chaos -d "$domain" -silent > "$temp_dir/chaos.txt" 2>/dev/null
    local chaos_count=$(wc -l < "$temp_dir/chaos.txt" 2>/dev/null || echo "0")
    echo -e "${BOLD_WHITE}[+] chaos done : $chaos_count subdomains${RESET}"

    echo -e "${PURPLE}[+] Combining and deduplicating results...${RESET}"
    cat "$temp_dir"/{subfinder,assetfinder,crtsh,findomain,chaos}.txt 2>/dev/null | \
        grep -E "^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" | \
        grep "$domain" | \
        sort -u > "$output_file"
    
    local total_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
    
    rm -rf "$temp_dir"
    
    echo -e "${BOLD_GREEN}"
    echo "=== ENUMERATION SUMMARY ==="
    echo "Domain: $domain"
    echo "Subfinder: $subfinder_count"
    echo "Assetfinder: $assetfinder_count"
    echo "crt.sh: $crtsh_count"
    echo "Findomain: $findomain_count"
    echo "Chaos: $chaos_count"
    echo "DNSRecon: $dnsrecon_count"
    echo "-------------------"
    echo "Total unique subdomains: $total_count"
    echo "Final output: $output_file"
    echo -e "${RESET}"
}

main() {
    local domain=""
    
    while getopts "d:o:h" opt; do
        case $opt in
            d)
                domain="$OPTARG"
                ;;
            o)
                OUTPUT_FILE="$OPTARG"
                ;;
            h)
                show_usage
                ;;
            \?)
                echo -e "${RED}[-] Invalid option: -$OPTARG${RESET}" >&2
                show_usage
                ;;
            :)
                echo -e "${RED}[-] Option -$OPTARG requires an argument.${RESET}" >&2
                show_usage
                ;;
        esac
    done
    
    if [ -z "$domain" ]; then
        echo -e "${RED}[-] Error: Domain is required${RESET}"
        show_usage
    fi
    
    check_tools
    single_target "$domain"
}

main "$@"
