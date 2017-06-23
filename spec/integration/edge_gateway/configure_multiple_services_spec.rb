require 'spec_helper'
require 'tempfile'

module Vcloud
  describe EdgeGateway::Configure do

    before(:all) do
      config_file = File.join(File.dirname(__FILE__), "../vcloud_tools_testing_config.yaml")
      required_user_params = [
        "edge_gateway",
        "provider_network_id",
        "provider_network_ip",
      ]

      @test_params = Vcloud::Tools::Tester::TestSetup.new(config_file, required_user_params).test_params
      @files_to_delete = []
    end

    context "with multiple services" do

      before(:all) do
        reset_edge_gateway
        @vars_config_file = generate_vars_file(edge_gateway_vars_hash)
        @initial_config_file = IntegrationHelper.fixture_file('nat_and_firewall_config.yaml.mustache')
        @adding_load_balancer_config_file = IntegrationHelper.fixture_file('nat_and_firewall_plus_load_balancer_config.yaml.mustache')
        @edge_gateway = Vcloud::Core::EdgeGateway.get_by_name(@test_params.edge_gateway)
      end

      context "Check update is functional" do

        it "should be starting our tests from an empty EdgeGateway" do
          remote_vcloud_config = @edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
          expect(remote_vcloud_config[:FirewallService][:FirewallRule].empty?).to be true
          expect(remote_vcloud_config[:NatService][:NatRule].empty?).to be true
          expect(remote_vcloud_config[:LoadBalancerService][:Pool].empty?).to be true
          expect(remote_vcloud_config[:LoadBalancerService][:VirtualServer].empty?).to be true
        end

        it "should only create one edgeGateway update task when updating the configuration" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          last_task = IntegrationHelper.get_last_task(@test_params.edge_gateway)
          diff = EdgeGateway::Configure.new(@initial_config_file, @vars_config_file).update
          tasks_elapsed = IntegrationHelper.get_tasks_since(@test_params.edge_gateway, last_task)

          expect(diff.keys).to eq([:FirewallService, :NatService])
          expect(diff[:FirewallService]).to have_at_least(1).items
          expect(diff[:NatService]).to have_at_least(1).items
          expect(tasks_elapsed).to have(1).items
        end

        it "should now have nat and firewall rules configured, no load balancer yet" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          remote_vcloud_config = @edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
          expect(remote_vcloud_config[:FirewallService][:FirewallRule].empty?).to be false
          expect(remote_vcloud_config[:NatService][:NatRule].empty?).to be false
          expect(remote_vcloud_config[:LoadBalancerService][:Pool].empty?).to be(true)
          expect(remote_vcloud_config[:LoadBalancerService][:VirtualServer].empty?).to be(true)
        end

        it "should not update the EdgeGateway again if the config hasn't changed" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          last_task = IntegrationHelper.get_last_task(@test_params.edge_gateway)
          diff = EdgeGateway::Configure.new(@initial_config_file, @vars_config_file).update
          tasks_elapsed = IntegrationHelper.get_tasks_since(@test_params.edge_gateway, last_task)

          expect(diff).to eq({})
          expect(tasks_elapsed).to have(0).items
        end

        it "should only create one additional edgeGateway update task when adding the LoadBalancer config" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          last_task = IntegrationHelper.get_last_task(@test_params.edge_gateway)
          diff = EdgeGateway::Configure.new(@adding_load_balancer_config_file, @vars_config_file).update
          tasks_elapsed = IntegrationHelper.get_tasks_since(@test_params.edge_gateway, last_task)

          expect(diff.keys).to eq([:LoadBalancerService])
          expect(diff[:LoadBalancerService]).to have_at_least(1).items
          expect(tasks_elapsed).to have(1).items
        end

        it "should not update the EdgeGateway again if we reapply the 'adding load balancer' config" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          last_task = IntegrationHelper.get_last_task(@test_params.edge_gateway)
          diff = EdgeGateway::Configure.new(@adding_load_balancer_config_file, @vars_config_file).update
          tasks_elapsed = IntegrationHelper.get_tasks_since(@test_params.edge_gateway, last_task)

          expect(diff).to eq({})
          expect(tasks_elapsed).to have(0).items
        end

      end

      after(:all) do
        IntegrationHelper.remove_temp_config_files(@files_to_delete)
      end

      def reset_edge_gateway
        edge_gateway = Core::EdgeGateway.get_by_name @test_params.edge_gateway
        edge_gateway.update_configuration({
                                            FirewallService: {IsEnabled: false, FirewallRule: []},
                                            NatService: {:IsEnabled => "true", :NatRule => []},
                                            LoadBalancerService: {
                                              IsEnabled: "false",
                                              Pool: [],
                                              VirtualServer: []
                                            }
                                          })
      end

      def generate_vars_file(vars_hash)
        file = Tempfile.new('vars_file')
        file.write(vars_hash.to_yaml)
        file.close
        @files_to_delete << file

        file.path
      end

      def edge_gateway_vars_hash
        {
          edge_gateway_name: @test_params.edge_gateway,
          network_id: @test_params.provider_network_id,
          original_ip: @test_params.provider_network_ip,
          edge_gateway_ext_network_id: @test_params.provider_network_id,
          edge_gateway_ext_network_ip: @test_params.provider_network_ip,
        }
      end
    end

  end
end
