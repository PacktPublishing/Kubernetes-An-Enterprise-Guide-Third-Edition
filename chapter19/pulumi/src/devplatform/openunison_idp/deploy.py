import pulumi
from pulumi_kubernetes import helm, Provider
import pulumi_kubernetes as k8s
from pulumi_kubernetes.apiextensions.CustomResource import CustomResource
from ...lib.helm_chart_versions import get_latest_helm_chart_version
import logging
import base64

def deploy_openunison_idp(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str, orchestra_cluster_management_release,openunison_login_portal,orchestra_release):
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
        depends_on=[openunison_login_portal],
        custom_timeouts=pulumi.CustomTimeouts(
            create="10m",
            update="10m",
            delete="10m"
        )
    )
    )

    # create the Secret for storing the MySQL passwords


    

    gitlab_token_secret = k8s.core.v1.Secret(
    "mysql-target",
    metadata= k8s.meta.v1.ObjectMetaArgs(
        name="mysql-passwords",
        namespace="openunison"
    ),
    data={
        "dev":   base64.b64encode("start123".encode('utf-8')).decode('utf-8')   ,
        "prod":   base64.b64encode("start123".encode('utf-8')).decode('utf-8')   ,
    },
    opts=pulumi.ResourceOptions(
        provider = k8s_provider,
        retain_on_delete=False,
        delete_before_replace=True,
        depends_on=[openunison_login_portal],
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
        "harbor_url": "https://harbor." + dns_suffix,
        "gitlab_ssh_host": "gitlab-ssh." + dns_suffix,
        "openunison": {
            "orchestra_login_portal_name": openunison_login_portal.name.apply(lambda name: name),
            "orchestra_name": orchestra_release.name.apply(lambda name: name)
        },
        "dev_dns_suffix": config.require("openunison.dev.dns_suffix"),
        "prod_dns_suffix": config.require("openunison.prod.dns_suffix"),
        "cp_dns_suffix": config.require("openunison.cp.dns_suffix"),
        "vcluster": {
            "job_image": "ghcr.io/mlbiam/vcluster-onboard:1.0.0"
        },
        "cacert": config.get("certmanager.clusterissuer.cert") or "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURFVENDQWZtZ0F3SUJBZ0lVYmtiS2ZRN29ldXJuVHpyeWdIL0dDS0kzNkUwd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0dERVdNQlFHQTFVRUF3d05aVzUwWlhKd2NtbHpaUzFqWVRBZUZ3MHlNakV4TURjeE5EUTFNakphRncwegpNakV4TURReE5EUTFNakphTUJneEZqQVVCZ05WQkFNTURXVnVkR1Z5Y0hKcGMyVXRZMkV3Z2dFaU1BMEdDU3FHClNJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0FvSUJBUUNucVZ3eVFvMjJyRzZuVVpjU2UvR21WZnI5MEt6Z3V4MDkKNDY4cFNTUWRwRHE5UlRRVU92ZkFUUEJXODF3QlJmUDEvcnlFaHNocnVBS2E5LzVoKzVCL3g4bmN4VFhwbThCNwp2RDdldHY4V3VyeUtQc0lMdWlkT0QwR1FTRVRvNzdBWE03RmZpUk9yMDFqN3c2UVB3dVB2QkpTcDNpa2lDL0RjCnZFNjZsdklFWE43ZFNnRGRkdnV2R1FORFdPWWxHWmhmNUZIVy81ZHJQSHVPOXp1eVVHK01NaTFpUCtSQk1QUmcKSWU2djhCcE9ncnNnZHRtWExhNFZNc1BNKzBYZkQwSDhjU2YvMkg2V1M0LzdEOEF1bG5QSW9LY1krRkxKUEFtMwpJVFI3L2w2UTBJUXVNU3c2QkxLYWZCRm5CVmNUUVNIN3lKZEFKNWdINFZZRHIyamtVWkwzQWdNQkFBR2pVekJSCk1CMEdBMVVkRGdRV0JCU2Y5RDVGS3dISUY3eFdxRi80OG4rci9SVFEzakFmQmdOVkhTTUVHREFXZ0JTZjlENUYKS3dISUY3eFdxRi80OG4rci9SVFEzakFQQmdOVkhSTUJBZjhFQlRBREFRSC9NQTBHQ1NxR1NJYjNEUUVCQ3dVQQpBNElCQVFCN1BsMjkrclJ2eHArVHhLT3RCZGRLeEhhRTJVRUxuYmlkaFUvMTZRbW51VmlCQVhidUVSSEF2Y0phCm5hb1plY0JVQVJ0aUxYT2poOTFBNkFvNVpET2RETllOUkNnTGI2czdDVVhSKzNLenZWRmNJVFRSdGtTTkxKMTUKZzRoallyQUtEWTFIM09zd1EvU3JoTG9GQndneGJJQ1F5eFNLaXQ0OURrK2V4c3puMUJFNzE2aWlJVmdZT0daTwp5SWF5ekJZdW1Gc3M0MGprbWhsbms1ZW5hYjhJTDRUcXBDZS9xYnZtNXdOaktaVVozamJsM2QxVWVtcVlOdVlWCmNFY1o0UXltQUJZS3k0VkUzVFJZUmJJZGV0NFY2dVlIRjVZUHlFRWlZMFRVZStYVVJaVkFtaU9jcmtqblVIT3gKMWJqelJxSlpMNVR3b0ZDZzVlZUR6dVk0WlRjYwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="

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