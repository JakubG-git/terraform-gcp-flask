#Reserwe external IP
resource "google_compute_address" "external_ip" {
  name = "external-ip"
  region = var.gcp_region
}
#Create a VPC network
resource "google_compute_network" "default" {
  name = "terraform-network"
  auto_create_subnetworks = false
}

#Create a subnet
resource "google_compute_subnetwork" "default" {
  name          = "terraform-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = google_compute_network.default.id
}


#Create a VM instance
# Create a single Compute Engine instance
resource "google_compute_instance" "flask" {
  name         = "flask-vm"
  machine_type = "f1-micro"
  zone         = var.gcp_zone
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # Install Flask
  metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python3-pip rsync; pip install flask;"


  network_interface {
    subnetwork = google_compute_subnetwork.default.id
    access_config {
      # Include this section to give the VM an external IP address
        nat_ip = google_compute_address.external_ip.address
    }
  }
}

resource "google_compute_firewall" "flask" {
  name    = "flask-app-firewall"
  network = google_compute_network.default.id

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }
  source_ranges = ["0.0.0.0/0"]
}
#Get the managed zone and save for later use
data "google_dns_managed_zone" "website_zone" {
    name = var.gcp_dns_zone
}

#Add IP to DNS record (Adding A type record to DNS)
resource "google_dns_record_set" "website_dns" {
    name = "${var.gcp_subdomain}.${data.google_dns_managed_zone.website_zone.dns_name}"
    managed_zone = data.google_dns_managed_zone.website_zone.name
    type = "A"
    ttl = 300
    rrdatas = [google_compute_address.external_ip.address]
}
