require 'spec_helper_acceptance'

describe 'iop::cvemap_downloader' do
  before(:all) do
    on default, 'systemctl stop iop-cvemap-download.timer || true'
    on default, 'systemctl disable iop-cvemap-download.timer || true'
    on default, 'systemctl stop iop-cvemap-download.service || true'
    on default, 'systemctl disable iop-cvemap-download.service || true'
    on default, 'systemctl stop iop-cvemap-download.path || true'
    on default, 'systemctl disable iop-cvemap-download.path || true'
    on default, 'rm -f /etc/systemd/system/iop-cvemap-download*'
    on default, 'rm -rf /var/www/html/pub/iop'
    on default, 'rm -f /usr/local/bin/iop-cvemap-download.sh'
    on default, 'systemctl daemon-reload'
    on default, 'mkdir -p /var/www/html/pub'
    on default, 'mkdir -p /var/lib/foreman'
  end

  context 'with default parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        group { 'foreman': } ->
        file { '/etc/foreman':
          ensure => directory,
        } ->
        class { 'certs::foreman': } ->
        class { 'iop::cvemap_downloader': }
        PUPPET
      end
    end

    describe file('/usr/local/bin/iop-cvemap-download.sh') do
      it { is_expected.to be_file }
      it { is_expected.to be_executable }
    end

    describe file('/etc/systemd/system/iop-cvemap-download.service') do
      it { is_expected.to be_file }
    end

    describe file('/etc/systemd/system/iop-cvemap-download.timer') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{OnUnitActiveSec=24h} }
    end

    describe service('iop-cvemap-download.timer') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe file('/etc/systemd/system/iop-cvemap-download.path') do
      it { is_expected.to be_file }
    end

    describe service('iop-cvemap-download.service') do
      it { is_expected.not_to be_running }
    end

    describe service('iop-cvemap-download.path') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe command('systemctl list-timers iop-cvemap-download.timer') do
      its(:exit_status) { should eq 0 }
    end

    describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
      it { should exist }
      it { should be_file }
      it { should be_readable }
    end
  end
end
