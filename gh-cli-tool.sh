function gh-run-info() {
  local ids=("$@")
  if [ ${#ids[@]} -eq 0 ]; then
    ids=( $(gh run list --json databaseId -q '.[].databaseId') )
  fi
  for id in "${ids[@]}"; do
    echo "Details for run ID: $id"
    gh run view $id --json workflowName
    echo "------------------------------"
  done
}

function gh-del-workflow-name() {
  contains_string="$1"
  runs_to_delete=( $(gh run list --json databaseId,workflowName -q ".[] | select(.workflowName | contains(\"$contains_string\")) | .databaseId") )
  if [ ${#runs_to_delete[@]} -eq 0 ]; then
    echo "No runs found matching: $contains_string"
    return 0
  fi
  gh-run-info "${runs_to_delete[@]}"
  echo "Are you sure you want to delete these ${#runs_to_delete[@]} runs? (y/n)"
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    for id in "${runs_to_delete[@]}"; do
      echo "Deleting run ID: $id"
      gh run delete "$id"
    done
    echo "Deletion complete."
  else
    echo "Aborted. No runs deleted."
  fi
}