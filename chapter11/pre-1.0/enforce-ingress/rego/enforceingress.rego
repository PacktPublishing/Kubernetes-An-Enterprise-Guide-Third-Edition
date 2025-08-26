package k8senforceingress

violation[{"msg":msg,"details":{}}] {
    missingIngressLabel
    msg := "Missing label allowingress: \"true\""
}

missingIngressLabel {
    data.inventory.cluster["v1"].Namespace[input.review.object.metadata.namespace].metadata.labels["allowingress"] != "true"
}

missingIngressLabel {
    not data.inventory.cluster["v1"].Namespace[input.review.object.metadata.namespace].metadata.labels["allowingress"]
}