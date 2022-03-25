resource "kubectl_manifest" "clusterserviceversion_olm_packageserver" {
  depends_on = [
    kubernetes_manifest.customresourcedefinition_clusterserviceversions_operators_coreos_com,
  ]

  yaml_body = yamlencode({
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "ClusterServiceVersion"
    "metadata" = {
      "labels" = {
        "olm.version" = "v${local.olm_version}"
      }
      "name"      = "packageserver"
      "namespace" = kubernetes_namespace_v1.olm.metadata[0].name
    }
    "spec" = {
      "apiservicedefinitions" = {
        "owned" = [
          {
            "containerPort"  = 5443
            "deploymentName" = "packageserver"
            "description"    = "A PackageManifest is a resource generated from existing CatalogSources and their ConfigMaps"
            "displayName"    = "PackageManifest"
            "group"          = "packages.operators.coreos.com"
            "kind"           = "PackageManifest"
            "name"           = "packagemanifests"
            "version"        = "v1"
          },
        ]
      }
      "description" = "Represents an Operator package that is available from a given CatalogSource which will resolve to a ClusterServiceVersion."
      "displayName" = "Package Server"
      "install" = {
        "spec" = {
          "clusterPermissions" = [
            {
              "rules" = [
                {
                  "apiGroups" = [
                    "authorization.k8s.io",
                  ]
                  "resources" = [
                    "subjectaccessreviews",
                  ]
                  "verbs" = [
                    "create",
                    "get",
                  ]
                },
                {
                  "apiGroups" = [
                    "",
                  ]
                  "resources" = [
                    "configmaps",
                  ]
                  "verbs" = [
                    "get",
                    "list",
                    "watch",
                  ]
                },
                {
                  "apiGroups" = [
                    "operators.coreos.com",
                  ]
                  "resources" = [
                    "catalogsources",
                  ]
                  "verbs" = [
                    "get",
                    "list",
                    "watch",
                  ]
                },
                {
                  "apiGroups" = [
                    "packages.operators.coreos.com",
                  ]
                  "resources" = [
                    "packagemanifests",
                  ]
                  "verbs" = [
                    "get",
                    "list",
                  ]
                },
              ]
              "serviceAccountName" = kubernetes_service_account_v1.olm_operator.metadata[0].name
            },
          ]
          "deployments" = [
            {
              "name" = "packageserver"
              "spec" = {
                "replicas" = 2
                "selector" = {
                  "matchLabels" = {
                    "app" = "packageserver"
                  }
                }
                "strategy" = {
                  "rollingUpdate" = {
                    "maxSurge"       = 1
                    "maxUnavailable" = 1
                  }
                  "type" = "RollingUpdate"
                }
                "template" = {
                  "metadata" = {
                    "labels" = {
                      "app" = "packageserver"
                    }
                  }
                  "spec" = {
                    "containers" = [
                      {
                        "command" = [
                          "/bin/package-server",
                          "-v=4",
                          "--secure-port",
                          "5443",
                          "--global-namespace",
                          kubernetes_namespace_v1.olm.metadata[0].name,
                        ]
                        "image"           = "quay.io/operator-framework/olm:v${local.olm_version}"
                        "imagePullPolicy" = "Always"
                        "livenessProbe" = {
                          "httpGet" = {
                            "path"   = "/healthz"
                            "port"   = 5443
                            "scheme" = "HTTPS"
                          }
                        }
                        "name" = "packageserver"
                        "ports" = [
                          {
                            "containerPort" = 5443
                          },
                        ]
                        "readinessProbe" = {
                          "httpGet" = {
                            "path"   = "/healthz"
                            "port"   = 5443
                            "scheme" = "HTTPS"
                          }
                        }
                        "resources" = {
                          "requests" = {
                            "cpu"    = "10m"
                            "memory" = "50Mi"
                          }
                        }
                        "securityContext" = {
                          "runAsUser" = 1000
                        }
                        "terminationMessagePolicy" = "FallbackToLogsOnError"
                        "volumeMounts" = [
                          {
                            "mountPath" = "/tmp"
                            "name"      = "tmpfs"
                          },
                        ]
                      },
                    ]
                    "nodeSelector" = {
                      "kubernetes.io/os" = "linux"
                    }
                    "serviceAccountName" = kubernetes_service_account_v1.olm_operator.metadata[0].name
                    "volumes" = [
                      {
                        "emptyDir" = {}
                        "name"     = "tmpfs"
                      },
                    ]
                  }
                }
              }
            },
          ]
        }
        "strategy" = "deployment"
      }
      "installModes" = [
        {
          "supported" = true
          "type"      = "OwnNamespace"
        },
        {
          "supported" = true
          "type"      = "SingleNamespace"
        },
        {
          "supported" = true
          "type"      = "MultiNamespace"
        },
        {
          "supported" = true
          "type"      = "AllNamespaces"
        },
      ]
      "keywords" = [
        "packagemanifests",
        "olm",
        "packages",
      ]
      "links" = [
        {
          "name" = "Package Server"
          "url"  = "https://github.com/operator-framework/operator-lifecycle-manager/tree/master/pkg/package-server"
        },
      ]
      "maintainers" = [
        {
          "email" = "openshift-operators@redhat.com"
          "name"  = "Red Hat"
        },
      ]
      "maturity"       = "alpha"
      "minKubeVersion" = "1.11.0"
      "provider" = {
        "name" = "Red Hat"
      }
      "version" = "v${local.olm_version}"
    }
  })
}
