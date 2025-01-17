resource "google_compute_instance" "vm_instance" {
  name         = "cloudroot7"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  labels = {
    env = "production"
  }

  metadata_startup_script = <<-EOF
     #!/bin/bash
     sudo apt-get update 
     sudo apt-get install -y google-osconfig-agent
   EOF

}

# resource "google_os_config_os_policy_assignment" "apache_install" {
#   name        = "apache-install"
#   project     = var.project_id
#   description = "Install Apache on existing VM"
#   location    = "us-central1-a"

#   instance_filter {
#     all = false
#     inclusion_labels {
#       labels = {
#         env = "production"
#       }
#     }
#     inventories {
#       os_short_name = "debian"
#     }
#   }
#   os_policies {
#     id   = "install-apache"
#     mode = "ENFORCEMENT"
#     resource_groups {
#       resources {
#         id = "install-apache-pkg"
#         pkg {
#           desired_state = "INSTALLED"
#           name          = "apache2"
#         }
#       }
#     }
#   }

#   rollout {
#     disruption_budget {
#       fixed = 1
#     }
#     min_wait_duration = "60s"
#   }
# }

resource "google_os_config_os_policy_assignment" "install-google-cloud-ops-agent" {
  description = "Install the ops agent on hosts"
  location    = var.zone
  name        = "install-google-cloud-ops-agent"
  project     = var.project

  instance_filter {
    all = false
    inventories {
      os_short_name = "ubuntu"
      os_version    = "22.04"
    }
  }

  os_policies {
    allow_no_resource_group_match = false
    description                   = "Copy file from GCS bucket to local path"
    id                            = "install-and-configure-ops-agent"
    mode                          = "ENFORCEMENT"

    resource_groups {
      resources {
        id = "install-package"
        exec {
          enforce {
            args        = []
            interpreter = "SHELL"
            script      = "apt-get install -y apache2 && exit 100"
          }
          validate {
            args        = []
            interpreter = "SHELL"
            script      = "if systemctl is-active google-cloud-ops-agent-opentelemetry-collector; then exit 100; else exit 101; fi"
          }
        }
      }
    }
  }

  rollout {
    min_wait_duration = "60s"
    disruption_budget {
      fixed   = 0
      percent = 100
    }
  }

  timeouts {}
}