output "virtual_site_name" {
  value       = volterra_virtual_site.mesh.name
  description = "Name of the virtual site CE sites are selected into"
}

output "site_mesh_group_name" {
  value       = volterra_site_mesh_group.mesh.name
  description = "Name of the site mesh group"
}

output "segment_names" {
  value       = { for k, v in volterra_segment.segments : k => v.name }
  description = "Map of created network segment names"
}

output "site_label" {
  value       = local.site_mesh_label_expr
  description = "Label expression that CE sites must carry to join the mesh"
}
