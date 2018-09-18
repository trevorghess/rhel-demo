output "lb_ip" {
  value = ["${azurerm_public_ip.vmsspip.*.ip_address}"]
}
