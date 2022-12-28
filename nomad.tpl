# The "job" stanza is the top-most configuration option in the job
# specification. A job is a declarative specification of tasks that Nomad
# should run. Jobs have a globally unique name, one or many task groups, which
# are themselves collections of one or many tasks.
job "${app_name}" {
  # The "datacenters" parameter specifies the list of datacenters which should
  # be considered when placing this task. This must be provided. (e.g., "sd", "lv", "eu")
  datacenters = ${jsonencode(datacenters)}

  # The "type" parameter controls the type of job, which impacts the scheduler's
  # decision on placement. This configuration is optional and defaults to
  # "service". For a full list of job types and their differences, please see
  # the online documentation.
  type = "${type}"

  # The "namespace" parameter controls the namespace in which to place the job. All namespaces excluding "dev"
  # will be managed by a CI/CD pipeline deployment and this field should remain unchanged for development.
  namespace = "${namespace}"

  # The "update" stanza specifies the update strategy of task groups. The update
  # strategy is used to control things like rolling upgrades, canaries, and
  # blue/green deployments. If omitted, no update strategy is enforced. The
  # "update" stanza may be placed at the job or task group. When placed at the
  # job, it applies to all groups within the job. When placed at both the job and
  # group level, the stanzas are merged with the group's taking precedence.
  update {
    max_parallel = ${count}
    canary       = ${count}
    auto_revert  = true
    auto_promote = true
    health_check = "checks"
  }

  # The "group" stanza defines a series of tasks that should be co-located on
  # the same Nomad client. Any task within a group will be placed on the same
  # client.
  group "${app_name}" {
    # The "count" parameter specifies the number of the task groups that should
    # be running under this group. This value must be non-negative and defaults
    # to 1.
    count = "${count}"

    # The "network" stanza specifies the network configuration for the allocation
    # including requesting port bindings.
    network {
        port "${app_name}" {}
    }

    # The "task" stanza creates an individual unit of work, such as a Docker
    # container, web application, or batch processing.
    task "${app_name}" {
      # The "driver" parameter specifies the task driver that should be used to
      # run the task.
      driver = "${task_driver}"

      # The "config" stanza specifies the driver configuration, which is passed
      # directly to the driver to start the task. The details of configurations
      # are specific to each driver, so please see specific driver
      # documentation for more information.
      config {
        image = "${docker_image}:${docker_tag}"

        auth {
          username = "${registry_server}"
          password = "${registry_token}"
        }
        ports = ["${app_name}"]
      }

      # The "service" stanza instructs Nomad to register this task as a service
      # in the service discovery engine, which is currently Nomad or Consul. This
      # will make the service discoverable after Nomad has placed it on a host and
      # port.
      service {
        # The name of the service within service discovery.
        name = "${app_name}"
        provider = "${service_provider}"
        port = "${app_name}"

%{ if health_check_path != "" ~}
        check {
          type     = "http"
          name     = "${app_name}_health"
          path     = "${health_check_path}"
          interval = "20s"
          timeout  = "5s"

          check_restart {
            limit = 3
            grace = "90s"
            ignore_warnings = false
          }
        }
%{ endif ~}

        # Key/Value pair tags are how Traefik Reverse Proxy picks up and configures routers for services within Nomad.
        # The name of the router is defined within the key (traefik.http.routers.EXAMPLE).
        # Most values can be left as default with the exception of the router rule. The router rule defines conditions for routing
        # to a particular service with which many options are available for configuration.
        # See (https://doc.traefik.io/traefik/routing/routers/) for more information regarding routers
        # and (https://doc.traefik.io/traefik/routing/providers/nomad/) for additional tagging options for Nomad.
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${app_name}.rule=${traefik_rules}",
          "traefik.http.routers.${app_name}.entrypoints=websecure",
          "traefik.http.routers.${app_name}.tls=true",
          "traefik.http.routers.${app_name}.tls.certresolver=le"
        ]
      }

      # The environment stanza passes environment variables to the defined task.
      # This template dynamically passes all entrypoint environment variables from Waypoint, however, as many variables can be defined below as necessary.
      env {
        %{ for k,v in entrypoint.env ~}
        ${k} = "${v}"
        %{ endfor ~}

        # For HashiCorp Waypoint URL service to function the service port needs to be passed as an environment variable.
        # Nomad generates environment variables for all defined ports by prepending 'NOMAD_PORT_' to the name of the defined port.
        # Change 'example' to the name given to the port defined above.
        PORT = "$${NOMAD_PORT_${app_name}}"
      }
    }
  }
}