#!/bin/bash

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d DOMAIN      Single domain to process"
    echo "  -l FILE        File containing list of domains"
    echo "  -level LEVEL   Subdomain depth level (2, 3, 4, etc)"
    echo "  -o FILE        Output file to save results"
    echo "  -h             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d dev.api.example.com -level 2"
    echo "  $0 -l domains.txt -level 3 -o results.txt"
    exit 1
}

extract_by_level() {
    local domain="$1"
    local level="$2"
    
    domain=$(echo "$domain" | sed 's|https\?://||' | sed 's|/.*||')
    
    echo "$domain" | grep -oP "(\.[\w-]+){$level}\$" | sed 's/^\.//'
}

DOMAIN=""
LIST_FILE=""
LEVEL=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d) DOMAIN="$2"; shift 2 ;;
        -l) LIST_FILE="$2"; shift 2 ;;
        -level) LEVEL="$2"; shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -h) usage ;;
        *) usage ;;
    esac
done

if [ -z "$LEVEL" ]; then
    usage
fi

if [ "$LEVEL" -lt 2 ]; then
    echo "Error: Level must be at least 2"
    exit 1
fi

if [ -n "$OUTPUT" ]; then
    if [ -n "$DOMAIN" ]; then
        extract_by_level "$DOMAIN" "$LEVEL" | sort -u > "$OUTPUT"
    elif [ -n "$LIST_FILE" ]; then
        while IFS= read -r domain; do
            [ -n "$domain" ] && extract_by_level "$domain" "$LEVEL"
        done < "$LIST_FILE" | sort -u > "$OUTPUT"
    fi
else
    if [ -n "$DOMAIN" ]; then
        extract_by_level "$DOMAIN" "$LEVEL" | sort -u
    elif [ -n "$LIST_FILE" ]; then
        while IFS= read -r domain; do
            [ -n "$domain" ] && extract_by_level "$domain" "$LEVEL"
        done < "$LIST_FILE" | sort -u
    fi
fi
