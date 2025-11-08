#!/bin/bash


cd /tests
pytest /tests/test_outputs.py -rA

# Write reward based on last command exit code
if [ $? -eq 0 ]; then
  echo 1 > /logs/verifier/reward.txt
else
  echo 0 > /logs/verifier/reward.txt
fi
