import base64
import pulumi
from pulumi_kubernetes import helm, Provider
import pulumi_kubernetes as k8s
from pulumi_kubernetes.apiextensions.CustomResource import CustomResource
from ...lib.helm_chart_versions import get_latest_helm_chart_version
import logging
import kubernetes
from kubernetes import config as kube_config, dynamic
from kubernetes import client as k8s_client
from kubernetes.dynamic.exceptions import ResourceNotFoundError
from kubernetes.client import api_client
from pulumiverse_harbor.config_auth import ConfigAuth
import secrets

def load_ca_cert():
    try:
        # this is probably the wrong way to do this, but <shrug>
        k8s_cp_api = kube_config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
        k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
        k8s_cp_custom_api = k8s_client.CustomObjectsApi(k8s_cp_api)

        cluster_issuer_object = k8s_cp_custom_api.get_cluster_custom_object(group="cert-manager.io",version="v1",plural="clusterissuers",name="enterprise-ca")
        cluster_issuer_ca_secret_name = cluster_issuer_object["spec"]["ca"]["secretName"]
        pulumi.log.info("Loading CA from {}".format(cluster_issuer_ca_secret_name))
        ca_secret = k8s_cp_core_api.read_namespaced_secret(namespace="cert-manager",name=cluster_issuer_ca_secret_name)
        ca_cert = ca_secret.data["tls.crt"]

        return ca_cert
    except:
        return pulumi.Config().get("certmanager.clusterissuer.cert") or "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURFVENDQWZtZ0F3SUJBZ0lVYmtiS2ZRN29ldXJuVHpyeWdIL0dDS0kzNkUwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05aVzUwWlhKd2NtbHpaUzFqWVRBZUZ3MHlNakV4TURjeE5EUTFNakphRncwegpNakV4TURReE5EUTFNakphTUJneEZqQVVCZ05WQkFNTURXVnVkR1Z5Y0hKcGMyVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNucVZ3eVFvMjJyRzZuVVpjU2UvR21WZnI5MEt6Z3V4MDkKNDY4cFNTUWRwRHE5UlRRVU92ZkFUUEJXODF3QlJmUDEvcnlFaHNocnVBS2E5LzVoKzVCL3g4bmN4VFhwbThCNwp2RDdldHY4V3VyeUtQc0lMdWlkT0QwR1FTRVRvNzdBWE03RmZpUk9yMDFqN3c2UVB3dVB2QkpTcDNpa2lDL0RjCnZFNjZsdklFWE43ZFNnRGRkdnV2R1FORFdPWWxHWmhmNUZIVy81ZHJQSHVPOXp1eVVHK01NaTFpUCtSQk1QUmcKSWU2djhCcE9ncnNnZHRtWExhNFZNc1BNKzBYZkQwSDhjU2YvMkg2V1M0LzdEOEF1bG5QSW9LY1krRkxKUEFtMwpJVFI3L2w2UTBJUXVNU3c2QkxLYWZCRm5CVmNUUVNIN3lKZEFKNWdINFZZRHIyamtVWkwzQWdNQkFBR2pVekJSCk1CMEdBMVVkRGdRV0JCU2Y5RDVGS3dISUY3eFdxRi80OG4rci9SVFEzakFmQmdOVkhTTUVHREFXZ0JTZjlENUYKS3dISUY3eFdxRi80OG4rci9SVFEzakFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQQpBNElCQVFCN1BsMjkrclJ2eHArVHhLT3RCZGRLeEhhRTJVRUxuYmlkaFUvMTZRbW51VmlCQVhidUVSSEF2Y0phCm5hb1plY0JVQVJ0aUxYT2poOTFBNkFvNVpET2RETllOUkNnTGI2czdDVVhSKzNLenZWRmNJVFRSdGtTTkxKMTUKZzRoallyQUtEWTFIM09zd1EvU3JoTG9GQndneGJJQ1F5eFNLaXQ0OURrK2V4c3puMUJFNzE2aWlJVmdZT0daTwp5SWF5ekJZdW1Gc3M0MGprbWhsbms1ZW5hYjhJTDRUcXBDZS9xYnZtNXdOaktaVVozamJsM2QxVWVtcVlOdVlWCmNFY1o0UXltQUJZS3k0VkUzVFJZUmJJZGV0NFY2dVlIRjVZUHlFRWlZMFRVZStYVVJaVkFtaU9jcmtqblVIT3gKMWJqelJxSlpMNVR3b0ZDZzVlZUR6dVk0WlRjYwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="


def load_oidc_secret(k8s_provider,openunison_cluster_management_release):
    # this is probably the wrong way to do this, but <shrug>
    k8s_cp_api = kube_config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
    k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)

    try:
        oidc_secret = k8s_cp_core_api.read_namespaced_secret(namespace="openunison",name="harbor-oidc")
        oidc_client_secret = oidc_secret.data["harbor.oidc.client_secret"]

        decoded_secret = base64.b64decode(oidc_client_secret).decode("utf-8")

    except kubernetes.client.exceptions.ApiException:
        # the secret doesn't exist, let's create it
        decoded_secret = secrets.token_urlsafe(64)
    
    harbor_oidc_secret = k8s.core.v1.Secret(
    "harbor-oidc",
    metadata= k8s.meta.v1.ObjectMetaArgs(
        name="harbor-oidc",
        namespace="openunison"
    ),
    data={
        "harbor.oidc.client_secret": base64.b64encode(decoded_secret.encode('utf-8')).decode('utf-8'),
    },
    opts=pulumi.ResourceOptions(
        provider = k8s_provider,
        retain_on_delete=False,
        delete_before_replace=True,
        depends_on=[openunison_cluster_management_release],
        custom_timeouts=pulumi.CustomTimeouts(
            create="10m",
            update="10m",
            delete="10m"
        )
    )
    )

    return [harbor_oidc_secret,decoded_secret]

def load_admin_secret(k8s_provider,harborns):
    # this is probably the wrong way to do this, but <shrug>
    k8s_cp_api = kube_config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
    k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
    
    try:
        admin_secret = k8s_cp_core_api.read_namespaced_secret(namespace="harbor",name="harbor-admin")
        admin_client_secret = admin_secret.data["harbor-admin"]

        decoded_secret = base64.b64decode(admin_client_secret).decode("utf-8")

    except kubernetes.client.exceptions.ApiException:
        # the secret doesn't exist, let's create it
        decoded_secret = secrets.token_urlsafe(64)
    
    admin_secret = k8s.core.v1.Secret(
    "harbor-admin",
    metadata= k8s.meta.v1.ObjectMetaArgs(
        name="harbor-admin",
        namespace="harbor"
    ),
    data={
        "harbor-admin": base64.b64encode(decoded_secret.encode('utf-8')).decode('utf-8'),
    },
    opts=pulumi.ResourceOptions(
        provider = k8s_provider,
        depends_on = [harborns],
        retain_on_delete=False,
        delete_before_replace=True,
        custom_timeouts=pulumi.CustomTimeouts(
            create="10m",
            update="10m",
            delete="10m"
        )
    )
    )

    return [admin_secret,decoded_secret]

def deploy_harbor(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str,openunison_cluster_management_release,certificate_manager):
    logging.info("in harbor")
    config = pulumi.Config()
    # Create a Namespace
    harbor_namespace = k8s.core.v1.Namespace("harbor_namespace",
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="harbor"
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

    # get the domain suffix and cluster_issuer
    domain_suffix = config.require('openunison.cp.dns_suffix')

    # generate a unique root password and store as a secret
    [admin_secret,admin_password] = load_admin_secret(k8s_provider,harbor_namespace)

    # generate a Secret for our CA cert
    ca_secret = k8s.core.v1.Secret(
    "harbor-ca-secret",
    metadata= k8s.meta.v1.ObjectMetaArgs(
        name="harbor-ca",
        namespace="harbor"
    ),
    data={
        "ca.crt": base64.b64encode(load_ca_cert().encode('utf-8')).decode('utf-8'),
    },
    opts=pulumi.ResourceOptions(
        provider = k8s_provider,
        depends_on = [harbor_namespace],
        retain_on_delete=False,
        delete_before_replace=True,
        custom_timeouts=pulumi.CustomTimeouts(
            create="10m",
            update="10m",
            delete="10m"
        )
    )
    )

    harbor_certificate = CustomResource(
        "harbor_certificate",
        api_version="cert-manager.io/v1",
        kind="Certificate",
        metadata={
            "name": "harbor-certificate",
            "namespace": "harbor"
        },
        spec={
            "commonName": "harbor." + domain_suffix,
            "duration": "2160h0m0s",
            "isCA": False,
            "issuerRef": {
                "group": "cert-manager.io",
                "kind": "ClusterIssuer",
                "name": "enterprise-ca"
            },
            "privateKey": {
                "algorithm": "RSA",
                "encoding": "PKCS1",
                "size": 2048
            },
            "renewBefore": "360h0m0s",
            "secretName": "harbor-tls-certificate",
            "dnsNames": [
                "harbor." + domain_suffix
            ],
            "usages":["server auth","client auth"]
        },
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[harbor_namespace,certificate_manager],
            custom_timeouts=pulumi.CustomTimeouts(
                create="30m",
                update="30m",
                delete="30m"
            )
        )
    )

    helm_values = {
        "expose": {
            "type": "ingress",
            "tls": {
                "certSource": "secret",
                "secret": {
                    "secretName": "harbor-tls-certificate",
                }
            },
            "ingress": {
                "hosts": {
                    "core": "harbor." + domain_suffix,
                },
                "annotations": {
                    "kubernetes.io/ingress.class": "nginx"
                }
            }
        },
        "externalURL": "https://harbor." + domain_suffix,
        "caBundleSecretName": "harbor-ca",
        "existingSecretAdminPassword": "harbor-admin",
        "existingSecretAdminPasswordKey": "harbor-admin",
        "caSecretName": "harbor-ca",

    }

    # Fetch the latest version from the helm chart index
    chart_name = "harbor"
    chart_index_path = "index.yaml"
    chart_url = "https://helm.goharbor.io"
    index_url = f"{chart_url}/{chart_index_path}"
    chart_version = get_latest_helm_chart_version(index_url, chart_name)

    

    release = k8s.helm.v3.Release(
        'harbor',
        k8s.helm.v3.ReleaseArgs(
            chart='harbor',
            version=chart_version,
            namespace='harbor',
            skip_await=False,
            repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                repo=chart_url
            ),
            values=helm_values,
        ),
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[harbor_certificate,harbor_namespace,harbor_certificate,admin_secret],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    

    
    # creds have been set, we can configure
    logging.info("in harbor oidc configuration")
    [harbor_oidc_secret,decoded_secret] = load_oidc_secret(k8s_provider,openunison_cluster_management_release)

    harbor_configured = config.get_bool("harbor.configured") or None
    if harbor_configured:
        oidc_auth = ConfigAuth("harbor-oidc-config",
                                        auth_mode="oidc",
                                        primary_auth_mode=True,
                                        oidc_name="openunison",
                                        oidc_endpoint="https://k8sou." + domain_suffix + "/auth/idp/k8sIdp",
                                        oidc_client_id="harbor",
                                        oidc_client_secret=decoded_secret,
                                        oidc_scope="openid, email, profile",
                                        oidc_verify_cert=False,
                                        oidc_auto_onboard=True,
                                        oidc_user_claim="sub",
                                        oidc_groups_claim="groups",
                                        oidc_admin_group="k8s-cluster-k8s-administrators-internal",
                                        opts = pulumi.ResourceOptions(depends_on=[release,harbor_oidc_secret]))
    