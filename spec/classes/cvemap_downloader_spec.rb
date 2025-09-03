require 'spec_helper'

describe 'iop::cvemap_downloader' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_class('iop::core_gateway') }
        it { should contain_file('/usr/local/bin/iop-cvemap-download.sh') }
        it { should contain_systemd__manage_unit('iop-cvemap-download.service') }
        it { should contain_systemd__timer('iop-cvemap-download.timer') }
        it { should contain_systemd__unit_file('iop-cvemap-download.path') }
        it { should contain_exec('iop-cvemap-initial-download') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }
        
        it { should compile.with_all_deps }
        it { should contain_file('/usr/local/bin/iop-cvemap-download.sh').with_ensure('absent') }
        it { should contain_systemd__manage_unit('iop-cvemap-download.service').with_ensure('absent') }
        it { should contain_systemd__timer('iop-cvemap-download.timer').with_ensure('absent') }
        it { should contain_systemd__unit_file('iop-cvemap-download.path').with_ensure('absent') }
      end

      context 'with custom base_url' do
        let(:params) { { base_url: 'https://example.com/test.xml' } }
        
        it { should compile.with_all_deps }
        it { should contain_systemd__manage_unit('iop-cvemap-download.service') }
        it { should contain_exec('iop-cvemap-initial-download') }
      end

      context 'with custom timer_interval' do
        let(:params) { { timer_interval: '12h' } }
        
        it { should compile.with_all_deps }
        it { should contain_systemd__timer('iop-cvemap-download.timer') }
      end

      context 'with enable_initial_download => false' do
        let(:params) { { enable_initial_download: false } }
        
        it { should compile.with_all_deps }
        it { should_not contain_exec('iop-cvemap-initial-download') }
      end

      context 'gateway dependency verification' do
        it { should compile.with_all_deps }
        
        describe 'systemd unit dependencies' do
          let(:unit_entry) { catalogue.resource('Systemd::Manage_unit', 'iop-cvemap-download.service')[:unit_entry] }
          
          it 'has correct After dependencies' do
            expect(unit_entry['After']).to eq(['network-online.target', 'iop-core-gateway.service'])
          end
          
          it 'has correct Wants dependencies' do
            expect(unit_entry['Wants']).to eq(['network-online.target', 'iop-core-gateway.service'])
          end
        end
        
        it { should contain_systemd__manage_unit('iop-cvemap-download.service').that_requires('Class[iop::core_gateway]') }
      end
    end
  end
end
