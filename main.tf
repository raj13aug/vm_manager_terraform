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
  value   = "true"
}

resource "google_compute_project_metadata_item" "enable_osconfig" {
  project = var.project_id
  key     = "enable-guest-attributes"
  value   = "true"
}

resource "google_compute_instance" "vm_instance" {
  name         = "cloudroot7"
  machine_type = "e2-micro"
  zone         = var.zone

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

  metadata_startup_script = <<-EOF
     #!/bin/bash
     sudo apt-get update 
     sudo apt-get install -y google-osconfig-agent
     sudo systemctl enable google-osconfig-agent
     sudo systemctl start google-osconfig-agent
   EOF
  depends_on              = [time_sleep.wait_project_init]
}


data "google_compute_default_service_account" "default" {
  project = var.project_id
}


resource "google_project_iam_member" "osconfig" {
  project = var.project_id
  role    = "roles/osconfig.guestPolicyAdmin"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "iam_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}


# resource "google_compute_instance_iam_member" "vm_instance_admin" {
#   project       = var.project_id
#   zone          = var.zone
#   instance_name = google_compute_instance.vm_instance.name
#   role          = "roles/compute.instanceAdmin.v1"
#   member        = "serviceAccount:${data.google_compute_default_service_account.default.email}"
# }


# resource "google_os_config_os_policy_assignment" "install-google-cloud-ops-agent" {
#   description = "Install the ops agent on hosts"
#   location    = var.zone
#   name        = "install-google-cloud-ops-agent"
#   project     = var.project_id

#   instance_filter {
#     all = false
#     inclusion_labels {
#       labels = {
#         env = "production"
#       }
#     }
#     inventories {
#       os_short_name = "ubuntu"
#       os_version    = "22.04"
#     }
#   }

#   os_policies {
#     allow_no_resource_group_match = false
#     description                   = "install and confiure apache"
#     id                            = "install-apache"
#     mode                          = "ENFORCEMENT"

#     resource_groups {
#       resources {
#         id = "install-package"
#         exec {
#           enforce {
#             args        = []
#             interpreter = "SHELL"
#             script      = "apt-get install -y apache2 && exit 100"
#           }
#           validate {
#             args        = []
#             interpreter = "SHELL"
#             script      = <<EOT
#              if dpkg -l | grep -q apache2; then
#               exit 0
#             else
#               exit 1
#             fi
#             EOT
#           }
#         }
#       }
#     }
#   }

#   rollout {
#     min_wait_duration = "60s"
#     disruption_budget {
#       fixed   = 0
#       percent = 100
#     }
#   }

#   timeouts {}
#   depends_on = [time_sleep.wait_project_init]
# }