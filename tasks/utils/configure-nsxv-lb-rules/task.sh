#!/bin/bash
set -eux

# script expects to have access to a directory/filename called `nsxv-pool-data/pool_config.yml`
# containing the following parameters:
#
# application-name: appname
# application-domain: appname.domain.com
# application-port-number: 8443
# pool-ips: 10.10.10.1,10.10.10.2
# pool-name-prefix: pks-clustername
#
main() {

  pool_config_file=nsxv-pool-data/pool_config.yml

  APPLICATION_NAME=$(getYamlPropertyValue "application-name" "$pool_config_file")
  APPLICATION_DOMAIN=$(getYamlPropertyValue "application-domain" "$pool_config_file")
  APPLICATION_PORT_NUMBER=$(getYamlPropertyValue "application-port-number" "$pool_config_file")
  POOL_IPS=$(getYamlPropertyValue "pool-ips" "$pool_config_file")
  POOL_NAME_PREFIX=$(getYamlPropertyValue "pool-name-prefix" "$pool_config_file")

  # POOL_IPS parsed example =( 192.168.28.101 192.168.28.102 192.168.28.103 )

  # generated params
  # Vsphere Settings
  POOL_NAME=${POOL_NAME_PREFIX}-${APPLICATION_NAME}

  cat << EOF > nsx.ini
[nsxv]
nsx_manager = $NSX_EDGE_GEN_NSX_MANAGER_ADDRESS
nsx_username = $NSX_EDGE_GEN_NSX_MANAGER_ADMIN_USER
nsx_password = $NSX_EDGE_GEN_NSX_MANAGER_ADMIN_PASSWD
[vcenter]
vcenter = $VCENTER_HOST
vcenter_user = $VCENTER_USR
vcenter_passwd = $VCENTER_PWD
[defaults]
transport_zone = $NSX_EDGE_GEN_NSX_MANAGER_TRANSPORT_ZONE
datacenter_name = $VCENTER_DATA_CENTER
edge_datastore =  $NSX_EDGE_GEN_EDGE_DATASTORE
edge_cluster = $NSX_EDGE_GEN_EDGE_CLUSTER
EOF

  cat << EOF > app_rule
acl host_${APPLICATION_NAME} hdr_dom(host) -i ${APPLICATION_DOMAIN}
use_backend ${POOL_NAME} if host_${APPLICATION_NAME}
EOF

  # create lb pool
  pynsxvg lb add_pool -n $NSX_EDGE_GEN_NAME \
    --pool_name ${POOL_NAME} \
    --algorithm round-robin \
    --monitor default_tcp_monitor
  # add members to pool
  for ip in ${POOL_IPS[@]}
  do
    pynsxvg lb add_member \
      -n $NSX_EDGE_GEN_NAME \
      --pool_name $POOL_NAME \
      --member_name node-${ip//./_} \
      --member $ip \
      --port ${APPLICATION_PORT_NUMBER} \
      --monitor_port ${APPLICATION_PORT_NUMBER} \
      --weight 1
  done

  pynsxvg lb add_rule \
    -n $NSX_EDGE_GEN_NAME \
    -rn "route-${APPLICATION_NAME}" \
    -rs "$(cat app_rule)"

  #TODO: modify pynsxv to allow to add a app rule to an existing virtual server
  # pynsxv_local lb modify_vip \
  #  -n $NSX_EDGE_GEN_NAME \
  #  --vip_name pks-$cluster \
  #  --rule_name route-$APP"

}

pynsxvg () {
   pynsxv/pynsxv/cli.py "$@"
}

getYamlPropertyValue() {
  propertyName="${1}"
  yamlFile="${2}"
  grep "$propertyName" "$yamlFile" | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " "
}

main
