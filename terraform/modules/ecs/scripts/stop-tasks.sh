#!/bin/bash

SERVICES="$(aws ecs list-services --cluster "${CLUSTER}" | grep "${CLUSTER}" || true | sed -e 's/"//g' -e 's/,//')"
for SERVICE in $SERVICES ; do
  # Idle the service that spawns tasks
  aws ecs update-service --cluster "${CLUSTER}" --service "${SERVICE}" --desired-count 0

  # Stop running tasks
  TASKS="$(aws ecs list-tasks --cluster "${CLUSTER}" --service "${SERVICE}" | grep "${CLUSTER}" || true | sed -e 's/"//g' -e 's/,//')"
  for TASK in $TASKS; do
    aws ecs stop-task --task "$TASK"
  done

  # Delete the service after it becomes inactive
  aws ecs wait services-inactive --cluster "${CLUSTER}" --service "${SERVICE}"
  aws ecs delete-service --cluster "${CLUSTER}" --service "${SERVICE}"
done
