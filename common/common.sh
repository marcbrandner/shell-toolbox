# =============================================================================
#   Compare version numbers
# =============================================================================

function check_version {
    echo "$1" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }';
}

# =============================================================================
#   Test availability of required commands
# =============================================================================

function check_command {
    COMMAND=$1
    REQ_VERSION=$2
    COMMAND_VERSION=$($COMMAND --version | head -n 1)
    RC=$?
    if [ $RC -eq 127 ]; then
        echo "ERROR: Command '$COMMAND' not found. Aborting."
        exit 1
    elif [ $RC -eq 0 ]; then
        echo "Found: $COMMAND_VERSION"
    else
        echo "ERROR: Unknown problem executing '$COMMAND'. Exit code: $RC. Aborting."
        exit 1
    fi
    VERSION_NUMBER=$(echo $COMMAND_VERSION | awk '{print $3}' | tr -d ',' | tr -d 'v')
    if [ ! -z ${REQ_VERSION+x} ]; then
        if [ ! $(check_version $VERSION_NUMBER) -ge $(check_version $REQ_VERSION) ]; then
            echo "ERROR: Insufficient version for $COMMAND. Present: $VERSION_NUMBER; Required: $REQ_VERSION or higher. Aborting."
            exit 1
        fi
    fi
}