resource "google_project_service" "osconfig" {
  project = var.project_id
  service = "osconfig.googleapis.com"
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "manger" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"
}

resource "time_sleep" "wait_project_init" {
  create_duration = "90s"

  depends_on = [google_project_service.osconfig, google_project_service.compute, google_project_service.manger, google_project_service.iam]
}

resource "google_compute_project_metadata_item" "osconfig" {
  project = var.project_id
  key     = "enable-osconfig"
  value   = "TRUE"
}

resource "google_compute_project_metadata_item" "enable_osconfig" {
  project = var.project_id
  key     = "enable-guest-attributes"
  value   = "TRUE"
}

data "google_compute_default_service_account" "default" {
  project = var.project_id
}


resource "google_project_iam_member" "osconfig_agent_role" {
  project = var.project_id
  role    = "roles/osconfig.guestPolicyAdmin"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "compute_instance_admin_role" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}


resource "google_compute_instance" "vm_instance" {
  name         = "cloudroot7"
  machine_type = "e2-micro"
  zone         = var.zone

  allow_stopping_for_update = true

  metadata = {
    enable-guest-attributes = "TRUE"
    enable-osconfig         = "TRUE"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  labels = {
    env = "production"
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = <<-EOF
     #!/bin/bash
     sudo apt-get update 
     sudo apt-get install -y google-osconfig-agent
     sudo systemctl enable google-osconfig-agent
     sudo systemctl start google-osconfig-agent
   EOF
  depends_on              = [time_sleep.wait_project_init]
}


resource "google_os_config_os_policy_assignment" "os_policy_assignment" {
  name        = "apache-os-policy-assignment"
  location    = var.zone
  description = "OS policy assignment to install Apache on Ubuntu"
  rollout {
    disruption_budget {
      fixed = 1
    }
    min_wait_duration = "60s"
  }
  instance_filter {
    all = true
  }
  os_policies {
    id          = "apache-policy"
    mode        = "ENFORCEMENT"
    description = "Policy to install Apache on Ubuntu"
    resource_groups {
      resources {
        id = "install-package"
        pkg {
          desired_state = "INSTALLED"
          apt {
            name = "apache2"
          }
        }
      }
    }
  }
}