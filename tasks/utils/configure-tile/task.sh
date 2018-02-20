#!/bin/bash
set -eu

function generate_cert () (
  set -eu
  local domains="$1"

  local data=$(echo $domains | jq --raw-input -c '{"domains": (. | split(" "))}')

  local response=$(
    om-linux \
      --target "https://${OPSMAN_DOMAIN_OR_IP_ADDRESS}" \
      --client-id "${OPSMAN_CLIENT_ID}" \
      --client-secret "${OPSMAN_CLIENT_SECRET}" \
      --username "$OPSMAN_USERNAME" \
      --password "$OPSMAN_PASSWORD" \
      --skip-ssl-validation \
      curl \
      --silent \
      --path "/api/v0/certificates/generate" \
      -x POST \
      -d $data
    )

  echo "$response"
)

saml_domains=(
  "*.${CERT_DOMAIN}"
  "*.api.${CERT_DOMAIN}"
)

saml_certificates=$(generate_cert "${saml_domains[*]}")
saml_cert_pem=`echo $saml_certificates | jq --raw-output '.certificate'`
saml_key_pem=`echo $saml_certificates | jq --raw-output '.key'`


# NETWORK
echo "$TILE_NETWORK" > ./network_object.yml
# convert network YML into JSON
python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < ./network_object.yml > ./network_object.json
export network_object=$(cat network_object.json)

# RESOURCES
echo "$TILE_RESOURCES" > ./resources_object.yml
# convert resources YML into JSON
python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < ./resources_object.yml > ./resources_object.json
export resources_object=$(cat resources_object.json)

# PROPERTIES
echo "$TILE_PROPERTIES" > ./properties_object.yml
# convert properties YML into JSON
python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < ./properties_object.yml > ./properties_object.json

# appends generated certificate to properties object
cat properties_object.json | jq \
  --arg saml_cert_pem "$saml_cert_pem" \
  --arg saml_key_pem "$saml_key_pem" \
  '
  .
  +
  {
  ".pivotal-container-service.pks_tls": {
    "value": {
      "cert_pem": $saml_cert_pem,
      "private_key_pem": $saml_key_pem
    }
  }}' > final_properties_object.json

export final_properties_object=$(cat final_properties_object.json)

om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --client-id "${OPSMAN_CLIENT_ID}" \
  --client-secret "${OPSMAN_CLIENT_SECRET}" \
  --username "$OPSMAN_USERNAME" \
  --password "$OPSMAN_PASSWORD" \
  --skip-ssl-validation \
  configure-product \
  --product-name "$TILE_PRODUCT_NAME" \
  --product-network "$network_object"

  om-linux \
    --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
    --client-id "${OPSMAN_CLIENT_ID}" \
    --client-secret "${OPSMAN_CLIENT_SECRET}" \
    --username "$OPSMAN_USERNAME" \
    --password "$OPSMAN_PASSWORD" \
    --skip-ssl-validation \
    configure-product \
    --product-name "$TILE_PRODUCT_NAME" \
    --product-resources "$resources_object" \
    --product-properties "$final_properties_object"
