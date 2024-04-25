import base64
import pulumi
from pulumi_kubernetes import helm, Provider
import pulumi_kubernetes as k8s
from pulumi_kubernetes.apiextensions.CustomResource import CustomResource
from ...lib.helm_chart_versions import get_latest_helm_chart_version
import logging
from kubernetes import config as kube_config, dynamic
from kubernetes import client as k8s_client
from kubernetes.dynamic.exceptions import ResourceNotFoundError
from kubernetes.client import api_client

def load_ca_cert():
    # this is probably the wrong way to do this, but <shrug>
    kube_config.load_kube_config()
    cluster_issuer_object = k8s_client.CustomObjectsApi().get_cluster_custom_object(group="cert-manager.io",version="v1",plural="clusterissuers",name="enterprise-ca")
    cluster_issuer_ca_secret_name = cluster_issuer_object["spec"]["ca"]["secretName"]
    pulumi.log.info("Loading CA from {}".format(cluster_issuer_ca_secret_name))
    ca_secret = k8s_client.CoreV1Api().read_namespaced_secret(namespace="cert-manager",name=cluster_issuer_ca_secret_name)
    ca_cert = ca_secret.data["tls.crt"]

    decoded_cert = base64.b64decode(ca_cert).decode("utf-8")

    # with the cert, format for our JSON/YAML
    lines = decoded_cert.split('\n')
    encoded_cert = ''
    for line in lines:
        encoded_cert = encoded_cert + '  ' + line + '\n'

    logging.info("Encoded cert\n" + encoded_cert)
    return encoded_cert
    
    



def deploy_argocd(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str,openunison_cluster_management_release):
    logging.info("in deploy_argocd")
    config = pulumi.Config()
    # Create a Namespace
    argocd_namespace = k8s.core.v1.Namespace("argocd_namespace",
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="argocd"
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

    # create the support objects needed for short lived tokens to remote clusters
    argocd_support_manifest_url = 'src/yaml/argocd-helm-support.yaml'
    k8s.yaml.ConfigFile("argocd-support", file=argocd_support_manifest_url,opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            retain_on_delete=False,
            delete_before_replace=True,
            custom_timeouts=pulumi.CustomTimeouts(
                create="10m",
                update="10m",
                delete="10m"
            )
        ))
    
    # load our CA cert
    ca_cert = load_ca_cert()

    # get the domain suffix and cluster_issuer
    domain_suffix = config.require('openunison.cp.dns_suffix')

    helm_values = {
                "configs": {
                    "cm": {
                    "url": "https://argocd." + domain_suffix,
                    "oidc.config": "name: OpenUnison\nissuer: https://k8sou." + domain_suffix + "/auth/idp/k8sIdp\nclientID: argocd\nrootCA: |\n" + ca_cert + "requestedIDTokenClaims:\n  groups:\n    essential: True\nrequestedScopes:\n  - openid\n  - profile\n  - email"
                    },
                    "params": {
                    "server.insecure": True
                    },
                    "rbac": {
                    "policy.csv": "g, \"k8s-cluster-k8s-administrators-internal\", role:admin"
                    }
                },
                "dex": {
                    "enabled": False
                },
                "server": {
                    "ingress": {
                    "enabled": True,
                    "annotations": {
                        "cert-manager.io/cluster-issuer": "enterprise-ca"
                    },
                    "ingressClassName": "nginx",
                    "hostname": "argocd." + domain_suffix,
                    "tls": True
                    },
                    "ingressGrpc": {
                    "enabled": True,
                    "annotations": {
                        "cert-manager.io/cluster-issuer": "enterprise-ca"
                    },
                    "ingressClassName": "nginx",
                    "hostname": "argocd-grpc." + domain_suffix,
                    "tls": True
                    }
                },
                "controller": {
                    "volumes": [
                    {
                        "name": "custom-tools",
                        "emptyDir": {
                        }
                    },
                    {
                        "name": "remote-tokens",
                        "configMap": {
                        "name": "argocd-remote-tokens"
                        }
                    }
                    ],
                    "volumeMounts": [
                    {
                        "mountPath": "/custom-tools",
                        "name": "custom-tools"
                    }
                    ],
                    "initContainers": [
                    {
                        "name": "downloadtools",
                        "image": "alpine",
                        "command": [
                        "sh",
                        "-c"
                        ],
                        "args": [
                        "wget -O /custom-tools/curl https://github.com/moparisthebest/static-curl/releases/download/v8.7.1/curl-amd64 && chmod +x /custom-tools/curl && cp /remote-tokens/remote-token.sh /custom-tools && chmod +x /custom-tools/remote-token.sh"
                        ],
                        "volumeMounts": [
                        {
                            "mountPath": "/custom-tools",
                            "name": "custom-tools"
                        },
                        {
                            "mountPath": "/remote-tokens",
                            "name": "remote-tokens"
                        }
                        ]
                    }
                    ]
                }
                }


    # Fetch the latest version from the helm chart index
    chart_name = "argo-cd"
    chart_index_path = "index.yaml"
    chart_url = "https://argoproj.github.io/argo-helm"
    index_url = f"{chart_url}/{chart_index_path}"
    chart_version = get_latest_helm_chart_version(index_url, chart_name)

    

    release = k8s.helm.v3.Release(
        'argocd',
        k8s.helm.v3.ReleaseArgs(
            chart='argo-cd',
            version=chart_version,
            namespace='argocd',
            skip_await=False,
            repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                repo=chart_url
            ),
            values=helm_values,
        ),
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    

    

    
    