#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
CHANNEL="${1:?missing channel}"

require_env AWS_REGION

INSTANCE_ID="$(
aws ec2 describe-instances \
  --filters \
    "Name=tag:Name,Values=portfolio-ssh-ec2-$CHANNEL" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --region "$AWS_REGION" \
  --output text
)"

if [[ -z "$INSTANCE_ID" ]]; then
  die "No instance found to deployment"
fi

COMMAND_ID="$(
aws ssm send-command \
    --region "$AWS_REGION" \
    --document-name "AWS-RunShellScript" \
    --comment "Deploy ssh-portfolio '$CHANNEL'" \
    --instance-id "$INSTANCE_ID" \
    --parameters commands='["sudo /opt/portfolio/deploy.sh"]' \
    --query "Command.CommandId" --output text
)"


info "SSM CommandId: $COMMAND_ID"

while true; do
  STATUS=$(aws ssm get-command-invocation \
    --region "$AWS_REGION" \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query "Status" \
    --output text)

  info "SSM status: $STATUS"

  case "$STATUS" in
    Success)
      break
      ;;
    Failed|TimedOut|Cancelled)
      warn "SSM command failed"
      aws ssm get-command-invocation \
        --region "$AWS_REGION" \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID"
      exit 1
      ;;
  esac

  sleep 5
done
