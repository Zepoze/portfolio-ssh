#!/bin/bash

HOST="127.0.0.1"
PORT="2222"
USER="test"
ATTEMPTS=10
DELAY=0.2
TIMEOUT=3

echo "Starting SSH rate limit test..."

for i in $(seq 1 $ATTEMPTS); do
  (
    echo "Attempt $i"

    timeout $TIMEOUT ssh \
      -o ConnectTimeout=2 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -p $PORT \
      $USER@$HOST exit 2>/dev/null

  ) &

  sleep $DELAY
done

wait

echo "Test finished."
