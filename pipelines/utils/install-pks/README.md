<img src="https://pivotal.gallerycdn.vsassets.io/extensions/pivotal/vscode-concourse/0.1.3/1517353139519/Microsoft.VisualStudio.Services.Icons.Default" alt="Concourse" height="70"/>&nbsp;&nbsp;<img src="https://dtb5pzswcit1e.cloudfront.net/assets/images/product_logos/icon_pivotalcontainerservice@2x.png" alt="PCF Knowledge Depot" height="70"/>

# Install PKS pipeline

This pipeline installs the PKS tile on top of an existing PCF Ops Manager deployment.

<img src="https://raw.githubusercontent.com/lsilvapvt/misc-support-files/master/docs/images/install-pks-tile.png" alt="Concourse" width="100%"/>


The parameters file of this pipeline implements the concept of "externalized tile parameters", where all the available tile configuration options are fed to the pipeline tasks as a YAML object containing the parameter names expected by Ops Manager for the tile.

For example:
```
properties: |

  ######## Configuration for Plan 1
  .properties.plan1_selector:
    value: "Plan Active"
  .properties.plan1_selector.active.name:
    value: "Small plan"  # the name that appears for end users to choose
```

This approach allows for the `configure-tile` task of this pipeline to be generic and *tile-agnostic*, by delegating the tile configuration options to the content of the main three parameters `networks`, `properties` and `resources`.

---

## How to use this pipeline

1) Update `pks_params.yml` by following the instructions in the file.  
   The order of tile parameters in that file follows the same order as parameters are presented in Ops Manager and in the tile documentation ([vSphere](https://docs.pivotal.io/runtimes/pks/1-0/installing-pks-vsphere.html) or [GCP](https://docs.pivotal.io/runtimes/pks/1-0/installing-pks-gcp.html)).  

    If you use `Vault` or `CredHub` for credentials management, you can use the provided script [`pks_vault_params.sh`](pks_vault_params.sh) to automatically create the pipeline secrets in those systems.

2) Create the pipeline in Concourse:  

   `fly -t <target> set-pipeline -p install-pks -c pipeline.yml -l pks_params.yml`

3) Un-pause and run pipeline `install-pks`


*Note: for this first MVP, the pipeline only generates self-signed PKS certificate at all times. Work is in progress to make it configurable through an option in the params file. Stay tuned for updates.*

---


## Post PKS tile deploy steps

### PKS CLI client ID creation

Once the PKS tile is successfully deployed, a PKS CLI client ID is required to be created ([see documentation](https://docs.pivotal.io/runtimes/pks/1-0/manage-users.html#uaa-scopes)).

For that step, the pipeline also provides a job to automate it: `create-pks-cli-user`. Simply manually run that pipeline job to get the PKS CLI client ID created.

*Note:* in order for that task to work, the configured PKS API endpoint needs to be reachable from a DNS/network standpoint (see docs for [vSphere](https://docs.pivotal.io/runtimes/pks/1-0/installing-pks-vsphere.html#loadbalancer-pks-api) and [GCP](https://docs.pivotal.io/runtimes/pks/1-0/installing-pks-gcp.html#loadbalancer-pks-api])).

### Using PKS

Once the PKS CLI client ID created, proceed with [creating K8s clusters with PKS](https://docs.pivotal.io/runtimes/pks/1-0/create-cluster.html) and [deploying K8s workloads with `kubectl`](https://docs.pivotal.io/runtimes/pks/1-0/deploy-workloads.html).
