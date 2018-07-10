function setStemcellAdhocUpgradePipeline() {
  foundation="${1}"
  foundation_name="${2}"
  mainConfigFile="${3}"

  set +e
  createStemcellPipeline=$(grep "BoM_stemcell_version" $foundation | grep "^[^#;]")
  pcfPipelinesSource=$(grep "pcf-pipelines-source" $mainConfigFile | grep "^[^#;]" | cut -d ":" -f 2 | tr -d " ")
  set -e
  if [ -z "${createStemcellPipeline}" ]; then
      echo "No stemcell upgrade config for [$foundation_name], skipping it."
  else
    stemcell_version=$(grep "BoM_stemcell_version" $foundation | cut -d ":" -f 2 | tr -d " ")
    echo "Setting Stemcell adhoc upgrade pipeline for foundation [$foundation_name], version [$stemcell_version]"

    pipelineFileName="stemcell-adhoc-upgrade.yml"
    [ "${pcfPipelinesSource,,}" == "pivnet" ] && pipelineFileName="stemcell-adhoc-upgrade-pivnet.yml";

    ./fly -t $foundation_name set-pipeline -p "$foundation_name-Upgrade-Stemcell-Adhoc" -c "./pipelines/utils/$pipelineFileName" -l ./common/credentials.yml -l "$foundation" -v "stemcell_version=${stemcell_version}" -n
  fi
}
