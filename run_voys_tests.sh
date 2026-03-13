#!/usr/bin/env bash

TOKEN=""
EMAIL=""
RESGATE_URL_ARG=""
VOIPGRID_API_URL_ARG=""
AVAILABILITY_API_URL_ARG=""
RUN_LONG_TESTS="${RUN_LONG_TESTS:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --email)
      EMAIL="$2"
      shift 2
      ;;
    --resgate-url)
      RESGATE_URL_ARG="$2"
      shift 2
      ;;
    --voipgrid-api-url)
      VOIPGRID_API_URL_ARG="$2"
      shift 2
      ;;
    --availability-api-url)
      AVAILABILITY_API_URL_ARG="$2"
      shift 2
      ;;
    --run-long-tests)
      RUN_LONG_TESTS="true"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

VOIPGRID_API_TOKEN="${TOKEN:-$VOIPGRID_API_TOKEN}"
VOIPGRID_EMAIL="${EMAIL:-$VOIPGRID_EMAIL}"
RESGATE_URL="${RESGATE_URL_ARG:-${RESGATE_URL:-wss://resgate.eu-production.holodeck.voys.nl}}"
VOIPGRID_API_URL="${VOIPGRID_API_URL_ARG:-${VOIPGRID_API_URL:-https://partner.voipgrid.nl/api}}"
AVAILABILITY_API_URL="${AVAILABILITY_API_URL_ARG:-${AVAILABILITY_API_URL:-https://api.eu-production.holodeck.voys.nl/user-status}}"

MISSING=()
[[ -z "$VOIPGRID_API_TOKEN" ]] && MISSING+=("VOIPGRID_API_TOKEN (--token)")
[[ -z "$VOIPGRID_EMAIL" ]]     && MISSING+=("VOIPGRID_EMAIL (--email)")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Error: the following required values are missing:"
  for item in "${MISSING[@]}"; do
    echo "  - $item"
  done
  echo ""
  echo "Provide each as a flag or set the corresponding environment variable. Example:"
  echo ""
  echo "  ./run_voys_tests.sh --email <your_email> --token <your_token>"
  exit 1
fi

if [[ "$CI" == "true" ]]; then
  dart pub global activate junitreport
  export PATH="$PATH:$HOME/.pub-cache/bin"

  VOIPGRID_API_TOKEN="$VOIPGRID_API_TOKEN" \
  VOIPGRID_EMAIL="$VOIPGRID_EMAIL" \
  RESGATE_URL="$RESGATE_URL" \
  VOIPGRID_API_URL="$VOIPGRID_API_URL" \
  AVAILABILITY_API_URL="$AVAILABILITY_API_URL" \
  RUN_LONG_TESTS="$RUN_LONG_TESTS" \
    dart test test/voys_tests.dart --reporter json | \
    tojunit | \
    sed 's/&#x1[Bb];\\[[0-9;]*[a-zA-Z]//g; s/&#x1[Bb];//g' > test-results.xml

  exit "${PIPESTATUS[0]}"
else
  VOIPGRID_API_TOKEN="$VOIPGRID_API_TOKEN" \
  VOIPGRID_EMAIL="$VOIPGRID_EMAIL" \
  RESGATE_URL="$RESGATE_URL" \
  VOIPGRID_API_URL="$VOIPGRID_API_URL" \
  AVAILABILITY_API_URL="$AVAILABILITY_API_URL" \
  RUN_LONG_TESTS="$RUN_LONG_TESTS" \
    dart test test/voys_tests.dart
fi
