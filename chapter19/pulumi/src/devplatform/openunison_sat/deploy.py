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


def deploy_cp_integration(k8s_provider: Provider,cp_domain_suffix:str,domain_suffix:str,env:str,ca_cert:str,orchestra_login_portal):
    # this is probably the wrong way to do this, but <shrug>
    k8s_cp_api =config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
    k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
    

    try:
        oidc_secret =k8s_cp_core_api.read_namespaced_secret(namespace="openunison",name="oidc-remote-" + env)
        oidc_client_secret = oidc_secret.data["cluster-idp-kubernetes-" + env]

        decoded_secret = base64.b64decode(oidc_client_secret).decode("utf-8")

    except k8s_client.exceptions.ApiException:
        # the secret doesn't exist, let's create it
        decoded_secret = secrets.token_urlsafe(64)
    
    oidc_secret = k8s.core.v1.Secret(
    "oidc-remote-" + env,
    metadata= k8s.meta.v1.ObjectMetaArgs(
        name="oidc-remote-" + env,
        namespace="openunison"
    ),
    data={
        "cluster-idp-kubernetes-"+env : base64.b64encode(decoded_secret.encode('utf-8')).decode('utf-8'),
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

    helm_values =   {
                        "cluster": {
                        "az_groups": [
                            "k8s-namespace-administrators-k8s-kubernetes-" + env + "-*",
                            "k8s-namespace-viewer-k8s-kubernetes-" + env + "-*",
                            "k8s-cluster-k8s-kubernetes-" + env + "-administrators-internal"
                        ],
                        "description": "Cluster kubernetes-" + env + "",
                        "hosts": {
                            "dashboard": "k8sdb." + domain_suffix,
                            "portal": "k8sou." + domain_suffix,
                        },
                        "label": "kubernetes-" + env,
                        "management": {
                            "enabled": True,
                            "target": {
                            "base64_certificate": ca_cert,
                            "tokenType": "oidc",
                            "url": "oumgmt-proxy." + domain_suffix,
                            "useToken": True
                            }
                        },
                        "name": "kubernetes-" + env,
                        "parent": "B158BD40-0C1B-11E3-8FFD-0800200C9A66",
                        "sso": {
                            "enabled": True,
                            "inactivityTimeoutSeconds": 900,
                            "client_secret": "oidc-remote-" + env,
                        }
                        },
                        "naasRoles": [
                        {
                            "bindings": [
                            {
                                "binding": "admins",
                                "name": "admin",
                                "type": "ClusterRole"
                            }
                            ],
                            "description": "Manage membership of the $nameSpace$ project, responsible for push to production",
                            "external": {
                            "errorMessage": "Invalid owners group",
                            "fieldName": "ownerGroup",
                            "label": "Owner Group"
                            },
                            "name": "owners",
                            "workflow": {
                            "approvalLabel": "Approve owner, $name$",
                            "displayLabel": "$name$ Owner",
                            "emailTemplate": "Approve owner for $name$",
                            "label": "project owner",
                            "org": {
                                "description": "Project Owners",
                                "label": "Owners"
                            },
                            "userNotification": {
                                "message": "Your access has been approved",
                                "subject": "Owner access to $name$ approved"
                            }
                            }
                        },
                        {
                            "bindings": [
                            {
                                "binding": "viewers",
                                "name": "view",
                                "type": "ClusterRole"
                            }
                            ],
                            "description": "View kubernetes namespace $cluster$ $nameSpace$",
                            "external": {
                            "errorMessage": "Invalid viewer group",
                            "fieldName": "viewerGroup",
                            "label": "Viewer Group"
                            },
                            "name": "viewer",
                            "workflow": {
                            "approvalLabel": "Approve viewer access for $cluster$ - $name$",
                            "displayLabel": "$name$ Administrator",
                            "emailTemplate": "Approve viewer access to $cluster$ $name$",
                            "label": "namespace viewer",
                            "org": {
                                "description": "Namespace Viewers",
                                "label": "Viewers"
                            },
                            "userNotification": {
                                "message": "Your access has been approved",
                                "subject": "View access to $cluster$ $name$ approved"
                            }
                            }
                        }
                        ]
                    }
    
    chart_name = "openunison-k8s-add-cluster"
    chart_index_path = "index.yaml"
    chart_url = "https://nexus.tremolo.io/repository/helm"
    index_url = f"{chart_url}/{chart_index_path}"
    #chart_version = get_latest_helm_chart_version(index_url,chart_name)
    localpath = '/Users/marcboorshtein/git-local/helm-charts';
    openunison_k8s_add_client_release = k8s.helm.v3.Release(
        'openunison-cluster-' + env,
        k8s.helm.v3.ReleaseArgs(
            #chart=chart_name,
            chart=localpath + '/' + chart_name,
            #version=chart_version,
            values=helm_values,
            namespace='openunison',
            skip_await=False,
            # repository_opts= k8s.helm.v3.RepositoryOptsArgs(
            #     repo=chart_url
            # ),
        ),
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[orchestra_login_portal],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    return [openunison_k8s_add_client_release,decoded_secret]
    




def deploy_openunison_sat(name: str, k8s_provider: Provider, k8s_cp_provider: Provider,kubernetes_distribution: str, project_name: str, namespace: str, env :str,orchestra_login_portal,dev_cert_manager):
    # Initialize Pulumi configuration
    pconfig = pulumi.Config()

    # Deploy the Kubernetes Dashboard 6.0.8
    k8s_db_release = deploy_kubernetes_dashboard(name=name,k8s_provider=k8s_provider,kubernetes_distribution=kubernetes_distribution,project_name=project_name,namespace=namespace,env=env)

    # generate openunison namespace
    openunison_namespace = k8s.core.v1.Namespace("openunison-"+env,
            metadata= k8s.meta.v1.ObjectMetaArgs(
                name="openunison"
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
    domain_suffix = pconfig.require('openunison.' + env + '.dns_suffix')
    cp_domain_suffix = pconfig.require('openunison.cp.dns_suffix')

    # get the cluster issuer
    cluster_issuer = "enterprise-ca"

    # create the Certificate
    openunison_certificate = CustomResource(
        "ou-tls-certificate-"+env,
        api_version="cert-manager.io/v1",
        kind="Certificate",
        metadata={
            "name": "ou-tls-certificate",
            "namespace": "openunison",
        },
        spec={
            "secretName": "ou-tls-certificate",
            "commonName": "*." + domain_suffix,
            "isCA": False,
            "privateKey": {
                "algorithm": "RSA",
                "encoding": "PKCS1",
                "size": 2048,
            },
            "usages": ["server auth","client auth"],
            "dnsNames": ["*." + domain_suffix, domain_suffix],
            "issuerRef": {
                "name": cluster_issuer,
                "kind": "ClusterIssuer",
                "group": "cert-manager.io",
            },
        },
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[openunison_namespace,dev_cert_manager],
            custom_timeouts=pulumi.CustomTimeouts(
                create="5m",
                update="10m",
                delete="10m"
            )
        )
    )

    # this is probably the wrong way to do this, but <shrug>
    k8s_cp_api = config.kube_config.new_client_from_config(pulumi.Config().require("kube.dev.path"))
    k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
    k8s_cp_custom_api = k8s_client.CustomObjectsApi(k8s_cp_api)

    try:
        cluster_issuer_object = k8s_cp_custom_api.get_cluster_custom_object(group="cert-manager.io",version="v1",plural="clusterissuers",name=cluster_issuer)

        cluster_issuer_ca_secret_name = cluster_issuer_object["spec"]["ca"]["secretName"]

        pulumi.log.info("Loading CA from {}".format(cluster_issuer_ca_secret_name))

        ca_secret = k8s_cp_core_api.read_namespaced_secret(namespace="cert-manager",name=cluster_issuer_ca_secret_name)

        ca_cert = ca_secret.data["tls.crt"]
    except k8s_client.exceptions.ApiException:
        ca_cert = pulumi.Config().get("certmanager.clusterissuer.cert") or "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURFVENDQWZtZ0F3SUJBZ0lVYmtiS2ZRN29ldXJuVHpyeWdIL0dDS0kzNkUwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05aVzUwWlhKd2NtbHpaUzFqWVRBZUZ3MHlNakV4TURjeE5EUTFNakphRncwegpNakV4TURReE5EUTFNakphTUJneEZqQVVCZ05WQkFNTURXVnVkR1Z5Y0hKcGMyVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNucVZ3eVFvMjJyRzZuVVpjU2UvR21WZnI5MEt6Z3V4MDkKNDY4cFNTUWRwRHE5UlRRVU92ZkFUUEJXODF3QlJmUDEvcnlFaHNocnVBS2E5LzVoKzVCL3g4bmN4VFhwbThCNwp2RDdldHY4V3VyeUtQc0lMdWlkT0QwR1FTRVRvNzdBWE03RmZpUk9yMDFqN3c2UVB3dVB2QkpTcDNpa2lDL0RjCnZFNjZsdklFWE43ZFNnRGRkdnV2R1FORFdPWWxHWmhmNUZIVy81ZHJQSHVPOXp1eVVHK01NaTFpUCtSQk1QUmcKSWU2djhCcE9ncnNnZHRtWExhNFZNc1BNKzBYZkQwSDhjU2YvMkg2V1M0LzdEOEF1bG5QSW9LY1krRkxKUEFtMwpJVFI3L2w2UTBJUXVNU3c2QkxLYWZCRm5CVmNUUVNIN3lKZEFKNWdINFZZRHIyamtVWkwzQWdNQkFBR2pVekJSCk1CMEdBMVVkRGdRV0JCU2Y5RDVGS3dISUY3eFdxRi80OG4rci9SVFEzakFmQmdOVkhTTUVHREFXZ0JTZjlENUYKS3dISUY3eFdxRi80OG4rci9SVFEzakFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQQpBNElCQVFCN1BsMjkrclJ2eHArVHhLT3RCZGRLeEhhRTJVRUxuYmlkaFUvMTZRbW51VmlCQVhidUVSSEF2Y0phCm5hb1plY0JVQVJ0aUxYT2poOTFBNkFvNVpET2RETllOUkNnTGI2czdDVVhSKzNLenZWRmNJVFRSdGtTTkxKMTUKZzRoallyQUtEWTFIM09zd1EvU3JoTG9GQndneGJJQ1F5eFNLaXQ0OURrK2V4c3puMUJFNzE2aWlJVmdZT0daTwp5SWF5ekJZdW1Gc3M0MGprbWhsbms1ZW5hYjhJTDRUcXBDZS9xYnZtNXdOaktaVVozamJsM2QxVWVtcVlOdVlWCmNFY1o0UXltQUJZS3k0VkUzVFJZUmJJZGV0NFY2dVlIRjVZUHlFRWlZMFRVZStYVVJaVkFtaU9jcmtqblVIT3gKMWJqelJxSlpMNVR3b0ZDZzVlZUR6dVk0WlRjYwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="

    pulumi.log.info("Satelite CA Certificate {}".format(ca_cert))

    # deploy integration on the control plane
    [openunison_k8s_add_client_release,client_secret] = deploy_cp_integration(k8s_provider=k8s_cp_provider,
                          cp_domain_suffix=cp_domain_suffix,
                          domain_suffix=domain_suffix,
                          env=env,
                          ca_cert=ca_cert,
                          orchestra_login_portal=orchestra_login_portal)

    return deploy_openunison_charts(ca_cert=ca_cert,k8s_provider=k8s_provider,kubernetes_distribution=kubernetes_distribution,project_name=project_name,namespace=namespace,domain_suffix=domain_suffix,openunison_certificate=openunison_certificate,config=pconfig,db_release=k8s_db_release,cp_domain_suffix=cp_domain_suffix,env=env,client_secret=client_secret,openunison_k8s_add_client_release=openunison_k8s_add_client_release)



def deploy_openunison_charts(ca_cert,k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str,domain_suffix: str,openunison_certificate,config,db_release, cp_domain_suffix: str,env :str,client_secret : str,openunison_k8s_add_client_release):


    openunison_helm_values = {
        "enable_wait_for_job": True,
        "network": {
            "openunison_host": "k8sou." + domain_suffix,
            "dashboard_host": "k8sdb." + domain_suffix,
            "api_server_host": "k8sapi." + domain_suffix,
            "session_inactivity_timeout_seconds": 900,
            "k8s_url": "https://192.168.2.130:6443",
            "force_redirect_to_tls": False,
            "createIngressCertificate": False,
            "ingress_type": "nginx",
            "ingress_annotations": {
            }
        },
        "cert_template": {
            "ou": "Kubernetes",
            "o": "MyOrg",
            "l": "My Cluster",
            "st": "State of Cluster",
            "c": "MyCountry"
        },
        "myvd_config_path": "WEB-INF/myvd.conf",
        #"myvd_configmap": "myvd-book",
        "k8s_cluster_name": "openunison-kubernetes-" + env,
        "enable_impersonation": True,
        "impersonation": {
            "use_jetstack": True,
            "explicit_certificate_trust": True
        },
        "dashboard": {
            "namespace": "kubernetes-dashboard",
            #"cert_name": "kubernetes-dashboard-certs",
            "label": "app.kubernetes.io/name=kubernetes-dashboard",
            #"service_name": db_release.name.apply(lambda name: "kubernetes-dashboard-" + name)   ,
            "require_session": True
        },
        "certs": {
            "use_k8s_cm": False
        },
        "trusted_certs": [
        {
            "name": "unison-ca",
            "pem_b64": ca_cert,
        },
        {
            "name": "trusted-idp",
            "pem_b64": ca_cert,
        },
        ],
        "monitoring": {
            "prometheus_service_account": "system:serviceaccount:monitoring:prometheus-k8s"
        },
        
        
        
   
        
        "oidc": {
            "claims": {
                "display_name": "display_name",
                "email": "email",
                "family_name": "family_name",
                "given_name": "given_name",
                "groups": "groups",
                "sub": "sub"
            },
            "client_id": "cluster-idp-kubernetes-" + env,
            "domain": "",
            "issuer": "https://k8sou." + cp_domain_suffix + "/auth/idp/cluster-idp-kubernetes-" + env,
            "scopes": "openid email profile groups",
            "user_in_idtoken": True
        },
        

        
        "network_policies": {
        "enabled": False,
        "ingress": {
            "enabled": True,
            "labels": {
            "app.kubernetes.io/name": "ingress-nginx"
            }
        },
        "monitoring": {
            "enabled": True,
            "labels": {
            "app.kubernetes.io/name": "monitoring"
            }
        },
        "apiserver": {
            "enabled": False,
            "labels": {
            "app.kubernetes.io/name": "kube-system"
            }
        }
        },
        "services": {
        "enable_tokenrequest": False,
        "token_request_audience": "api",
        "token_request_expiration_seconds": 600,
        "node_selectors": [

        ]
        },
        "openunison": {
            "az_groups": [
                "k8s-namespace-administrators-k8s-kubernetes-" + env + "-*",
                "k8s-namespace-viewer-k8s-kubernetes-" + env + "-*",
                "k8s-cluster-k8s-kubernetes-" + env + "-administrators-internal"
            ],
            "enable_provisioning": False,
            "management_proxy": {
                "enabled": True,
                "host": "oumgmt-proxy." + domain_suffix,
                "remote": {
                    "cert_alias": "trusted-idp",
                    "issuer": "https://k8sou." + cp_domain_suffix + "/auth/idp/remotek8s"
                }
            },
            "non_secret_data": {
            "K8S_DB_SSO": "oidc",
            "PROMETHEUS_SERVICE_ACCOUNT": "system:serviceaccount:monitoring:prometheus-k8s",
            "SHOW_PORTAL_ORGS": "False"
            },
            "replicas": 1,
            "secrets": []
        },
        "apps":[],
        # "post_jit_workflow": "jit-gitlab",
    }
    

    orchesrta_login_portal_helm_values = json.loads(json.dumps(openunison_helm_values))
    openunison_helm_values["dashboard"]["service_name"] = db_release.name.apply(lambda name: name)
    openunison_helm_values["dashboard"]["cert_name"] = db_release.name.apply(lambda name: name + "-certs")
    orchesrta_login_portal_helm_values["dashboard"]["service_name"] = db_release.name.apply(lambda name: name)

    # Fetch the latest version from the helm chart index
    chart_name = "openunison-operator"
    chart_index_path = "index.yaml"
    chart_url = "https://nexus.tremolo.io/repository/helm"
    index_url = f"{chart_url}/{chart_index_path}"
    chart_version = get_latest_helm_chart_version(index_url,chart_name)

    openunison_operator_release = k8s.helm.v3.Release(
        'openunison-operator-'+env,
        k8s.helm.v3.ReleaseArgs(
            chart=chart_name,
            version=chart_version,
            values=openunison_helm_values,
            namespace='openunison',
            skip_await=False,
            repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                repo=chart_url
            ),
        ),
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[openunison_certificate,openunison_k8s_add_client_release],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    raw_secret_data = {
        "K8S_DB_SECRET": secrets.token_urlsafe(64),
        "unisonKeystorePassword": secrets.token_urlsafe(64),

    }
    encoded_secret_data = {
        key: base64.b64encode(value.encode('utf-8')).decode('utf-8')
            for key, value in raw_secret_data.items()
    }

    orchestra_secret_source = k8s.core.v1.Secret(
        "orchestra-secrets-source-"+env,
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="orchestra-secrets-source",
            namespace="openunison"
        ),
        data={
            "K8S_DB_SECRET": encoded_secret_data['K8S_DB_SECRET'],
            "unisonKeystorePassword": encoded_secret_data["unisonKeystorePassword"],
            "OIDC_CLIENT_SECRET": base64.b64encode(client_secret.encode('utf-8')).decode('utf-8') 
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

    orchestra_chart_name = 'orchestra'
    orchestra_chart_version = get_latest_helm_chart_version(index_url,orchestra_chart_name)
    localpath = '/Users/marcboorshtein/git-local/helm-charts';
    openunison_orchestra_release = k8s.helm.v3.Release(
        resource_name='orch-'+env,
        args=k8s.helm.v3.ReleaseArgs(
            chart=localpath + '/' + orchestra_chart_name,
            version=orchestra_chart_version,
            values=openunison_helm_values,
            namespace='openunison',
            #name='orchestra',
            skip_await=False,
            wait_for_jobs=True,
            # repository_opts= k8s.helm.v3.RepositoryOptsArgs(
            #     #repo=chart_url
            #     path=localpath
            # ),

        ),

        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[openunison_operator_release,orchestra_secret_source],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    #pulumi.export("openunison_orchestra_release",openunison_orchestra_release)

    orchesrta_login_portal_helm_values["impersonation"]["orchestra_release_name"] = openunison_orchestra_release.name.apply(lambda name: name)

    orchestra_login_portal_chart_name = 'orchestra-login-portal'
    orchestra_login_portal_chart_version = get_latest_helm_chart_version(index_url,orchestra_login_portal_chart_name)
    openunison_orchestra_login_portal_release = k8s.helm.v3.Release(
        'orchestra-login-portal-'+env,
        k8s.helm.v3.ReleaseArgs(
            chart=orchestra_login_portal_chart_name,
            version=orchestra_login_portal_chart_version,
            values=orchesrta_login_portal_helm_values,
            namespace='openunison',
            skip_await=False,
            wait_for_jobs=True,
            repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                repo=chart_url
            ),

        ),

        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[openunison_orchestra_release],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    orchestra_kube_oidc_proxy_chart_name = 'orchestra-kube-oidc-proxy'
    orchestra_kube_oidc_proxy_chart_version = get_latest_helm_chart_version(index_url,orchestra_kube_oidc_proxy_chart_name)
    openunison_kube_oidc_proxy_release = k8s.helm.v3.Release(
        'orchestra-kube-oidc-proxy-'+env,
        k8s.helm.v3.ReleaseArgs(
            chart=orchestra_kube_oidc_proxy_chart_name,
            version=orchestra_kube_oidc_proxy_chart_version,
            values=orchesrta_login_portal_helm_values,
            namespace='openunison',
            skip_await=False,
            wait_for_jobs=True,
            repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                repo=chart_url
            ),

        ),

        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[openunison_orchestra_login_portal_release],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    

    return [openunison_kube_oidc_proxy_release,openunison_orchestra_release]



    


def deploy_kubernetes_dashboard(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str,env: str):
    # Deploy kubernetes-dashboard via the helm chart
    # Create a Namespace
    dashboard_namespace = k8s.core.v1.Namespace("kubernetes-dashboard-"+env,
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="kubernetes-dashboard"
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

    # Fetch the latest version from the helm chart index
    chart_name = "kubernetes-dashboard"
    chart_index_path = "index.yaml"
    chart_url = "https://kubernetes.github.io/dashboard"
    index_url = f"{chart_url}/{chart_index_path}"
    chart_version = "6.0.8"

    k8s_db_release = k8s.helm.v3.Release(
            'kubernetes-dashboard-'+env,
            k8s.helm.v3.ReleaseArgs(
                chart=chart_name,
                version=chart_version,
                namespace='kubernetes-dashboard',
                skip_await=False,
                repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                    repo=chart_url
                ),
            ),
            opts=pulumi.ResourceOptions(
                provider = k8s_provider,
                depends_on=[dashboard_namespace],
                custom_timeouts=pulumi.CustomTimeouts(
                    create="8m",
                    update="10m",
                    delete="10m"
                )
            )
        )

    return k8s_db_release
