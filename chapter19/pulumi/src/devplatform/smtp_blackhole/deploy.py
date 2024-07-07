import pulumi
from pulumi_kubernetes import helm, Provider
import pulumi_kubernetes as k8s
from pulumi_kubernetes.apiextensions.CustomResource import CustomResource
from ...lib.helm_chart_versions import get_latest_helm_chart_version
import logging

def deploy_smtp_blackhole(name: str, k8s_provider: Provider, kubernetes_distribution: str, project_name: str, namespace: str):
    logging.info("in deploy_smtp_blackhole")
    config = pulumi.Config()
    # Create a Namespace
    blackhole_namespace = k8s.core.v1.Namespace("blackhole_namespace",
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="blackhole"
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

    blackhole_deployment = k8s.apps.v1.Deployment(
        "blackhole-deployment",
        metadata= k8s.meta.v1.ObjectMetaArgs(
            name="blackhole",
            namespace="blackhole",
            labels={
                "app":"blackhole"
            }
        ),
        spec= {
            "replicas":1,
            "selector":{
                "matchLabels": {
                    "app": "blackhole"
                }
            },
            "template":{
                "metadata": {
                    "labels":{
                        "app":"blackhole"
                    }
                },
                "spec": {
                    "containers": [
                        {
                            "name":"smtp-blackhole",
                            "image": "tremolosecurity/smtp-blackhole"
                        }
                    ]
                }
            }
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

    blackole_service = k8s.core.v1.Service("blackhole-service",
                                       metadata= k8s.meta.v1.ObjectMetaArgs(
                                            name="blackhole",
                                            namespace="blackhole",
                                            labels={
                                                "app":"blackhole"
                                            }
                                        ),
                                        spec={
                                            "ports": [
                                                {
                                                    "protocol": "TCP",
                                                    "port": 1025,
                                                    "targetPort": 1025
                                                }
                                            ],
                                            "selector": {
                                                "app": "blackhole"
                                            },
                                            "type": "ClusterIP"
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
                                        ))

    