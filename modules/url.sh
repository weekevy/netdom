#!/bin/bash
declare -A TOOL_PATHS # Global associative array to store tool paths

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_WHITE='\033[1;37m'
PURPLE='\033[0;35m'
UNDERLINE='\033[4m'
RESET='\033[0m'


url_usage() {
    echo -e "${BOLD_GREEN}Usage: reecon url [MODE] [OPTIONS]${RESET}"
    echo ""
    echo -e "${YELLOW}Modes:${RESET}"
    echo -e "  --passive          Passive URL enumeration using waybackurl and passive katana"
    echo -e "  --active           Active URL enumeration using katana, hakrawler, and gospider"
    echo ""
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  reecon url --passive -d example.com -o passive_urls.txt"
    echo -e "  reecon url --active -l domains.txt -O active_results/"
    echo -e "  reecon url --help          Show general help for url module"
    exit 1
}

show_passive_usage() {
    echo -e "${BOLD_GREEN}Usage: reecon url --passive [OPTIONS]${RESET}"
    echo ""
    echo -e "${YELLOW}Options for Passive Mode:${RESET}"
    echo -e "  -d <domain>        Single domain to process (e.g., example.com)"
    echo -e "  -l <file>          File containing list of domains"
    echo -e "  -o <output_file>   Output file to save results (for single domain)"
    echo -e "  -O <output_dir>    Output directory to save results (for domain list)"
    echo -e "  -h                 Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${RESET}"
    echo -e "  reecon url --passive -d example.com -o passive_urls.txt"
    echo -e "  reecon url --passive -l domains.txt -O passive_results/"
    exit 1
}


run_waybackurl() {
    local domain="$1"
    local output_file="$2"
    
    echo -e "${BOLD_GREEN}[+] Running waybackurl for: $domain${RESET}"
    
    local temp_output=$(mktemp)
    # //
    waybackurl "$domain" > "$temp_output" 2>/dev/null
    local count=$(wc -l < "$temp_output" | tr -d ' ')
    
    if [ -s "$temp_output" ]; then
        sort -u "$temp_output" > "$output_file"
        echo -e "${GREEN}[+] Found $count URLs with waybackurl for $domain. Results saved to: $output_file${RESET}"
    else
        echo -e "${YELLOW}[-] No URLs found with waybackurl for $domain.${RESET}"
        touch "$output_file"
    fi
}

passive_enumeration () {

    



}

main() {
    if [[ $# -eq 0 ]]; then
        url_usage
    fi

    case "$1" in
        --passive)
            passive_enumeration "$@"
            ;;
        --active) # Re-enabled active mode
            echo "coming soon!"
            ;;
        -h|--help)
            url_usage
            ;;
        *)
            echo -e "${RED}[-] Error: Unknown mode '$1'. Use --passive or --active.${RESET}"
            url_usage
            ;;
    esac
    exit 0
}

# Execute main function with all script arguments
main "$@"




