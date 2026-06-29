#!/usr/bin/env bash
set -eo pipefail

BASE_URL="https://reon-org.github.io/packager/void"
ARCH="x86_64"

# Clean trailing slashes
BASE_URL="${BASE_URL%/}"

echo "--> Scanning HTTP endpoints for $BASE_URL..."
echo "--------------------------------------------------------"
printf "%-50s %-10s\n" "TARGET FILE PATH" "STATUS"
echo "--------------------------------------------------------"

# Dictionary arrays for standard repository variants
declare -a FILES_TO_CHECK=(
    # Root paths
    "${BASE_URL}/${ARCH}-repodata"
    "${BASE_URL}/${ARCH}-repodata.sig"
    "${BASE_URL}/noarch-repodata"
    # Suffix variants
    "${BASE_URL}/${ARCH}-repodata.xbps"
    # Nested architectures subdirectories (Common on GitHub)
    "${BASE_URL}/${ARCH}/${ARCH}-repodata"
    "${BASE_URL}/${ARCH}/${ARCH}-repodata.sig"
    "${BASE_URL}/${ARCH}/noarch-repodata"
)

# Search for typical 'rind' package variants manually
declare -a PACKAGES_TO_CHECK=(
    "rind"
    "rind-1.0_1"
    "rinit"
)

for file in "${FILES_TO_CHECK[@]}"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L "$file")
    if [ "$STATUS" = "200" ]; then
        printf "%-50s \e[32m%s\e[0m\n" "${file#$BASE_URL/}" "FOUND (200)"
    else
        printf "%-50s \e[31m%s\e[0m\n" "${file#$BASE_URL/}" "MISSING ($STATUS)"
    fi
done

# Check hypothetical package formats directly on the server
for pkg in "${PACKAGES_TO_CHECK[@]}"; do
    for path in "" "${ARCH}/"; do
        BINARY_URL="${BASE_URL}/${path}${pkg}.${ARCH}.xbps"
        SIG_URL="${BASE_URL}/${path}${pkg}.${ARCH}.xbps.sig2"
        
        B_STAT=$(curl -s -o /dev/null -w "%{http_code}" -L "$BINARY_URL")
        if [ "$B_STAT" = "200" ]; then
            printf "%-50s \e[32m%s\e[0m\n" "${BINARY_URL#$BASE_URL/}" "FOUND (200)"
            # Check matching signature
            S_STAT=$(curl -s -o /dev/null -w "%{http_code}" -L "$SIG_URL")
            printf "%-50s %s\n" "${SIG_URL#$BASE_URL/}" "SIG STATUS: $S_STAT"
        fi
    done
done
echo "--------------------------------------------------------"
