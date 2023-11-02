package k8senforceingress

violation[{"msg":msg,"details":{}}] {
    missingIngressLabel
    msg := "Missing label allowingress: \"true\""
}

missingIngressLabel {
    data.inventory.cluster["v1"].Namespace["v1"][input.review.object.metadata.namespace].metadata.labels["allowingress"] != "true"
}