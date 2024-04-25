import pulumi
from pulumi_kubernetes import helm, Provider
import pulumi_kubernetes as k8s
from pulumi_kubernetes.apiextensions.CustomResource import CustomResource
from ...lib.helm_chart_versions import get_latest_helm_chart_version
import logging
import base64

def deploy_openunison_idp(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str, orchestra_cluster_management_release):
    logging.info("in openunison-idp")
    
    config = pulumi.Config()
    gitlab_token = config.require_secret('gitlab.root.token')
    dns_suffix = config.require('openunison.cp.dns_suffix')
    

    # create the Secret for storing the gitlab token
    gitlab_token_secret = k8s.core.v1.Secret(
    "gitlab-target",
    metadata= k8s.meta.v1.ObjectMetaArgs(
        name="gitlab-target",
        namespace="openunison"
    ),
    data={
        "gitlab.root.token":   gitlab_token.apply(lambda token : base64.b64encode(token.encode('utf-8')).decode('utf-8') )  ,
    },
    opts=pulumi.ResourceOptions(
        provider = k8s_provider,
        retain_on_delete=False,
        delete_before_replace=True,
        custom_timeouts=pulumi.CustomTimeouts(
            create="10m",
            update="10m",
            delete="10m"
        )
    )
    )

    helm_values = {
        "gitlab_url": "https://gitlab." + dns_suffix,
        "argocd_url": "https://argocd." + dns_suffix,
        "vault_url": "https://vault." + dns_suffix,
    }

    chart_name = "kube-enterprise-guide-openunison-idp"
    
    openunison_idp_release = k8s.helm.v3.Release(
        'openunison-idp',
        k8s.helm.v3.ReleaseArgs(
            chart='src/helm/kube-enterprise-guide-openunison-idp',
            
            namespace='openunison',
            skip_await=False,
            
            values=helm_values,
        ),
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[gitlab_token_secret,orchestra_cluster_management_release],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )