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
import secrets
import pulumi_vault as vault


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

        decoded_cert = base64.b64decode(ca_cert).decode("utf-8")
        return decoded_cert
    except:
        return base64.b64decode(pulumi.Config().get("certmanager.clusterissuer.cert") or "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURFVENDQWZtZ0F3SUJBZ0lVYmtiS2ZRN29ldXJuVHpyeWdIL0dDS0kzNkUwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05aVzUwWlhKd2NtbHpaUzFqWVRBZUZ3MHlNakV4TURjeE5EUTFNakphRncwegpNakV4TURReE5EUTFNakphTUJneEZqQVVCZ05WQkFNTURXVnVkR1Z5Y0hKcGMyVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNucVZ3eVFvMjJyRzZuVVpjU2UvR21WZnI5MEt6Z3V4MDkKNDY4cFNTUWRwRHE5UlRRVU92ZkFUUEJXODF3QlJmUDEvcnlFaHNocnVBS2E5LzVoKzVCL3g4bmN4VFhwbThCNwp2RDdldHY4V3VyeUtQc0lMdWlkT0QwR1FTRVRvNzdBWE03RmZpUk9yMDFqN3c2UVB3dVB2QkpTcDNpa2lDL0RjCnZFNjZsdklFWE43ZFNnRGRkdnV2R1FORFdPWWxHWmhmNUZIVy81ZHJQSHVPOXp1eVVHK01NaTFpUCtSQk1QUmcKSWU2djhCcE9ncnNnZHRtWExhNFZNc1BNKzBYZkQwSDhjU2YvMkg2V1M0LzdEOEF1bG5QSW9LY1krRkxKUEFtMwpJVFI3L2w2UTBJUXVNU3c2QkxLYWZCRm5CVmNUUVNIN3lKZEFKNWdINFZZRHIyamtVWkwzQWdNQkFBR2pVekJSCk1CMEdBMVVkRGdRV0JCU2Y5RDVGS3dISUY3eFdxRi80OG4rci9SVFEzakFmQmdOVkhTTUVHREFXZ0JTZjlENUYKS3dISUY3eFdxRi80OG4rci9SVFEzakFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQQpBNElCQVFCN1BsMjkrclJ2eHArVHhLT3RCZGRLeEhhRTJVRUxuYmlkaFUvMTZRbW51VmlCQVhidUVSSEF2Y0phCm5hb1plY0JVQVJ0aUxYT2poOTFBNkFvNVpET2RETllOUkNnTGI2czdDVVhSKzNLenZWRmNJVFRSdGtTTkxKMTUKZzRoallyQUtEWTFIM09zd1EvU3JoTG9GQndneGJJQ1F5eFNLaXQ0OURrK2V4c3puMUJFNzE2aWlJVmdZT0daTwp5SWF5ekJZdW1Gc3M0MGprbWhsbms1ZW5hYjhJTDRUcXBDZS9xYnZtNXdOaktaVVozamJsM2QxVWVtcVlOdVlWCmNFY1o0UXltQUJZS3k0VkUzVFJZUmJJZGV0NFY2dVlIRjVZUHlFRWlZMFRVZStYVVJaVkFtaU9jcmtqblVIT3gKMWJqelJxSlpMNVR3b0ZDZzVlZUR6dVk0WlRjYwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==").decode("utf-8")

def load_kube_ca_cert():
    # this is probably the wrong way to do this, but <shrug>
    k8s_cp_api = kube_config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
    k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
    
    
    ca_secret = k8s_cp_core_api.read_namespaced_config_map(namespace="default",name="kube-root-ca.crt")
    ca_cert = ca_secret.data["ca.crt"]
    #ca_cert = base64.b64encode(ca_cert.encode('utf8')).decode('ascii')
    return ca_cert


def load_oidc_secret(k8s_provider,openunison_cluster_management_release):
    # this is probably the wrong way to do this, but <shrug>
    k8s_cp_api = kube_config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
    k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
    

    try:
        oidc_secret = k8s_cp_core_api.read_namespaced_secret(namespace="openunison",name="vault-oidc")
        oidc_client_secret = oidc_secret.data["vault.oidc.client_secret"]

        decoded_secret = base64.b64decode(oidc_client_secret).decode("utf-8")

    except kubernetes.client.exceptions.ApiException:
        # the secret doesn't exist, let's create it
        decoded_secret = secrets.token_urlsafe(64)
    
    vault_oidc_secret = k8s.core.v1.Secret(
    "vault-oidc",
    metadata= k8s.meta.v1.ObjectMetaArgs(
        name="vault-oidc",
        namespace="openunison"
    ),
    data={
        "vault.oidc.client_secret": base64.b64encode(decoded_secret.encode('utf-8')).decode('utf-8'),
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

    return [vault_oidc_secret,decoded_secret]


def gen_vault_client_token():
    k8s_cp_api = kube_config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
    k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
    
    
    try:
        token_request = k8s_client.AuthenticationV1TokenRequest(
            kind="TokenRequest",
            api_version="authentication.k8s.io/v1",
            metadata=k8s_client.V1ObjectMeta(

            ),
            spec=k8s_client.V1TokenRequestSpec(
                audiences = ["https://kubernetes.default.svc.cluster.local"],
                expiration_seconds = 60*60*24*365
            )

        )

        token_response = k8s_cp_core_api.create_namespaced_service_account_token(namespace="vault-integration",
                                                                                        name="vault-client",
                                                                                        body=token_request)

        return token_response.status.token
    except kubernetes.client.exceptions.ApiException:
        return "notoken"

def deploy_vault(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str,openunison_cluster_management_release,orchestra_release,cert_manager):
    logging.info("in deploy_vault")
    config = pulumi.Config()

    # Generate a Namespace, ServiceAccount, Bindings and Tokens for using authenticating to Vault via Kubernetes

    vault_integration_manifest_url = 'src/yaml/vaultintegration.yaml'
    vaultintegration_k8s_yaml = k8s.yaml.ConfigFile("vault_integration", file=vault_integration_manifest_url,opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            retain_on_delete=False,
            delete_before_replace=True,
            custom_timeouts=pulumi.CustomTimeouts(
                create="10m",
                update="10m",
                delete="10m"
            )
        ))

    #pulumi.export('vault_integration_yaml', vaultintegration_k8s_yaml)

    # Create a Namespace
    vault_namespace = k8s.core.v1.Namespace("vault_namespace",
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="vault"
        ),
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on = [vaultintegration_k8s_yaml,cert_manager],
            retain_on_delete=True,
            custom_timeouts=pulumi.CustomTimeouts(
                create="10m",
                update="10m",
                delete="10m"
            )
        )
    )

    #
    # get the domain suffix and cluster_issuer
    domain_suffix = config.require('openunison.cp.dns_suffix')

    

    helm_values = {
        "ui": {
            "enabled": True,
            "serviceType": "ClusterIP",

        },
        "server": {
            "ingress": {
                "enabled": True,
                "annotations": {
                    "cert-manager.io/cluster-issuer": "enterprise-ca",
                },
                "ingressClassName": "nginx",
                "hosts": [
                    {
                        "host": "vault." + domain_suffix,
                        "paths": ["/"]
                    }
                ],
                "tls": [
                    {
                        "secretName": "vault-tls",
                        "hosts": [
                            "vault." + domain_suffix
                        ]
                    }
                ]

            },
            "dev": {
                "enabled": False

            },
            "ui": {
                "enabled": True
            }
        }
    }


    # Fetch the latest version from the helm chart index
    chart_name = "vault"
    chart_index_path = "index.yaml"
    chart_url = "https://helm.releases.hashicorp.com"
    index_url = f"{chart_url}/{chart_index_path}"
    chart_version = get_latest_helm_chart_version(index_url, chart_name)

    

    release = k8s.helm.v3.Release(
        'vault',
        k8s.helm.v3.ReleaseArgs(
            chart='vault',
            version=chart_version,
            namespace='vault',
            skip_await=False,
            repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                repo=chart_url
            ),
            values=helm_values,
        ),
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[vault_namespace],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    


    # Setup a vault provider
    vault_root_token = config.get_secret("vault.key") or None
    if vault_root_token:
        vault_provider = vault.Provider("vault_provider",address="https://vault." + domain_suffix,token=vault_root_token.apply(lambda token : token),skip_tls_verify=True)

        # create the kube auth backend so we can validate tokens
        # we generate a token using the TokenRequest API

        # enable the kubernetes auth backend
        kubernetes_auth_backend = vault.AuthBackend("kubernetes",type="kubernetes",opts=pulumi.ResourceOptions(depends_on = [release],provider=vault_provider),)

        jwt_token = gen_vault_client_token()
        kube_ca_cert = load_kube_ca_cert()
        logging.info("kube ca cert : '" + kube_ca_cert + "'")

        if jwt_token != "notoken":
            # Configure the Kubernetes Auth Method in Vault
            k8s_auth_config = vault.kubernetes.AuthBackendConfig("k8s-auth-cp-config",
                opts=pulumi.ResourceOptions(depends_on = [vaultintegration_k8s_yaml,kubernetes_auth_backend],provider=vault_provider),
                # Provide the Kubernetes host, i.e., the API server URL
                kubernetes_host="https://kubernetes.default.svc.cluster.local",
                backend=kubernetes_auth_backend.path,
                # Provide the base64 encoded cluster CA certificate
                kubernetes_ca_cert=kube_ca_cert,
                # get a JWT via TokenRequest API
                token_reviewer_jwt = jwt_token
                
            )

            # create a policy so OpenUnison can provision reasources using its ServiceAccount
            with open('src/hcl/vault-admin.hcl','r') as file:
                ou_admin_policy_cfg = file.read()

            ou_admin_policy = vault.Policy("ou_admin_policy",name="ou-admin",policy=ou_admin_policy_cfg,opts=pulumi.ResourceOptions(depends_on = [k8s_auth_config],provider=vault_provider))

            # Bind the ou admin policy to the openunison:orchestra ServiceAccount
            ou_admin_role = vault.kubernetes.AuthBackendRole("ou_admin_role",
                                                            backend=kubernetes_auth_backend.path,
                                                            role_name="ou_admin_role",
                                                            bound_service_account_names=[ orchestra_release.resource_names.apply(lambda resource_names : resource_names["ServiceAccount/v1"][0].split('/')[1] ) ],
                                                            bound_service_account_namespaces=[ "openunison" ],
                                                            token_ttl=86400,
                                                            token_policies=["ou-admin"],
                                                            opts=pulumi.ResourceOptions(depends_on = [ou_admin_policy],provider=vault_provider))
            
            #create a mount for our secrets
            cluster_mount = vault.Mount("cluster_mount",
                                        description="Mount for all secrets",
                                        path="secret",
                                        type="kv",
                                        opts=pulumi.ResourceOptions(depends_on = [ou_admin_policy],provider=vault_provider))
            
            # get the oidc client secret
            [vault_oidc_secret,oidc_client_secret] = load_oidc_secret(k8s_provider,openunison_cluster_management_release)
            
            # Configuring OIDC login to Vault's UI
            # create a policy so cp cluster admins can manage vault
            with open('src/hcl/vault-ou-admins.hcl','r') as file:
                ou_cluster_admin_policy_cfg = file.read()

            
            ou_cluster_admin_policy = vault.Policy("ou_clusteR_admin_policy",name="ou_cluster_admin",policy=ou_cluster_admin_policy_cfg,opts=pulumi.ResourceOptions(depends_on = [k8s_auth_config],provider=vault_provider))

            


            #oidc_auth_enable = vault.AuthBackend("oidc",type="oidc",opts=pulumi.ResourceOptions(depends_on = [release],provider=vault_provider))

            # enable the oidc auth backend
            oidc_auth_backend = vault.jwt.AuthBackend("oidc-jwt-backend",
                                                    opts=pulumi.ResourceOptions(depends_on = [vault_oidc_secret,release],provider=vault_provider),
                                                    path="oidc",
                                                    default_role="oidc-auth-openunison",
                                                    oidc_discovery_url="https://k8sou." + domain_suffix + "/auth/idp/k8sIdp",
                                                    oidc_discovery_ca_pem=load_ca_cert(),
                                                    oidc_client_id="vault",
                                                    oidc_client_secret=oidc_client_secret,
                                                    bound_issuer="https://k8sou." + domain_suffix + "/auth/idp/k8sIdp",
                                                    description="OpenUnison",
                                                    type="oidc")

            # Configure the OIDC Auth Role in Vault
            oidc_auth_role = vault.jwt.AuthBackendRole("oidc-auth-cp-role",
                opts=pulumi.ResourceOptions(depends_on = [openunison_cluster_management_release,release],provider=vault_provider),
                backend = oidc_auth_backend.path,
                bound_audiences=["vault"],
                allowed_redirect_uris=["https://vault." + domain_suffix + "/ui/vault/auth/oidc/oidc/callback","https://vault." + domain_suffix + "/oidc/oidc/callback"],
                user_claim="sub",
                role_type="oidc",
                groups_claim="groups",
                role_name="oidc-auth-openunison"
            )

            # bind our external (to vault) group to the cp cluster admin group
            vault_admin_group = vault.identity.Group("vault_oidc_admins",
                                metadata={
                                    "version": "1",
                                },
                                policies=["ou_cluster_admin"],
                                type="external",
                                name="openunison_admin",
                                opts=pulumi.ResourceOptions(depends_on=[oidc_auth_role],provider=vault_provider))
            
            # create a group alias to our cluster admin group
            vault_admin_group_alias = vault.identity.GroupAlias("vault_oidc_admins_alias",
                                                                name="k8s-cluster-k8s-administrators-internal",
                                                                mount_accessor=oidc_auth_backend.accessor,
                                                                canonical_id=vault_admin_group.id,
                                                                opts=pulumi.ResourceOptions(depends_on=[vault_admin_group],provider=vault_provider)
                                                            )

    



    

    
    