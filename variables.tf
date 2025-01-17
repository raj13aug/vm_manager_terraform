variable "project_id" {
  type        = string
  description = "project id"
  default     = "testing-last-446414"
}

variable "region" {
  type        = string
  description = "Region of policy "
  default     = "us-central1"
}

variable "zone" {
  description = "The zone of the GCP project"
  type        = string
  default     = "us-central1-a"
}

variable "gcp_service_list" {
  type        = list(string)
  description = "The list of apis necessary for the project"
  default     = []
}