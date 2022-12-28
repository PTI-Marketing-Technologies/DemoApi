# The name of your project. A project typically maps 1:1 to a VCS repository.
# This name must be unique for your Waypoint server. If you're running in
# local mode, this must be unique to your machine.
project = "demoapi"

# Labels can be specified for organizational purposes.
# labels = { "foo" = "bar" }

# Sensitive information such as container registry credentials can be safely stored in local environment variable files
# and not get checked into a VCS repository. All environment variables passed into waypoint must be prepended with `WP_VAR_`
# followed by the intended name of the variable as defined in HCL. (e.g., WP_VAR_registry_server would reference HCL variable "registry_server" )
variable "registry_server" {
  type = string
}

variable "registry_token" {
  type = string
}

variable "docker_image" {
  type = string
  default = "marcomdevops/demoapi"
}

variable "docker_tag" {
  type = string
  default = "1.0.0"
}

# Enable that Waypoint Static Runner
runner {
  enabled = true
}

# An application to deploy.
app "example" {

# Build specifies how an application should be deployed. In this case,
# we'll build using cloud native buildpacks.
  build {
    use "pack" {
#      The default pack image is heroku/buildpacks which supports a variety of languages and environments (https://devcenter.heroku.com/articles/buildpacks)
#      Heroku does not natively support .NET as of this writing, however, paketobuildpacks/builder does. Uncomment this line to utilize Paketo BuildPacks
      builder = "cloudfoundry/cnb"
    }

#    Use a remote docker registry to push your built images.
    registry {
      use "docker" {
        image = var.docker_image
        tag   = var.docker_tag
        auth {
          username = var.registry_server
          password = var.registry_token
        }
      }
    }

#        The `docker-pull` plugin can be used instead of the `pack` plugin in junction with the registry block to deploy pre-existing
#        docker images. This is helpful for deploying containers external to the repository, or for rolling back changes to a previous deployment.
#        use "docker-pull" {
#          image = var.docker_image
#          tag   = var.docker_tag
#          auth {
#            serverAddress = var.registry_server
#            identityToken = var.registry_token
#          }
#        }
  }

# Deploy to Nomad Cluster using a templated job file
# For complex configuration, additional variables can be templated and changes can be made to the nomad.tpl template file
  deploy {
    use "nomad-jobspec" {
      jobspec = templatefile("${path.app}/nomad.tpl", {
        app_name = "demoapi",
        count = 1,
        traefik_rules = "Host(`demoapi.com`)",
        health_check_path = "",
        datacenters = ["sd"],
        type = "service",
        namespace = "dev",
        task_driver = "docker",
        service_provider = "nomad",
        registry_server = var.registry_server,
        registry_token = var.registry_token,
        docker_image = var.docker_image,
        docker_tag = var.docker_tag
      })
    }
  }
}
