output "hostnames" {
  description = "Hostnames discovered in this group"
  value       = [for host in values(local.hosts) : host.hostname]
}
