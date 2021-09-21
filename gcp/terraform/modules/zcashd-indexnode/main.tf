resource "google_compute_address" "indexnode" {
  name         = "indexnode-address"
  address_type = "EXTERNAL"
}

resource "google_compute_address" "indexnode_internal" {
  name         = "indexnode-internal-address"
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
}

resource "google_compute_disk" "zcashindexdata" {
  name = var.index_data_disk_name
  #type = "pd-ssd"
  type = "pd-standard"  #want SSD but running into quota issues in region :(
  size = var.data_disk_size
}

resource "google_compute_disk" "zcashparams-indexnode-tmp" {
  name = "${var.params_disk_name}-indexnode-tmp"
  type = "pd-standard"
  snapshot = "${var.params_disk_name}-snapshot-latest"
  size = 2
  count = var.indexnode_count
}

resource "google_compute_instance" "indexnode" {
  name = "zcash-indexnode"
  machine_type = var.instance_type
  #depends_on = [google_compute_disk.zcashdata]

  count = var.indexnode_count

  allow_stopping_for_update = "true"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
      size = var.boot_disk_size
    }
  }

  attached_disk {
    source = var.index_data_disk_name
    device_name = var.index_data_disk_name
  }

  attached_disk {
    source = "${var.params_disk_name}-indexnode-tmp"
    device_name = var.params_disk_name
  }

  network_interface {
    network    = var.network_name
    network_ip = google_compute_address.indexnode_internal.address
    access_config {
      nat_ip = google_compute_address.indexnode.address
    }
  }

  metadata_startup_script = templatefile(
    format("%s/startup.sh", path.module), {
      params_disk_name : var.params_disk_name,
      index_data_disk_name : var.index_data_disk_name,
      gcloud_project : var.project,
      gcloud_region  : var.region,
      gcloud_zone    : var.zone,
      external_ip_address : google_compute_address.indexnode.address
    }
  )

  service_account {
    scopes = var.service_account_scopes
  }

  tags = [
    "indexnode",
  ]

}
