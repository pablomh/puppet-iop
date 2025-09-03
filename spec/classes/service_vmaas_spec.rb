require 'spec_helper'

describe 'iop::service_vmaas' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }

        # VMAAS service tests
        it { should contain_podman__quadlet('iop-service-vmaas-reposcan') }
        it { should contain_podman__quadlet('iop-service-vmaas-webapp-go') }
        it { should contain_file('/var/lib/vmaas') }
        it { should contain_class('iop::cvemap_downloader') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { should compile.with_all_deps }
        it { should contain_podman__quadlet('iop-service-vmaas-reposcan').with_ensure('absent') }
        it { should contain_podman__quadlet('iop-service-vmaas-webapp-go').with_ensure('absent') }
      end

      context 'with custom database parameters' do
        let(:params) do
          {
            database_user: 'test_user',
            database_name: 'test_db',
            database_password: 'test_password',
          }
        end

        it { should compile.with_all_deps }
        it { should contain_podman__quadlet('iop-service-vmaas-reposcan') }
        it { should contain_podman__quadlet('iop-service-vmaas-webapp-go') }
      end
    end
  end
end
