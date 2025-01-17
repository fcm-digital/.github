
if [[ -f $ARGO_WORKFLOW_FILE ]]; then
    argo submit $ARGO_WORKFLOW_FILE --watch
else
    echo "File $ARGO_WORKFLOW_FILE not found"
    exit 1
fi