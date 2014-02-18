require 'spec_helper'

module Vcloud
  module EdgeGateway
    module ConfigurationGenerator
      describe NatService do

        before(:each) do
          mock_uplink_interface = double(
            :mock_uplink,
            :network_name => "ane012345",
            :network_id   => "2ad93597-7b54-43dd-9eb1-631dd337e5a7",
            :network_href   => "https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7",
          )
          mock_internal_interface = double(
            :mock_uplink,
            :network_name => "internal_interface",
            :network_id   => "12346788-1234-1234-1234-123456789000",
            :network_href => "https://vmware.api.net/api/admin/network/12346788-1234-1234-1234-123456789000",
          )
          @interface_list = [ mock_uplink_interface, mock_internal_interface ]
        end

        context "SNAT rule defaults" do

          before(:each) do
            input = { nat_rules: [{
              rule_type: 'SNAT',
              network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
              original_ip: "192.0.2.2",
              translated_ip: "10.10.20.20",
            }]} # minimum NAT configuration with a rule
            output = NatService.new(input, @interface_list).generate_fog_config
            @rule = output[:NatRule].first
          end

          it 'should default to the rule being enabled' do
            expect(@rule[:IsEnabled]).to eq('true')
          end

          it 'should have a RuleType of SNAT' do
            expect(@rule[:RuleType]).to eq('SNAT')
          end

          it 'should not include a Protocol' do
            expect(@rule[:GatewayNatRule].key?(:Protocol)).to be_false
          end

          it 'should completely match our expected default rule' do
            expect(@rule).to eq({
              :Id=>"65537",
              :IsEnabled=>"true",
              :RuleType=>"SNAT",
              :GatewayNatRule=>{
                :Interface=>{
                  :type=>"application/vnd.vmware.admin.network+xml",
                  :name=>"ane012345",
                  :href=>"https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7"
                },
              :OriginalIp=>"192.0.2.2",
              :TranslatedIp=>"10.10.20.20"}
            })
          end

        end

        context "DNAT rule defaults" do

          before(:each) do
            input = { nat_rules: [{
              rule_type: 'DNAT',
              network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
              original_ip: "192.0.2.2",
              original_port: '22',
              translated_port: '22',
              translated_ip: "10.10.20.20",
              protocol: 'tcp',
            }]} # minimum NAT configuration with a rule
            output = NatService.new(input, @interface_list).generate_fog_config
            @rule = output[:NatRule].first
          end

          it 'should default to rule being enabled' do
            expect(@rule[:IsEnabled]).to eq('true')
          end

          it 'should have a RuleType of DNAT' do
            expect(@rule[:RuleType]).to eq('DNAT')
          end

          it 'should include a default Protocol of tcp' do
            expect(@rule[:GatewayNatRule][:Protocol]).to eq('tcp')
          end

          it 'should completely match our expected default rule' do
            expect(@rule).to eq({
              :Id=>"65537",
              :IsEnabled=>"true",
              :RuleType=>"DNAT",
              :GatewayNatRule=>{
                :Interface=>{
                  :type=>"application/vnd.vmware.admin.network+xml",
                  :name=>"ane012345",
                  :href=>"https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7"
                },
                :OriginalIp=>"192.0.2.2",
                :TranslatedIp=>"10.10.20.20",
                :OriginalPort=>"22",
                :TranslatedPort=>"22",
                :Protocol=>"tcp"
              }
            })
          end

        end

        context "nat service config generation" do

          test_cases = [
            {
              title: 'should generate config for enabled nat service with single disabled DNAT rule',
              input: {
                enabled: 'true',
                nat_rules: [
                  {
                    enabled: 'false',
                    id: '999',
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '22',
                    translated_port: '22',
                    translated_ip: "10.10.20.20",
                    protocol: 'tcp',
                  }
                ]
              },
              output: {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'false',
                    :Id => '999',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => "application/vnd.vmware.admin.network+xml",
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'tcp',
                      :OriginalIp => "192.0.2.2",
                      :OriginalPort => '22',
                      :TranslatedIp => "10.10.20.20",
                      :TranslatedPort => '22'
                    }
                  }
                ]
              }
            },

            {
              title: 'should handle specification of UDP based DNAT rules',
              input: {
                enabled: 'true',
                nat_rules: [
                  {
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.25",
                    original_port: '53',
                    translated_port: '53',
                    translated_ip: "10.10.20.25",
                    protocol: 'udp',
                  }
                ]
              },
              output: {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'true',
                    :Id => '65537',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => "application/vnd.vmware.admin.network+xml",
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'udp',
                      :OriginalIp => "192.0.2.25",
                      :OriginalPort => '53',
                      :TranslatedIp => "10.10.20.25",
                      :TranslatedPort => '53'
                    }
                  }
                ]
              }
            },

            {
              title: 'should generate config for enabled nat service with single disabled SNAT rule',
              input: {
                enabled: 'true',
                nat_rules: [
                  {
                    enabled: 'false',
                    rule_type: 'SNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    translated_ip: "10.10.20.20",
                  }
                ]
              },
              output: {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'SNAT',
                    :IsEnabled => 'false',
                    :Id => '65537',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => "application/vnd.vmware.admin.network+xml",
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :OriginalIp => "192.0.2.2",
                      :TranslatedIp => "10.10.20.20",
                    }
                  }
                ]
              }
            },

            {
              title: 'should auto generate rule id if not provided',
              input: {
                enabled: 'true',
                nat_rules: [
                  {
                    enabled: 'false',
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '22',
                    translated_port: '22',
                    translated_ip: "10.10.20.20",
                    protocol: 'tcp',
                  }
                ]
              },
              output: {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'false',
                    :Id => '65537',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => "application/vnd.vmware.admin.network+xml",
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'tcp',
                      :OriginalIp => "192.0.2.2",
                      :OriginalPort => '22',
                      :TranslatedIp => "10.10.20.20",
                      :TranslatedPort => '22'
                    }
                  }
                ]
              }
            },

            {
              title: 'should use default values for optional fields if they are missing',
              input: {
                nat_rules: [
                  {
                    rule_type: 'DNAT',
                    network_id: '2ad93597-7b54-43dd-9eb1-631dd337e5a7',
                    original_ip: "192.0.2.2",
                    original_port: '22',
                    translated_port: '22',
                    translated_ip: "10.10.20.20",
                  }
                ]
              },
              output: {
                :IsEnabled => 'true',
                :NatRule => [
                  {
                    :RuleType => 'DNAT',
                    :IsEnabled => 'true',
                    :Id => '65537',
                    :GatewayNatRule => {
                      :Interface =>
                        {
                          :type => "application/vnd.vmware.admin.network+xml",
                          :name => 'ane012345',
                          :href => 'https://vmware.api.net/api/admin/network/2ad93597-7b54-43dd-9eb1-631dd337e5a7'
                        },
                      :Protocol => 'tcp',
                      :OriginalIp => "192.0.2.2",
                      :OriginalPort => '22',
                      :TranslatedIp => "10.10.20.20",
                      :TranslatedPort => '22'
                    }
                  }
                ]
              }

            }
          ]

          test_cases.each do |test_case|
            it "#{test_case[:title]}" do
              generated_config = NatService.new(test_case[:input], @interface_list).generate_fog_config
              expect(generated_config).to eq(test_case[:output])
            end
          end

        end
      end
    end
  end
end
