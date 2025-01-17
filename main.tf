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

resource "google_os_config_os_policy_assignment" "install-google-cloud-ops-agent" {
  description = "Install the ops agent on hosts"
  location    = var.zone
  name        = "install-google-cloud-ops-agent"
  project     = var.project_id

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
            script      = <<EOT
             if dpkg -l | grep -q apache2; then
              exit 0
            else
              exit 1
            fi
            EOT
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