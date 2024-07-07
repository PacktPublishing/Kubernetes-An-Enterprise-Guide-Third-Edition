import pulumi
from pulumi_kubernetes import helm, Provider

import pulumi_kubernetes as k8s
from pulumi_kubernetes.apiextensions.CustomResource import CustomResource
from ...lib.helm_chart_versions import get_latest_helm_chart_version
import json
import secrets
import base64
from kubernetes import config, dynamic
from kubernetes import client as k8s_client
from kubernetes.dynamic.exceptions import ResourceNotFoundError
from kubernetes.client import api_client


def deploy_mysql(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, cert_manager,env):
    # Initialize Pulumi configuration
    pconfig = pulumi.Config()

    cluster_issuer_mysql = CustomResource(
        "mysql-ca-issuer-" + env,
        api_version="cert-manager.io/v1",
        kind="ClusterIssuer",
        metadata={
            "name": "mysql-self-signed",
            "namespace": "cert-manager"
        },
        spec={
            "selfSigned": {}
        },
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[cert_manager],
            custom_timeouts=pulumi.CustomTimeouts(
                create="5m",
                update="10m",
                delete="10m"
            )
        )
    )
    
    # generate mysql namespace
    mysql_namespace = k8s.core.v1.Namespace("mysql_" + env,
            metadata= k8s.meta.v1.ObjectMetaArgs(
                name="mysql"
            ),
            opts=pulumi.ResourceOptions(
                provider = k8s_provider,
                retain_on_delete=True,
                custom_timeouts=pulumi.CustomTimeouts(
                    create="10m",
                    update="10m",
                    delete="10m"
                )
            )
        )

    # create the Certificate
    mysql_certificate = CustomResource(
        "mysql-tls-" + env,
        api_version="cert-manager.io/v1",
        kind="Certificate",
        metadata={
            "name": "mysql",
            "namespace": "mysql",
        },
        spec={
            "secretName": "mysql-tls",
            "commonName": "mysql.mysql.svc",
            "isCA": False,
            "privateKey": {
                "algorithm": "RSA",
                "encoding": "PKCS1",
                "size": 2048,
            },
            "usages": ["server auth","client auth"],
            "dnsNames": ["mysql.mysql.svc"],
            "issuerRef": {
                "name": "enterprise-ca",
                "kind": "ClusterIssuer",
                "group": "cert-manager.io",
            },
        },
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[cluster_issuer_mysql],
            custom_timeouts=pulumi.CustomTimeouts(
                create="5m",
                update="10m",
                delete="10m"
            )
        )
    )

    # deploy mysql
    mysql_manifest_url = 'src/yaml/mysql_node.yaml'
    k8s_yaml = k8s.yaml.ConfigFile("mysql-"+env, file=mysql_manifest_url,resource_prefix=env,opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            retain_on_delete=False,
            delete_before_replace=True,
            depends_on=[mysql_certificate],
            
            custom_timeouts=pulumi.CustomTimeouts(
                create="10m",
                update="10m",
                delete="10m"
            )
        ))