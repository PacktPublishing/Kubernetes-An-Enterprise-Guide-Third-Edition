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
    try:
        k8s_cp_api = kube_config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
        k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
        k8s_cp_custom_api = k8s_client.CustomObjectsApi(k8s_cp_api)

        cluster_issuer_object = k8s_cp_custom_api.get_cluster_custom_object(group="cert-manager.io",version="v1",plural="clusterissuers",name="enterprise-ca")
        cluster_issuer_ca_secret_name = cluster_issuer_object["spec"]["ca"]["secretName"]
        pulumi.log.info("Loading CA from {}".format(cluster_issuer_ca_secret_name))
        ca_secret = k8s_cp_core_api.read_namespaced_secret(namespace="cert-manager",name=cluster_issuer_ca_secret_name)
        ca_cert = ca_secret.data["tls.crt"]

        decoded_cert = base64.b64decode(ca_cert).decode("utf-8")

        # with the cert, format for our JSON/YAML
        lines = decoded_cert.split('\n')
        encoded_cert = ''
        for line in lines:
            encoded_cert = encoded_cert + '  ' + line + '\n'

        logging.info("Encoded cert\n" + encoded_cert)
        return encoded_cert
    except:
        return pulumi.Config().get("certmanager.clusterissuer.cert") or "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURFVENDQWZtZ0F3SUJBZ0lVYmtiS2ZRN29ldXJuVHpyeWdIL0dDS0kzNkUwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05aVzUwWlhKd2NtbHpaUzFqWVRBZUZ3MHlNakV4TURjeE5EUTFNakphRncwegpNakV4TURReE5EUTFNakphTUJneEZqQVVCZ05WQkFNTURXVnVkR1Z5Y0hKcGMyVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNucVZ3eVFvMjJyRzZuVVpjU2UvR21WZnI5MEt6Z3V4MDkKNDY4cFNTUWRwRHE5UlRRVU92ZkFUUEJXODF3QlJmUDEvcnlFaHNocnVBS2E5LzVoKzVCL3g4bmN4VFhwbThCNwp2RDdldHY4V3VyeUtQc0lMdWlkT0QwR1FTRVRvNzdBWE03RmZpUk9yMDFqN3c2UVB3dVB2QkpTcDNpa2lDL0RjCnZFNjZsdklFWE43ZFNnRGRkdnV2R1FORFdPWWxHWmhmNUZIVy81ZHJQSHVPOXp1eVVHK01NaTFpUCtSQk1QUmcKSWU2djhCcE9ncnNnZHRtWExhNFZNc1BNKzBYZkQwSDhjU2YvMkg2V1M0LzdEOEF1bG5QSW9LY1krRkxKUEFtMwpJVFI3L2w2UTBJUXVNU3c2QkxLYWZCRm5CVmNUUVNIN3lKZEFKNWdINFZZRHIyamtVWkwzQWdNQkFBR2pVekJSCk1CMEdBMVVkRGdRV0JCU2Y5RDVGS3dISUY3eFdxRi80OG4rci9SVFEzakFmQmdOVkhTTUVHREFXZ0JTZjlENUYKS3dISUY3eFdxRi80OG4rci9SVFEzakFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQQpBNElCQVFCN1BsMjkrclJ2eHArVHhLT3RCZGRLeEhhRTJVRUxuYmlkaFUvMTZRbW51VmlCQVhidUVSSEF2Y0phCm5hb1plY0JVQVJ0aUxYT2poOTFBNkFvNVpET2RETllOUkNnTGI2czdDVVhSKzNLenZWRmNJVFRSdGtTTkxKMTUKZzRoallyQUtEWTFIM09zd1EvU3JoTG9GQndneGJJQ1F5eFNLaXQ0OURrK2V4c3puMUJFNzE2aWlJVmdZT0daTwp5SWF5ekJZdW1Gc3M0MGprbWhsbms1ZW5hYjhJTDRUcXBDZS9xYnZtNXdOaktaVVozamJsM2QxVWVtcVlOdVlWCmNFY1o0UXltQUJZS3k0VkUzVFJZUmJJZGV0NFY2dVlIRjVZUHlFRWlZMFRVZStYVVJaVkFtaU9jcmtqblVIT3gKMWJqelJxSlpMNVR3b0ZDZzVlZUR6dVk0WlRjYwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
    



def deploy_argocd(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str,openunison_cluster_management_release,cert_manager):
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
            depends_on=[cert_manager],
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
            depends_on=[argocd_namespace],
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
                "applicationSet": {
                    "allowAnyNamespace": True
                },
                "configs": {
                    "cm": {
                    "url": "https://argocd." + domain_suffix,
                    "oidc.config": "name: OpenUnison\nissuer: https://k8sou." + domain_suffix + "/auth/idp/k8sIdp\nclientID: argocd\nrootCA: |\n" + ca_cert + "requestedIDTokenClaims:\n  groups:\n    essential: True\nrequestedScopes:\n  - openid\n  - profile\n  - email",
                    "timeout.reconciliation": "30s"
                    },
                    "params": {
                    "server.insecure": True,
                    "applicationsetcontroller.namespaces": "*",
                    "application.namespaces":"*",
                    "applicationsetcontroller.enable.scm.providers": False
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
            depends_on=[argocd_namespace],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    

    

    
    