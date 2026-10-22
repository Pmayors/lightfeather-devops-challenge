locals {
  apps = {
    backend = {
      port = 8080
    }
    frontend = {
      port = 80
    }
  }

  services = {
    for pair in setproduct(sort(keys(var.environments)), sort(keys(local.apps))) :
    "${pair[0]}-${pair[1]}" => {
      environment       = pair[0]
      app               = pair[1]
      port              = local.apps[pair[1]].port
      desired_count     = var.environments[pair[0]].desired_count
      health_check_path = pair[1] == "backend" ? "/${pair[0]}/api/" : "/${pair[0]}/index.html"
      subnet_ids = [
        var.place_tasks_in_private_subnets
        ? var.private_subnet_ids[pair[0]]
        : var.public_subnet_ids[pair[0]]
      ]
      image = "${var.repository_urls[pair[1]]}:${var.image_tag}"
    }
  }

  # Lower number wins. The API rule must be ahead of the frontend rule because
  # /dev/api also matches the broader /dev prefix.
  environment_priority = {
    for index, name in sort(keys(var.environments)) :
    name => (index + 1) * 10
  }
}
