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

resource "google_os_config_os_policy_assignment" "apache_install" {
  name        = "apache-install"
  project     = var.project_id
  description = "Install Apache on existing VM"
  location    = "us-central1-a"

  instance_filter {
    all = false
    inclusion_labels {
      labels = {
        env = "production"
      }
    }
    inventories {
      os_short_name = "debian"
    }
  }
  os_policies {
    id   = "install-apache"
    mode = "ENFORCEMENT"
    resource_groups {
      resources {
        id = "install-apache-pkg"
        pkg {
          desired_state = "INSTALLED"
          name          = "apache2"
        }
      }
    }
  }

  rollout {
    disruption_budget {
      fixed = 1
    }
    min_wait_duration = "60s"
  }
}