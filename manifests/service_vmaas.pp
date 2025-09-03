# == Class: iop::service_vmaas
#
# Install and configure the VMAAS reposcan service
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure service is present or absent
#
# $database_user:: Username for the vmaas database
#
# $database_name:: Name of the vmaas database
#
# $database_password:: Password for the vmaas database
#
# $database_host:: Host for the vmaas database
#
# $database_port:: Port for the vmaas database
#
class iop::service_vmaas (
  String[1] $image = 'quay.io/iop/vmaas:latest',
  Enum['present', 'absent'] $ensure = 'present',
  String[1] $database_user = 'vmaas_admin',
  String[1] $database_name = 'vmaas_db',
  String[1] $database_password = extlib::cache_data('iop_cache_data', 'vmaas_db_password', extlib::random_password(32)),
  String[1] $database_host = '/var/run/postgresql',
  Stdlib::Port $database_port = 5432,
) {
  include podman
  include iop::core_network
  include iop::core_kafka
  include iop::core_gateway
  include iop::database
  include iop::cvemap_downloader
  include certs::iop

  $service_name = 'iop-service-vmaas-reposcan'
  $server_ca_cert_secret_name = "${service_name}-server-ca-cert"
  $database_username_secret_name = "${service_name}-database-username"
  $database_password_secret_name = "${service_name}-database-password"
  $database_name_secret_name = "${service_name}-database-name"
  $database_host_secret_name = "${service_name}-database-host"
  $database_port_secret_name = "${service_name}-database-port"

  $socket_volume = $database_host ? {
    /^\/var\/run\/postgresql/ => ['/var/run/postgresql:/var/run/postgresql:rw'],
    default                   => [],
  }

  podman::secret { $server_ca_cert_secret_name:
    ensure => $ensure,
    path   => $certs::iop::server_ca_cert,
  }

  podman::secret { $database_username_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_user),
  }

  podman::secret { $database_password_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_password),
  }

  podman::secret { $database_name_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_name),
  }

  podman::secret { $database_host_secret_name:
    ensure => $ensure,
    secret => Sensitive($database_host),
  }

  podman::secret { $database_port_secret_name:
    ensure => $ensure,
    secret => Sensitive(String($database_port)),
  }

  # Prevents errors if run from /root etc.
  Postgresql_psql {
    cwd => '/',
  }

  include postgresql::client, postgresql::server

  postgresql::server::db { $database_name:
    user     => $database_user,
    password => postgresql::postgresql_password($database_user, $database_password),
    owner    => $database_user,
    encoding => 'utf8',
    locale   => 'en_US.utf8',
  }

  file { '/var/lib/vmaas':
    ensure => directory,
    mode   => '0775',
    owner  => 'root',
    group  => 'root',
  }

  podman::quadlet { 'iop-service-vmaas-reposcan':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      File['/var/lib/vmaas'],
      Postgresql::Server::Db[$database_name],
      Podman::Secret[$server_ca_cert_secret_name],
      Podman::Secret[$database_username_secret_name],
      Podman::Secret[$database_password_secret_name],
      Podman::Secret[$database_name_secret_name],
      Podman::Secret[$database_host_secret_name],
      Podman::Secret[$database_port_secret_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'VMAAS Reposcan Service',
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-service-vmaas-reposcan',
        'Network'       => 'iop-core-network',
        'Exec'          => '/vmaas/entrypoint.sh database-upgrade reposcan',
        'Environment'   => [
          'PROMETHEUS_PORT=8085',
          'PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus_multiproc_dir',
          'SYNC_REPO_LIST_SOURCE=katello',
          'SYNC_REPOS=yes',
          'SYNC_CVE_MAP=yes',
          'SYNC_CPE=no',
          'SYNC_CSAF=no',
          'SYNC_RELEASES=no',
          'SYNC_RELEASE_GRAPH=no',
          'KATELLO_URL=http://iop-core-gateway:9090',
          'REDHAT_CVEMAP_URL=http://iop-core-gateway:9090/pub/iop/data/meta/v1/cvemap.xml',
        ],
        'Volume'        => $socket_volume + [
          '/var/lib/vmaas:/data:rw,z',
        ],
        'Secret'        => [
          "${server_ca_cert_secret_name},target=/katello-server-ca.crt,mode=0440,type=mount",
          "${database_username_secret_name},type=env,target=POSTGRESQL_USER",
          "${database_password_secret_name},type=env,target=POSTGRESQL_PASSWORD",
          "${database_name_secret_name},type=env,target=POSTGRESQL_DATABASE",
          "${database_host_secret_name},type=env,target=POSTGRESQL_HOST",
          "${database_port_secret_name},type=env,target=POSTGRESQL_PORT",
        ],
      },
      'Service'   => {
        'Environment' => 'REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json',
        'Restart'     => 'on-failure',
      },
      'Install'   => {
        'WantedBy' => ['multi-user.target', 'default.target'],
      },
    },
  }

  podman::quadlet { 'iop-service-vmaas-webapp-go':
    ensure       => $ensure,
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    require      => [
      Podman::Network['iop-core-network'],
      Postgresql::Server::Db[$database_name],
      Podman::Secret[$database_username_secret_name],
      Podman::Secret[$database_password_secret_name],
      Podman::Secret[$database_name_secret_name],
      Podman::Secret[$database_host_secret_name],
      Podman::Secret[$database_port_secret_name],
    ],
    settings     => {
      'Unit'      => {
        'Description' => 'VMAAS Webapp-Go Service',
        'Wants'       => ['iop-service-vmaas-reposcan.service'],
        'After'       => ['iop-service-vmaas-reposcan.service'],
      },
      'Container' => {
        'Image'         => $image,
        'ContainerName' => 'iop-service-vmaas-webapp-go',
        'Network'       => 'iop-core-network',
        'Exec'          => '/vmaas/entrypoint.sh webapp-go',
        'Environment'   => [
          'REPOSCAN_PUBLIC_URL=http://iop-service-vmaas-reposcan:8000',
          'REPOSCAN_PRIVATE_URL=http://iop-service-vmaas-reposcan:10000',
          'CSAF_UNFIXED_EVAL_ENABLED=FALSE',
          'GIN_MODE=release',
        ],
        'Secret'        => [
          "${database_username_secret_name},type=env,target=POSTGRESQL_USER",
          "${database_password_secret_name},type=env,target=POSTGRESQL_PASSWORD",
          "${database_name_secret_name},type=env,target=POSTGRESQL_DATABASE",
          "${database_host_secret_name},type=env,target=POSTGRESQL_HOST",
          "${database_port_secret_name},type=env,target=POSTGRESQL_PORT",
        ],
        'Volume'        => $socket_volume,
      },
      'Service'   => {
        'Environment' => 'REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json',
        'Restart'     => 'on-failure',
      },
      'Install'   => {
        'WantedBy' => ['multi-user.target', 'default.target'],
      },
    },
  }
}
