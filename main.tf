resource "kubernetes_namespace_v1" "olm" {
  metadata {
    name = "olm"
  }
}

resource "kubernetes_namespace_v1" "operators" {
  metadata {
    name = "operators"
  }
}

resource "kubernetes_service_account_v1" "olm_operator" {
  metadata {
    name      = "olm-operator-serviceaccount"
    namespace = kubernetes_namespace_v1.olm.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "olm" {
  metadata {
    name = "system:controller:operator-lifecycle-manager"
  }
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
  rule {
    non_resource_urls = ["*"]
    verbs             = ["*"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "olm_operator_binding_olm" {
  metadata {
    name = "olm-operator-binding-olm"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.olm.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.olm_operator.metadata[0].name
    namespace = kubernetes_service_account_v1.olm_operator.metadata[0].namespace
  }
}

resource "kubectl_manifest" "olmconfig_cluster" {
  depends_on = [
    kubernetes_manifest.customresourcedefinition_olmconfigs_operators_coreos_com,
  ]

  yaml_body = yamlencode({
    apiVersion = "operators.coreos.com/v1"
    kind       = "OLMConfig"
    metadata = {
      name = "cluster"
    }
  })
}

resource "kubernetes_deployment_v1" "olm_operator" {
  metadata {
    name      = "olm-operator"
    namespace = kubernetes_namespace_v1.olm.metadata[0].name
    labels = {
      app = "olm-operator"
    }
  }
  spec {
    strategy {
      type = "RollingUpdate"
    }
    replicas = 1
    selector {
      match_labels = {
        app = "olm-operator"
      }
    }
    template {
      metadata {
        labels = {
          app = "olm-operator"
        }
      }
      spec {
        service_account_name = kubernetes_service_account_v1.olm_operator.metadata[0].name
        container {
          name    = "olm-operator"
          command = ["/bin/olm"]
          args = [
            "--namespace",
            "$(OPERATOR_NAMESPACE)",
            "--writeStatusName",
            ""
          ]
          image             = "quay.io/operator-framework/olm:v${local.olm_version}"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 8080
            name           = "metrics"
          }
          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = 8080
              scheme = "HTTP"
            }
          }
          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = 8080
              scheme = "HTTP"
            }
          }
          termination_message_policy = "FallbackToLogsOnError"
          env {
            name = "OPERATOR_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name  = "OPERATOR_NAME"
            value = "olm-operator"
          }
          resources {
            requests = {
              cpu    = "10m"
              memory = "160Mi"
            }
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_deployment_v1" "catalog_operator" {
  metadata {
    name      = "catalog-operator"
    namespace = kubernetes_namespace_v1.olm.metadata[0].name
    labels = {
      app = "catalog-operator"
    }
  }
  spec {
    strategy {
      type = "RollingUpdate"
    }
    replicas = 1
    selector {
      match_labels = {
        app = "catalog-operator"
      }
    }
    template {
      metadata {
        labels = {
          app = "catalog-operator"
        }
      }
      spec {
        service_account_name = kubernetes_service_account_v1.olm_operator.metadata[0].name
        container {
          name    = "catalog-operator"
          command = ["/bin/catalog"]
          args = [
            "-namespace",
            "olm",
            "-configmapServerImage=quay.io/operator-framework/configmap-operator-registry:latest",
            "-util-image",
            "quay.io/operator-framework/olm:v${local.olm_version}"
          ]
          image             = "quay.io/operator-framework/olm:v${local.olm_version}"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 8080
            name           = "metrics"
          }
          liveness_probe {
            http_get {
              path   = "/healthz"
              port   = 8080
              scheme = "HTTP"
            }
          }
          readiness_probe {
            http_get {
              path   = "/healthz"
              port   = 8080
              scheme = "HTTP"
            }
          }
          termination_message_policy = "FallbackToLogsOnError"
          resources {
            requests = {
              cpu    = "10m"
              memory = "80Mi"
            }
          }
        }
        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_cluster_role_v1" "aggregate_olm_edit" {
  metadata {
    name = "aggregate-olm-edit"
    labels = {
      "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
      "rbac.authorization.k8s.io/aggregate-to-edit"  = "true"
    }
  }
  rule {
    api_groups = ["operators.coreos.com"]
    resources  = ["subscriptions"]
    verbs      = ["create", "update", "patch", "delete"]
  }
  rule {
    api_groups = ["operators.coreos.com"]
    resources  = ["clusterserviceversions", "catalogsources", "installplans", "subscriptions"]
    verbs      = ["delete"]
  }
}

resource "kubernetes_cluster_role_v1" "aggregate_olm_view" {
  metadata {
    name = "aggregate-olm-view"
    labels = {
      "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
      "rbac.authorization.k8s.io/aggregate-to-edit"  = "true"
      "rbac.authorization.k8s.io/aggregate-to-view"  = "true"
    }
  }
  rule {
    api_groups = ["operators.coreos.com"]
    resources  = ["clusterserviceversions", "catalogsources", "installplans", "subscriptions", "operatorgroups"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["packages.operators.coreos.com"]
    resources  = ["packagemanifests", "packagemanifests/icon"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubectl_manifest" "operatorgroup_operators_global_operators" {
  depends_on = [
    kubernetes_manifest.customresourcedefinition_operatorgroups_operators_coreos_com,
  ]

  yaml_body = yamlencode({
    apiVersion = "operators.coreos.com/v1"
    kind       = "OperatorGroup"
    metadata = {
      name      = "global-operators"
      namespace = kubernetes_namespace_v1.operators.metadata[0].name
    }
  })
}

resource "kubectl_manifest" "operatorgroup_olm_operators" {
  depends_on = [
    kubernetes_manifest.customresourcedefinition_operatorgroups_operators_coreos_com,
  ]

  yaml_body = yamlencode({
    apiVersion = "operators.coreos.com/v1"
    kind       = "OperatorGroup"
    metadata = {
      name      = "olm-operators"
      namespace = kubernetes_namespace_v1.olm.metadata[0].name
    }
    spec = {
      targetNamespaces = [
        kubernetes_namespace_v1.olm.metadata[0].name
      ]
    }
  })
}

resource "kubectl_manifest" "catalogsource_olm_operatorhubio_catalog" {
  depends_on = [
    kubernetes_manifest.customresourcedefinition_catalogsources_operators_coreos_com,
  ]

  yaml_body = yamlencode({
    apiVersion = "operators.coreos.com/v1alpha1"
    kind       = "CatalogSource"
    metadata = {
      name      = "operatorhubio-catalog"
      namespace = kubernetes_namespace_v1.olm.metadata[0].name
    }
    spec = {
      sourceType  = "grpc"
      image       = "quay.io/operatorhubio/catalog:latest"
      displayName = "Community Operators"
      publisher   = "OperatorHub.io"
      updateStrategy = {
        registryPoll = {
          interval = "60m"
        }
      }
    }
  })
}
