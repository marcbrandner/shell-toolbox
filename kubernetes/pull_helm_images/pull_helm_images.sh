#!/bin/bash

# =============================================================================
#   Help text
# =============================================================================

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
cat << 'EOF'
   Description
       Gets all images from a typical values.yaml file of a Helm Chart and,
       pulls these images and exports them into TGZ archives.
   Arguments
       $1: Path to values.yaml of Helm Chart
       $2: Target directory to save pulled images
EOF
exit 0
fi

SCRIPT_FILE="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"
source $SCRIPT_DIR/common.sh

DEFAULT_VALUES_PATH="values.yaml"
VALUES_PATH=${1:-$DEFAULT_VALUES_PATH}
VALUES_PATH=${VALUES_PATH%%+(/)} # removes trailing slash

DEFAULT_TARGET_PATH="/tmp"
TARGET_PATH=${2:-$DEFAULT_TARGET_PATH}
TARGET_PATH=${TARGET_PATH%%+(/)} # removes trailing slash

# =============================================================================
#   Test if values.yaml file exists and is readable
# =============================================================================

if [ ! -f "$VALUES_PATH" ]; then
    echo "ERROR: '$VALUES_PATH' does not exist. Aborting."
    exit 1
fi

if [ ! -r "$VALUES_PATH" ]; then
    echo "ERROR: '$VALUES_PATH' is not readable. Check file permissions. Aborting."
    exit 1
fi

# =============================================================================
#   Test if target directory exists and is readable
# =============================================================================

if [ ! -d "$TARGET_PATH" ]; then
    echo "ERROR: '$TARGET_PATH' does not exist. Aborting."
    exit 1
fi

if [ ! -r "$TARGET_PATH" ]; then
    echo "ERROR: '$TARGET_PATH' is not readable. Check file permissions. Aborting."
    exit 1
fi

# =============================================================================
#   Test availability of required commands
# =============================================================================

check_command "yq" "4.0.0"
check_command "docker" "19.03"

# =============================================================================
#   Parse values.yaml and build list of images
# =============================================================================

VALID_OBJECTS=$(yq e '[.. | select(has("repository"))]' $VALUES_PATH)

REGS=$(echo "$VALID_OBJECTS" | yq e '.[].registry' -)
REPOS=$(echo "$VALID_OBJECTS" | yq e '.[].repository' -)
TAGS=$(echo "$VALID_OBJECTS" | yq e '.[].tag' -)
GLOBAL_REG="$(yq e '.global.imageRegistry' $VALUES_PATH)/"
IMAGE_COUNT=$(echo "$REPOS" | wc -l )
FINAL_IMAGE_LIST=""

# =============================================================================
#   Heuristic for type A:
#   https://raw.githubusercontent.com/bitnami/charts/master/bitnami/postgresql/values.yaml
# =============================================================================

for (( REPO_NO=1; REPO_NO<=$IMAGE_COUNT; REPO_NO++ )); do

    REG="$(echo "$REGS" | sed "${REPO_NO}q;d")"
    REPO=$(echo "$REPOS" | sed "${REPO_NO}q;d")
    TAG=$(echo "$TAGS" | sed "${REPO_NO}q;d")

    if [ -z "$REPO" ]; then 
        # If no repository is set, we have no chance to assemble a valid image name with this heuristic
        continue
    fi

    if [ "$REG" == "null" ]; then
        if [ ! -z "$GLOBAL_REGISTRY" ]; then
            FULL_IMAGE_NAME=${GLOBAL_REGISTRY}${REPO}:${TAG}
        else
            FULL_IMAGE_NAME=${REPO}:${TAG}
        fi
    else
        FULL_IMAGE_NAME=${REG}/${REPO}:${TAG}
    fi

    FINAL_IMAGE_LIST=$(echo -e "$FINAL_IMAGE_LIST\n$FULL_IMAGE_NAME" | sed -e 's/:null//g')

done

# =============================================================================
#   Heuristic for type B: 
#   https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/main/helm-charts/helm3/strimzi-kafka-operator/values.yaml
# =============================================================================

DEFAULT_REG="$(yq e '.defaultImageRegistry' $VALUES_PATH)/"
DEFAULT_REPO="$(yq e '.defaultImageRepository' $VALUES_PATH)/"
DEFAULT_TAG=":$(yq e '.defaultImageTag' $VALUES_PATH)"
NAMES=$(echo "$VALID_OBJECTS" | yq e '.[].name' -)
NAME_COUNT=$(echo "$NAMES" | wc -l )

if [ ! -z "$DEFAULT_REPO" ] || [ ! "$DEFAULT_REPO" == "null" ]; then

    for (( NAME_NO=1; NAME_NO<=$NAME_COUNT; NAME_NO++ )); do

        NAME=$(echo "$NAMES" | sed "${NAME_NO}q;d")
        FULL_IMAGE_NAME=${DEFAULT_REG}${DEFAULT_REPO}${NAME}${DEFAULT_TAG}
        FINAL_IMAGE_LIST=$(echo -e "$FINAL_IMAGE_LIST\n$FULL_IMAGE_NAME" | sed -e 's/:null//g')

    done

fi

# =============================================================================
#   Remove empty lines from result, deduplicate entries, remove malfored entries
# =============================================================================

FINAL_IMAGE_LIST=$(echo "$FINAL_IMAGE_LIST" | awk 'NF' | sort -u | grep -v 'null/null')

# =============================================================================
#   Print final list of images
# =============================================================================

echo ""
echo "$IMAGE_COUNT images to pull:"
echo "$FINAL_IMAGE_LIST" | sed 's/^/- /'

# =============================================================================
#   Pull images
# =============================================================================

CURRENT_COUNT=1
TOTAL_COUNT=$(echo "$FINAL_IMAGE_LIST" | wc -l )

for IMAGE in $(echo "$FINAL_IMAGE_LIST"); do

    echo ""
    echo "  -- $CURRENT_COUNT of $TOTAL_COUNT --"
    docker pull $IMAGE
    IMAGE_FILE_NAME="$(echo $IMAGE | sed 's/:/___/g' | sed 's/\//__/g').tgz"
    echo "Saving image '$IMAGE' --> '$IMAGE_FILE_NAME' in directory '$TARGET_PATH'"
    docker save $IMAGE > "$TARGET_PATH/$IMAGE_FILE_NAME"
    ((CURRENT_COUNT=CURRENT_COUNT+1))

done

exit 0