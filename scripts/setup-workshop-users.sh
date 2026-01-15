#!/bin/bash
# =============================================================================
# Workshop User Setup Script
# =============================================================================
# Creates 25 users (user-01 to user-25) with password "openshift"
# Users will create their own projects during the workshop.
#
# Prerequisites:
#   - Logged in as cluster-admin
#   - htpasswd command available (brew install httpd on Mac)
#
# Usage:
#   ./setup-workshop-users.sh
# =============================================================================

set -e

# Configuration
NUM_USERS=25
PASSWORD="openshift"
HTPASSWD_SECRET_NAME="htpasswd-secret"
HTPASSWD_FILE="/tmp/workshop-users.htpasswd"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Workshop User Setup Script${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check if logged in as cluster-admin
echo -e "${YELLOW}Checking cluster-admin access...${NC}"
if ! oc auth can-i create oauth -A &>/dev/null; then
    echo -e "${RED}ERROR: You must be logged in as cluster-admin${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cluster-admin access confirmed${NC}"

# Check if htpasswd is available
if ! command -v htpasswd &>/dev/null; then
    echo -e "${RED}ERROR: htpasswd command not found${NC}"
    echo -e "${YELLOW}Install with: brew install httpd (Mac) or yum install httpd-tools (Linux)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ htpasswd command available${NC}"

# =============================================================================
# Step 1: Create htpasswd file with all users
# =============================================================================
echo ""
echo -e "${BLUE}Step 1: Creating htpasswd file with ${NUM_USERS} users...${NC}"

# Remove existing file if present
rm -f "$HTPASSWD_FILE"

# Create users
for i in $(seq -w 1 $NUM_USERS); do
    USERNAME="user-${i}"
    if [ "$i" == "01" ]; then
        # First user - create new file
        htpasswd -cbB "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    else
        # Subsequent users - append to file
        htpasswd -bB "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    fi
    echo -e "  Created: ${GREEN}${USERNAME}${NC}"
done

echo -e "${GREEN}✓ Created htpasswd file with ${NUM_USERS} users${NC}"

# =============================================================================
# Step 2: Create/Update the htpasswd secret in openshift-config
# =============================================================================
echo ""
echo -e "${BLUE}Step 2: Creating htpasswd secret in openshift-config...${NC}"

# Check if secret exists
if oc get secret "$HTPASSWD_SECRET_NAME" -n openshift-config &>/dev/null; then
    echo -e "${YELLOW}Secret exists, updating...${NC}"
    oc delete secret "$HTPASSWD_SECRET_NAME" -n openshift-config
fi

oc create secret generic "$HTPASSWD_SECRET_NAME" \
    --from-file=htpasswd="$HTPASSWD_FILE" \
    -n openshift-config

echo -e "${GREEN}✓ htpasswd secret created${NC}"

# =============================================================================
# Step 3: Configure OAuth to use htpasswd
# =============================================================================
echo ""
echo -e "${BLUE}Step 3: Configuring OAuth to use htpasswd...${NC}"

# Check if htpasswd identity provider already exists
EXISTING_IDP=$(oc get oauth cluster -o jsonpath='{.spec.identityProviders[?(@.name=="workshop-users")].name}' 2>/dev/null || echo "")

if [ -z "$EXISTING_IDP" ]; then
    echo -e "${YELLOW}Adding htpasswd identity provider...${NC}"
    
    # Patch OAuth to add htpasswd provider
    oc patch oauth cluster --type=json -p='[
      {
        "op": "add",
        "path": "/spec/identityProviders/-",
        "value": {
          "name": "workshop-users",
          "mappingMethod": "claim",
          "type": "HTPasswd",
          "htpasswd": {
            "fileData": {
              "name": "'"$HTPASSWD_SECRET_NAME"'"
            }
          }
        }
      }
    ]' 2>/dev/null || {
        # If identityProviders doesn't exist, create it
        oc patch oauth cluster --type=merge -p='{
          "spec": {
            "identityProviders": [
              {
                "name": "workshop-users",
                "mappingMethod": "claim",
                "type": "HTPasswd",
                "htpasswd": {
                  "fileData": {
                    "name": "'"$HTPASSWD_SECRET_NAME"'"
                  }
                }
              }
            ]
          }
        }'
    }
else
    echo -e "${YELLOW}htpasswd identity provider 'workshop-users' already exists${NC}"
fi

echo -e "${GREEN}✓ OAuth configured${NC}"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "Created ${GREEN}${NUM_USERS}${NC} users:"
echo ""
printf "  %-12s %s\n" "Username" "Password"
printf "  %-12s %s\n" "--------" "--------"
for i in $(seq -w 1 $NUM_USERS); do
    printf "  ${GREEN}%-12s${NC} %s\n" "user-${i}" "${PASSWORD}"
done
echo ""
echo -e "${YELLOW}Note: It may take 1-2 minutes for OAuth changes to take effect.${NC}"
echo -e "${YELLOW}Users should select 'workshop-users' when logging in.${NC}"
echo ""

# Cleanup
rm -f "$HTPASSWD_FILE"

echo -e "${GREEN}Done!${NC}"
