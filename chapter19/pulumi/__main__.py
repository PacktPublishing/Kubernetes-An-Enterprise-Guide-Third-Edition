"""A Python Pulumi program"""

import os
import pulumi
import pulumi_kubernetes as k8s

from src.devplatform.cert_manager.deploy import deploy_cert_manager
from src.devplatform.smtp_blackhole.deploy import deploy_smtp_blackhole
from src.devplatform.openunison.deploy import deploy_openunison
from src.devplatform.argocd.deploy import deploy_argocd
from src.devplatform.gitlab.deploy import deploy_gitlab
from src.devplatform.openunison_idp.deploy import deploy_openunison_idp
from src.devplatform.vault.deploy import deploy_vault
from src.devplatform.harbor.deploy import deploy_harbor
from src.devplatform.openunison_sat.deploy import deploy_openunison_sat
from src.devplatform.mysql.deploy import deploy_mysql
import logging

def main():
    config = pulumi.Config()

    kubeconfig = config.require('kube.cp.path')
    kubeconfig_context = config.require('kube.cp.context')

    kubernetes_distribution = "doesntmatter"

    # Initialize the Kubernetes provider
    k8s_provider = k8s.Provider(
        "k8sProvider",
        context=kubeconfig_context,
        kubeconfig=kubeconfig,
        suppress_deprecation_warnings=True,
        suppress_helm_hook_warnings=True,
        enable_server_side_apply=True
    )


    k8s_dev_provider = None    
    if config.get('kube.dev.context'):
        # initialize the dev cluster
        k8s_dev_provider = k8s.Provider(
            "k8sProviderDev",
            context=config.get('kube.dev.context') or 'kubernetes-admin@kubernetes',
            kubeconfig=config.require('kube.dev.path'),
            suppress_deprecation_warnings=True,
            suppress_helm_hook_warnings=True,
            enable_server_side_apply=True
        )

    k8s_prod_provider = None    
    if config.get('kube.prod.context'):
        # initialize the dev cluster
        k8s_prod_provider = k8s.Provider(
            "k8sProviderProd",
            context=config.get('kube.prod.context') or 'kubernetes-admin@kubernetes',
            kubeconfig=config.require('kube.prod.path'),
            suppress_deprecation_warnings=True,
            suppress_helm_hook_warnings=True,
            enable_server_side_apply=True
        )

    # Get the Kubernetes API endpoint IP
    #kubernetes_endpoint_ip = KubernetesApiEndpointIp("k8s-api-ip", k8s_provider)

    # deploy cert-manager
    cert_manager = deploy_cert_manager(
        "devplatform",
        k8s_provider,
        kubernetes_distribution,
        "devplatform",
        "cert-manager",
        ""
    )

    # deploy mysql
    mysql_manifest_url = 'src/yaml/mysql.yaml'
    mysql_release = k8s.yaml.ConfigFile("mysql", file=mysql_manifest_url,opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            retain_on_delete=False,
            delete_before_replace=True,
            depends_on=[cert_manager],
            custom_timeouts=pulumi.CustomTimeouts(
                create="10m",
                update="10m",
                delete="10m"
            )
        ))

    # mariadb_manifest_url = 'https://raw.githubusercontent.com/OpenUnison/kubeconeu/main/src/main/yaml/mariadb_k8s.yaml'
    # k8s.yaml.ConfigFile("mariadb", file=mariadb_manifest_url,opts=pulumi.ResourceOptions(
    #         provider = k8s_provider,
    #         retain_on_delete=False,
    #         delete_before_replace=True,
    #         custom_timeouts=pulumi.CustomTimeouts(
    #             create="10m",
    #             update="10m",
    #             delete="10m"
    #         )
    #     ))

    # deploy SMTP blackhole
    deploy_smtp_blackhole( "devplatform",
        k8s_provider,
        kubernetes_distribution,
        "devplatform",
        "smtp-blackhole")
    
    #deploy "Active Directory"
    apacheds_manifest_url = 'https://raw.githubusercontent.com/PacktPublishing/Kubernetes-An-Enterprise-Guide-Third-Edition/main/chapter6/user-auth/apacheds.yaml'
    apacheds_k8s_yaml = k8s.yaml.ConfigFile("apacheds", file=apacheds_manifest_url,opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            retain_on_delete=False,
            delete_before_replace=True,
            custom_timeouts=pulumi.CustomTimeouts(
                create="10m",
                update="10m",
                delete="10m"
            )
        ))

    gitlab_root_token = config.get_secret(key="gitlab.root.token") or None

    # # Deploy OpenUnison
    [openunison_cluster_management_release,orchestra_release,openunison_login_portal] = deploy_openunison("devplatform",k8s_provider,kubernetes_distribution,"devplatform","openunison",gitlab_root_token != None,cert_manager,mysql_release)

    # Deploy ArgoCD
    deploy_argocd("devplatform",k8s_provider,kubernetes_distribution,"devplatform","argocd",openunison_cluster_management_release,cert_manager)

    # Deploy GitLab
    deploy_gitlab("devplatform",k8s_provider,kubernetes_distribution,"devplatform","gitlab",openunison_cluster_management_release,cert_manager)

    # deploy vault
    deploy_vault("devplatform",k8s_provider,kubernetes_distribution,"devplatform","vault",openunison_cluster_management_release,orchestra_release,cert_manager)
    
    # deploy harbor
    deploy_harbor("devplatform",k8s_provider,kubernetes_distribution,"devplatform","harbor",openunison_cluster_management_release,cert_manager)
    
    # we won't run the customized OpenUnison charts until we have service accounts.  Unfortunately this part can't be automated

    

    if gitlab_root_token:
        logging.info("gitlab secret set")
        deploy_openunison_idp("devplatform",k8s_provider,kubernetes_distribution,"devplatform","openunison",openunison_cluster_management_release,openunison_login_portal,orchestra_release)
    else:
        logging.info("no gitlab token set")

    


    if k8s_dev_provider != None:
        # integrate the dev openunison
        # deploy cert-manager
        dev_cert_manager = deploy_cert_manager(
            "devplatform",
            k8s_dev_provider,
            kubernetes_distribution,
            "devplatform",
            "cert-manager",
            "-dev"
        )

        # deploy MySQL for k3s backend
        deploy_mysql("devplatform",k8s_dev_provider,kubernetes_distribution,"devplatform",dev_cert_manager,"dev")

        # deploy dev openunison
        deploy_openunison_sat("devplatform",k8s_dev_provider,k8s_provider,kubernetes_distribution,"devplatform","openunison","dev",openunison_cluster_management_release,dev_cert_manager)

    if k8s_prod_provider != None:
        # integrate the prod openunison
        # deploy cert-manager
        prod_cert_manager = deploy_cert_manager(
            "devplatform",
            k8s_prod_provider,
            kubernetes_distribution,
            "devplatform",
            "cert-manager",
            "-prod"
        )

        # deploy MySQL for k3s backend
        deploy_mysql("devplatform",k8s_prod_provider,kubernetes_distribution,"devplatform",prod_cert_manager,"prod")

        # deploy prod openunison
        deploy_openunison_sat("devplatform",k8s_prod_provider,k8s_provider,kubernetes_distribution,"devplatform","openunison","prod",openunison_cluster_management_release,prod_cert_manager)

  



main()