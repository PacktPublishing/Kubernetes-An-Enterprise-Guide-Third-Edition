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
import pulumi_gitlab as gitlab

def initialize_gitlab():
    # create a "group" (namespace) in gitlab
    cluster_ops_group = gitlab.Group("cluster-operations",path="cluster-operations",request_access_enabled=False)

    # create group that maps to cluster admins
    cluster_administrators_group = gitlab.Group("k8s-cluster-k8s-administrators",path="k8s-cluster-k8s-administrators",request_access_enabled=False)

    