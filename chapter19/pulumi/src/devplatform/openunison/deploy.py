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


def deploy_openunison(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str, gitlab_integrated: bool,cert_manager,mysql_release):
    # Initialize Pulumi configuration
    pconfig = pulumi.Config()

    # Deploy the Kubernetes Dashboard 6.0.8
    k8s_db_release = deploy_kubernetes_dashboard(name=name,k8s_provider=k8s_provider,kubernetes_distribution=kubernetes_distribution,project_name=project_name,namespace=namespace)

    # generate openunison namespace
    openunison_namespace = k8s.core.v1.Namespace("openunison",
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
    
    # create a ConfigMap for our "Active Directory" instance
    # deploy "Active Directory"
    ad_cm_manifest_url = 'https://raw.githubusercontent.com/PacktPublishing/Kubernetes-An-Enterprise-Guide-Third-Edition/main/chapter15/user-auth/myvd-book.yaml'
    ad_cm_k8s_yaml = k8s.yaml.ConfigFile("ad_cm", file=ad_cm_manifest_url,opts=pulumi.ResourceOptions(provider = k8s_provider,
            depends_on=[openunison_namespace],
            custom_timeouts=pulumi.CustomTimeouts(
                create="5m",
                update="10m",
                delete="10m"
            )))

    # get the domain suffix and cluster_issuer
    domain_suffix = pconfig.require('openunison.cp.dns_suffix')

    # get the cluster issuer
    cluster_issuer = "enterprise-ca"

    # create the Certificate
    openunison_certificate = CustomResource(
        "ou-tls-certificate",
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
            depends_on=[openunison_namespace,cert_manager],
            custom_timeouts=pulumi.CustomTimeouts(
                create="5m",
                update="10m",
                delete="10m"
            )
        )
    )

    # this is probably the wrong way to do this, but <shrug>
    try:
        k8s_cp_api = config.kube_config.new_client_from_config(pulumi.Config().require("kube.cp.path"))
        k8s_cp_core_api = k8s_client.CoreV1Api(k8s_cp_api)
        k8s_cp_custom_api = k8s_client.CustomObjectsApi(k8s_cp_api)


        cluster_issuer_object = k8s_cp_custom_api.get_cluster_custom_object(group="cert-manager.io",version="v1",plural="clusterissuers",name=cluster_issuer)

        cluster_issuer_ca_secret_name = cluster_issuer_object["spec"]["ca"]["secretName"]

        pulumi.log.info("Loading CA from {}".format(cluster_issuer_ca_secret_name))

        ca_secret = k8s_cp_core_api.read_namespaced_secret(namespace="cert-manager",name=cluster_issuer_ca_secret_name)

        ca_cert = ca_secret.data["tls.crt"]
    except:
        ca_cert = pulumi.Config().get("certmanager.clusterissuer.cert") or "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURFVENDQWZtZ0F3SUJBZ0lVYmtiS2ZRN29ldXJuVHpyeWdIL0dDS0kzNkUwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05aVzUwWlhKd2NtbHpaUzFqWVRBZUZ3MHlNakV4TURjeE5EUTFNakphRncwegpNakV4TURReE5EUTFNakphTUJneEZqQVVCZ05WQkFNTURXVnVkR1Z5Y0hKcGMyVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNucVZ3eVFvMjJyRzZuVVpjU2UvR21WZnI5MEt6Z3V4MDkKNDY4cFNTUWRwRHE5UlRRVU92ZkFUUEJXODF3QlJmUDEvcnlFaHNocnVBS2E5LzVoKzVCL3g4bmN4VFhwbThCNwp2RDdldHY4V3VyeUtQc0lMdWlkT0QwR1FTRVRvNzdBWE03RmZpUk9yMDFqN3c2UVB3dVB2QkpTcDNpa2lDL0RjCnZFNjZsdklFWE43ZFNnRGRkdnV2R1FORFdPWWxHWmhmNUZIVy81ZHJQSHVPOXp1eVVHK01NaTFpUCtSQk1QUmcKSWU2djhCcE9ncnNnZHRtWExhNFZNc1BNKzBYZkQwSDhjU2YvMkg2V1M0LzdEOEF1bG5QSW9LY1krRkxKUEFtMwpJVFI3L2w2UTBJUXVNU3c2QkxLYWZCRm5CVmNUUVNIN3lKZEFKNWdINFZZRHIyamtVWkwzQWdNQkFBR2pVekJSCk1CMEdBMVVkRGdRV0JCU2Y5RDVGS3dISUY3eFdxRi80OG4rci9SVFEzakFmQmdOVkhTTUVHREFXZ0JTZjlENUYKS3dISUY3eFdxRi80OG4rci9SVFEzakFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQQpBNElCQVFCN1BsMjkrclJ2eHArVHhLT3RCZGRLeEhhRTJVRUxuYmlkaFUvMTZRbW51VmlCQVhidUVSSEF2Y0phCm5hb1plY0JVQVJ0aUxYT2poOTFBNkFvNVpET2RETllOUkNnTGI2czdDVVhSKzNLenZWRmNJVFRSdGtTTkxKMTUKZzRoallyQUtEWTFIM09zd1EvU3JoTG9GQndneGJJQ1F5eFNLaXQ0OURrK2V4c3puMUJFNzE2aWlJVmdZT0daTwp5SWF5ekJZdW1Gc3M0MGprbWhsbms1ZW5hYjhJTDRUcXBDZS9xYnZtNXdOaktaVVozamJsM2QxVWVtcVlOdVlWCmNFY1o0UXltQUJZS3k0VkUzVFJZUmJJZGV0NFY2dVlIRjVZUHlFRWlZMFRVZStYVVJaVkFtaU9jcmtqblVIT3gKMWJqelJxSlpMNVR3b0ZDZzVlZUR6dVk0WlRjYwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="

    pulumi.log.info("CA Certificate {}".format(ca_cert))

    return deploy_openunison_charts(ca_cert=ca_cert,k8s_provider=k8s_provider,kubernetes_distribution=kubernetes_distribution,project_name=project_name,namespace=namespace,domain_suffix=domain_suffix,openunison_certificate=openunison_certificate,config=pconfig,db_release=k8s_db_release,gitlab_integrated=gitlab_integrated,openunison_namespace=openunison_namespace,mysql_release=mysql_release)



def deploy_openunison_charts(ca_cert,k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str,domain_suffix: str,openunison_certificate,config,db_release,gitlab_integrated,openunison_namespace,mysql_release):


    openunison_helm_values = {
        "image":"docker.io/tremolosecurity/betas:1.0.41",
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
        "k8s_cluster_name": "openunison-cp",
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
            "name": "ldaps",
            "pem_b64": "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURlekNDQW1PZ0F3SUJBZ0lFR2owUUZ6QU5CZ2txaGtpRzl3MEJBUXNGQURCdE1Rd3dDZ1lEVlFRR0V3TmsKWlhZeEREQUtCZ05WQkFnVEEyUmxkakVNTUFvR0ExVUVCeE1EWkdWMk1Rd3dDZ1lEVlFRS0V3TmtaWFl4RERBSwpCZ05WQkFzVEEyUmxkakVsTUNNR0ExVUVBeE1jWVhCaFkyaGxaSE11WVdOMGFYWmxaR2x5WldOMGIzSjVMbk4yCll6QWdGdzB5TVRBM01EVXdNRFV6TWpoYUdBOHlNVEl4TURZeE1UQXdOVE15T0Zvd2JURU1NQW9HQTFVRUJoTUQKWkdWMk1Rd3dDZ1lEVlFRSUV3TmtaWFl4RERBS0JnTlZCQWNUQTJSbGRqRU1NQW9HQTFVRUNoTURaR1YyTVF3dwpDZ1lEVlFRTEV3TmtaWFl4SlRBakJnTlZCQU1USEdGd1lXTm9aV1J6TG1GamRHbDJaV1JwY21WamRHOXllUzV6CmRtTXdnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFDNlNVQUJRSUZkYnRwZGJ3WEEKT05ablJVQlFBMEVyK2hWYmkxUHNWSnNaaUlGZjhJRC8xZXBPN0M4QlViVXN1U3dWWkc5ZEJIV3o0RFBwWUUrKwp2dmxrTEs1cEdiTnJQbDdFd241clJLRE5PeVR5ZUNBcFMzSVNsRW1iaVNQUjBuYXd5ckpoNjhQQ0I1bURSNTNmCmh1bFhPQ0dTd3ZNN2RwM2RPc3lFQmRlVkw3aTFnbkJNYi9wN05YdTN5WmlWaDlpS3pqaENrZndqL0VsNTZaUHEKYmsvOGtQN0xBdTFvZGJWTkZGSUx5clB6SFBFU3I3N0preHcvKytPTmhtblA2UFBiU3FtRm0rcUVEYWhQanBFZgpscUdaY3BsOEZ0VXBzTG5JK3B4blI5eWU5ZUNpVDVuaDhlTEhobkVFNzFpVE1rb2xrSHdxSm5xV1R3ZlF2b1g5CkM2SERBZ01CQUFHaklUQWZNQjBHQTFVZERnUVdCQlRjOGlDU055NnhSM2M5OU1aYkZUODgzREs1V0RBTkJna3EKaGtpRzl3MEJBUXNGQUFPQ0FRRUFOMEkwZnJDSzdYNGRHRmpGLzFpb3czUUwvbTcwemVIemlQVVFFUUdONXBFMwpyMlZZL0ZHWGdNV0tFSXpHa2hMZW5CUXRxRE5Pbm4vL1JjK0Y2anM1RkNOVXhaT2V4ekl2aElhY0M4YUhzRWpFClRnclI5OWNqUVdsdzFhSVF0YUhkSmVqYXdYcU50YU1FMSt4RlJBQTNCWUF1T3BveW9wQ0NoMXdJaTEvQk84TlQKVmFaancxQU8xd1ZUaTJ3SUtCSUp1Z0N2T0dYZEt3YzBuL0I4bzRRQkpScklRZEJnbzJVNjFBbkMxaWM4b0d3RwpxekN1V0dDenZjam9xNWFNcTliS0YyNHBQaDR3cWZMZnZGdWNsYmFIUlBiSmpxT3l0V3gzczhNV0lvRUNzdlhLCnhIYmJvSnU0c1AwLzRBMGQ4K25OOXI1MU8xalFaWHd0b3hwenFTV2ZlZz09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0="
        }
        ],
        "monitoring": {
            "prometheus_service_account": "system:serviceaccount:monitoring:prometheus-k8s"
        },
        
        
        # TODO: Active Directory
        "active_directory" :{
            "base": "DC=domain,DC=com",
            "host": "apacheds.activedirectory.svc",
            "port": 10636,
            "bind_dn": "cn=ou_svc_account,ou=Users,DC=domain,DC=com",
            "con_type": "ldaps",
            "srv_dns": False
        }
        ,
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
        "replicas": 1,
        "non_secret_data": {
            "K8S_DB_SSO": "oidc",
            "PROMETHEUS_SERVICE_ACCOUNT": "system:serviceaccount:monitoring:prometheus-k8s",
            "SHOW_PORTAL_ORGS": "true",
            "K8S_DEPLOYMENT_NAME": "Developer Portal Control Plane",
            "K8S_DEPLOYMENT_DESC": "Runs control plane systems for our internal developer portal",
            "GIT_USERNAME": "openunison",
            "GIT_EMAIL": "openunison@nodomain.io"
        },
        "secrets": [

        ],
        "enable_provisioning": True,
        "use_standard_jit_workflow": False,
        "activemq_use_pvc": True,
        "groups": {
            "areJson": True
        },
        "role_attribute": "portalGroups",
        "naas": {
            "forms": {
                "new_namespace": {
                    "use_default": False,
                },
            },
            "groups": {
                "internal": {
                    "enabled": True
                },
                "external": {
                    "enabled": False
                },
                "default": [
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
                        "binding": "admins",
                        "name": "admin",
                        "type": "ClusterRole"
                    }
                    ],
                    "description": "Manage operations of the $nameSpace$ project, responsible for day to day operations",
                    "external": {
                    "errorMessage": "Invalid operations group",
                    "fieldName": "operationsGroup",
                    "label": "Operations Group"
                    },
                    "name": "operations",
                    "workflow": {
                    "approvalLabel": "Approve operations, $name$",
                    "displayLabel": "$name$ Operations",
                    "emailTemplate": "Approve operations for $name$",
                    "label": "project operation",
                    "org": {
                        "description": "Project Operations",
                        "label": "Operations"
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
                        "binding": "developers",
                        "name": "developer",
                        "type": "ClusterRole"
                    }
                    ],
                    "description": "Developer for project $nameSpace$",
                    "external": {
                    "errorMessage": "Invalid developer group",
                    "fieldName": "developerGroup",
                    "label": "Developer Group"
                    },
                    "name": "developer",
                    "workflow": {
                    "approvalLabel": "Approve developer access for project $name$",
                    "displayLabel": "$name$ Developer",
                    "emailTemplate": "Approve developer access to project $name$",
                    "label": "namespace developer",
                    "org": {
                        "description": "Project Developer",
                        "label": "Developers"
                    },
                    "userNotification": {
                        "message": "Your access has been approved",
                        "subject": "Developer access to project $name$ approved"
                    }
                    }
                }
                ]
            },
            
        },
        "apps":[],
        # "post_jit_workflow": "jit-gitlab",
        },
        "database": {
            "hibernate_dialect": "org.hibernate.dialect.MySQLDialect",
            "quartz_dialect": "org.quartz.impl.jdbcjobstore.StdJDBCDelegate",
            "driver": "com.mysql.jdbc.Driver",
            "url": "jdbc:mysql://mysql.mysql.svc:3306/unison",
            "user": "root",
            "validation": "SELECT 1"
        },
        "smtp": {
            "host": "blackhole.blackhole.svc.cluster.local",
            "port": 1025,
            "user": "none",
            "from": "donotreply@domain.com",
            "tls": False
        }
    }

    if (gitlab_integrated):
        openunison_helm_values["openunison"]["post_jit_workflow"] = "jit-gitlab"
    

    orchesrta_login_portal_helm_values = json.loads(json.dumps(openunison_helm_values))
    orchestra_cm_helm_values = json.loads(json.dumps(openunison_helm_values))
    openunison_helm_values["dashboard"]["service_name"] = db_release.name.apply(lambda name: name)
    openunison_helm_values["dashboard"]["cert_name"] = db_release.name.apply(lambda name: name + "-certs")
    orchesrta_login_portal_helm_values["dashboard"]["service_name"] = db_release.name.apply(lambda name: name)
    orchestra_cm_helm_values["dashboard"]["service_name"] = db_release.name.apply(lambda name: name)


    # Fetch the latest version from the helm chart index
    chart_name = "openunison-operator"
    chart_index_path = "index.yaml"
    chart_url = "https://nexus.tremolo.io/repository/helm"
    index_url = f"{chart_url}/{chart_index_path}"
    chart_version = get_latest_helm_chart_version(index_url,chart_name)

    openunison_operator_release = k8s.helm.v3.Release(
        'openunison-operator',
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
            depends_on=[openunison_certificate],
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
        "orchestra-secrets-source",
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="orchestra-secrets-source",
            namespace="openunison"
        ),
        data={
            "K8S_DB_SECRET": encoded_secret_data['K8S_DB_SECRET'],
            "unisonKeystorePassword": encoded_secret_data["unisonKeystorePassword"],
            "AD_BIND_PASSWORD": base64.b64encode('start123'.encode('utf-8')).decode('utf-8') ,
            "OU_JDBC_PASSWORD": base64.b64encode('start123'.encode('utf-8')).decode('utf-8') ,
            "SMTP_PASSWORD": base64.b64encode('start123'.encode('utf-8')).decode('utf-8') ,
        },
        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            retain_on_delete=False,
            delete_before_replace=True,
            depends_on=[openunison_namespace],
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
        resource_name='orchestra',
        args=k8s.helm.v3.ReleaseArgs(
            chart=orchestra_chart_name,
            #chart=localpath + '/' + orchestra_chart_name,
            version=orchestra_chart_version,
            values=openunison_helm_values,
            namespace='openunison',
            #name='orchestra',
            skip_await=False,
            wait_for_jobs=True,
            repository_opts= k8s.helm.v3.RepositoryOptsArgs(
                repo=chart_url
                #path=localpath
            ),

        ),

        opts=pulumi.ResourceOptions(
            provider = k8s_provider,
            depends_on=[openunison_operator_release,orchestra_secret_source,mysql_release],
            custom_timeouts=pulumi.CustomTimeouts(
                create="8m",
                update="10m",
                delete="10m"
            )
        )
    )

    #pulumi.export("openunison_orchestra_release",openunison_orchestra_release)

    orchesrta_login_portal_helm_values["impersonation"]["orchestra_release_name"] = openunison_orchestra_release.name.apply(lambda name: name)
    orchestra_cm_helm_values["impersonation"]["orchestra_release_name"] = openunison_orchestra_release.name.apply(lambda name: name)
    orchestra_login_portal_chart_name = 'orchestra-login-portal'
    orchestra_login_portal_chart_version = get_latest_helm_chart_version(index_url,orchestra_login_portal_chart_name)
    openunison_orchestra_login_portal_release = k8s.helm.v3.Release(
        'orchestra-login-portal',
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
        'orchestra-kube-oidc-proxy',
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

    
    
    orchestra_cm_helm_values["openunison"]["orchestra_login_portal_name"] = openunison_orchestra_login_portal_release.name.apply(lambda name: name)

    orchestra_cluster_management_chart_name = 'openunison-k8s-cluster-management'
    orchestra_cluster_management_chart_version = get_latest_helm_chart_version(index_url,orchestra_cluster_management_chart_name)
    openunison_cluster_management_release = k8s.helm.v3.Release(
        'orchestra-cluster-management',
        k8s.helm.v3.ReleaseArgs(
            chart=orchestra_cluster_management_chart_name,
            #chart=localpath + '/' + orchestra_cluster_management_chart_name,
            version=orchestra_cluster_management_chart_version,
            values=orchestra_cm_helm_values,
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

    return [openunison_cluster_management_release,openunison_orchestra_release,openunison_orchestra_login_portal_release]



    


def deploy_kubernetes_dashboard(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str):
    # Deploy kubernetes-dashboard via the helm chart
    # Create a Namespace
    dashboard_namespace = k8s.core.v1.Namespace("kubernetes-dashboard",
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
            'kubernetes-dashboard',
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
