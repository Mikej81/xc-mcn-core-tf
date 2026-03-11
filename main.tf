locals {
  site_mesh_label_expr = "${var.site_mesh_label_key} = ${var.site_mesh_label_value}"
}

# --------------------------------------------------------------------------
# Known Label — shared namespace
# Defines the label key + value that CE sites use to join the mesh.
# --------------------------------------------------------------------------

resource "volterra_known_label_key" "site_mesh" {
  key       = var.site_mesh_label_key
  namespace = "shared"
}

resource "volterra_known_label" "site_mesh" {
  key       = var.site_mesh_label_key
  value     = var.site_mesh_label_value
  namespace = "shared"

  depends_on = [volterra_known_label_key.site_mesh]
}

# --------------------------------------------------------------------------
# Virtual Site — shared namespace
# CE-type virtual site that selects sites carrying the mesh label.
# --------------------------------------------------------------------------

resource "volterra_virtual_site" "mesh" {
  name      = var.mesh_name
  namespace = "shared"

  site_selector {
    expressions = [local.site_mesh_label_expr]
  }

  site_type = "CUSTOMER_EDGE"

  depends_on = [volterra_known_label.site_mesh]
}

# --------------------------------------------------------------------------
# Site Mesh Group — system namespace
# Full mesh, data-plane only, referencing the virtual site above.
# --------------------------------------------------------------------------

resource "volterra_site_mesh_group" "mesh" {
  name      = var.mesh_name
  namespace = "system"

  full_mesh {
    data_plane_mesh = true
  }

  virtual_site {
    name      = volterra_virtual_site.mesh.name
    namespace = "shared"
  }
}

# --------------------------------------------------------------------------
# Network Segments — system namespace
# --------------------------------------------------------------------------

resource "volterra_segment" "segments" {
  for_each = var.segments

  name        = each.key
  namespace   = "system"
  description = each.value.description
  enable      = each.value.internet_connected
}
