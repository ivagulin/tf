terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

variable "instances" {
  type = any
  default = {
    "vm1" = {
      "ip" = "192.168.100.10"
    }
    "vm2" = {
      "ip" = "192.168.100.11"
    }
    "vm3" = {
      "ip" = "192.168.100.12"
    }
  }
}

data "template_file" "network_config" {
  for_each = var.instances
  template = file("${path.module}/network_config.cfg")
  vars = {
    ip = each.value.ip
  }
}

data "template_file" "user_data" {
  for_each = var.instances
  template = file("${path.module}/cloud_init.yml")
  vars = {
    hostname = each.key
  }
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
resource "libvirt_cloudinit_disk" "commoninit" {
  for_each = var.instances

  name           = format("cloudinit-%s.iso", each.key)
  user_data      = data.template_file.user_data[each.key].rendered
  network_config = data.template_file.network_config[each.key].rendered
}

resource "libvirt_volume" "base" {
  name = "base"
  #source = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  #source = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  #source = "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
  #source = "file:///mnt/win/install/fedora/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
  source = "file:///mnt/win/install/ubuntu/ubuntu-22.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "qcow2" {
  for_each = var.instances

  name   = format("%s.qcow2", each.key) #"vm1.qcow2"
  base_volume_id = libvirt_volume.base.id
  size = 107374182400
}

# Create the machine
resource "libvirt_domain" "domain-ubuntu" {
  for_each = var.instances

  name   = each.key #"vm1"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.commoninit[each.key].id

  network_interface {
    network_name = "network"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "0"
  }

  disk {
    volume_id = libvirt_volume.qcow2[each.key].id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
