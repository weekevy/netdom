#!/bin/bash

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d DOMAIN        Single domain to enumerate"
    echo "  -l FILE          File containing list of domains"
    echo "  -w WORDLIST      Wordlist for bruteforce (required)"
    echo "  -t THREADS       Threads for massdns (default: 1000)"
    echo "  -r RESOLVERS     Resolvers file (default: /opt/massdns/lists/resolvers.txt)"
    echo "  -o OUTPUT        Output file (default: brute_results.txt)"
    echo "  -h               Show this help message"
    echo ""
    echo "Defaults:"
    echo "  THREADS: 1000"
    echo "  RESOLVERS: /opt/massdns/lists/resolvers.txt"
    echo "  OUTPUT: brute_results.txt"
    echo ""
    echo "Examples:"
    echo "  $0 -d example.com -w subdomains.txt -t 2000"
    echo "  $0 -l domains.txt -w all.txt -o results.txt"
    exit 1
}

check_dependencies() {
    local deps=("massdns" "dnsx")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: $dep not found"
            exit 1
        fi
    done
}

generate_dns_queries() {
    local domain="$1"
    local wordlist="$2"
    
    if [ ! -f "$wordlist" ]; then
        echo "Error: Wordlist $wordlist not found"
        exit 1
    fi
    
    # Create DNS queries: subdomain.domain.tld
    while IFS= read -r sub; do
        sub=$(echo "$sub" | tr -d '[:space:]')
        if [ -n "$sub" ]; then
            echo "${sub}.${domain}"
        fi
    done < "$wordlist"
}

detect_wildcard() {
    local domain="$1"
    local resolvers="$2"
    
    echo "[*] Checking for wildcard subdomains..."
    
    # Generate random subdomains to test
    for i in {1..5}; do
        random_sub=$(head /dev/urandom | tr -dc 'a-z0-9' | fold -w 20 | head -n 1)
        test_domain="${random_sub}.${domain}"
        
        if massdns -r "$resolvers" -t A -o S -w /dev/stdout <<< "$test_domain" 2>/dev/null | grep -q "ANSWER: 1"; then
        echo "[!] Wildcard detected for *.${domain}"
            return 0
        fi
    done
    
    echo "[+] No wildcard detected"
    return 1
}

bruteforce_domain() {
    local domain="$1"
    local wordlist="$2"
    local threads="$3"
    local resolvers="$4"
    local output="$5"
    
    echo "[*] Starting bruteforce for: $domain"
    echo "[*] Wordlist: $wordlist ($(wc -l < "$wordlist" | tr -d ' ') words)"
    echo "[*] Threads: $threads"
    
    # Generate queries and run massdns
    generate_dns_queries "$domain" "$wordlist" | \
    massdns -r "$resolvers" -t A -o S -w /dev/stdout -s "$threads" 2>/dev/null | \
    grep "ANSWER: 1" | \
    awk '{print $1}' | sed 's/\.$//' | \
    sort -u > "$output.tmp"
    
    # Verify with dnsx to reduce false positives
    if [ -s "$output.tmp" ]; then
        echo "[*] Verifying results with dnsx..."
        cat "$output.tmp" | dnsx -silent -a -resp -r "$resolvers" | \
        awk '{print $1}' | sort -u > "$output"
        
        found_count=$(wc -l < "$output" | tr -d ' ')
        echo "[+] Found $found_count valid subdomains for $domain"
    else
        echo "[-] No subdomains found for $domain"
        touch "$output"
    fi
    
    rm -f "$output.tmp"
}

# Default values
DOMAIN=""
LIST_FILE=""
WORDLIST=""
THREADS=1000
RESOLVERS="/home/dvsys/Desktop/github/netdom/resolvers/resolvers.txt"
OUTPUT="brute_results.txt"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d) DOMAIN="$2"; shift 2 ;;
        -l) LIST_FILE="$2"; shift 2 ;;
        -w) WORDLIST="$2"; shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        -r) RESOLVERS="$2"; shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Validate inputs
if [ -z "$WORDLIST" ]; then
    echo "Error: Wordlist is required (-w)"
    exit 1
fi

if [ -z "$DOMAIN" ] && [ -z "$LIST_FILE" ]; then
    echo "Error: Either -d or -l must be specified"
    exit 1
fi

if [ ! -f "$RESOLVERS" ]; then
    echo "Error: Resolvers file $RESOLVERS not found"
    echo "Get it from: https://raw.githubusercontent.com/blechschmidt/massdns/master/lists/resolvers.txt"
    exit 1
fi

# Check dependencies
check_dependencies

# Create output directory if needed
output_dir=$(dirname "$OUTPUT")
if [ -n "$output_dir" ] && [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
fi

# Main execution
if [ -n "$DOMAIN" ]; then
    # Single domain
    detect_wildcard "$DOMAIN" "$RESOLVERS"
    bruteforce_domain "$DOMAIN" "$WORDLIST" "$THREADS" "$RESOLVERS" "$OUTPUT"
else
    # Multiple domains from file
    if [ ! -f "$LIST_FILE" ]; then
        echo "Error: Domain list $LIST_FILE not found"
        exit 1
    fi
    
    total_domains=$(wc -l < "$LIST_FILE" | tr -d ' ')
    current=0
    
    while IFS= read -r domain || [ -n "$domain" ]; do
        domain=$(echo "$domain" | tr -d '[:space:]')
        if [ -n "$domain" ]; then
            current=$((current + 1))
            domain_output="${OUTPUT%.*}_${domain}.txt"
            echo "[$current/$total_domains] Processing: $domain"
            detect_wildcard "$domain" "$RESOLVERS"
            bruteforce_domain "$domain" "$WORDLIST" "$THREADS" "$RESOLVERS" "$domain_output"
            echo ""
        fi
    done < "$LIST_FILE"
fi

echo "[+] Bruteforce completed. Results saved to: $OUTPUT"
