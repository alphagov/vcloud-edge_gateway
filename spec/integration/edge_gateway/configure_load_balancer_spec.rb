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

    context "Test LoadBalancerService specifics" do

      before(:all) do
        reset_edge_gateway
        @vars_config_file = generate_vars_file(edge_gateway_vars_hash)
        @initial_load_balancer_config_file = IntegrationHelper.fixture_file('load_balancer_config.yaml.mustache')
        @edge_gateway = Vcloud::Core::EdgeGateway.get_by_name(@test_params.edge_gateway)
      end

      context "Check update is functional" do

        before(:all) do
          local_config = Core::ConfigLoader.new.load_config(
            @initial_load_balancer_config_file,
            Vcloud::EdgeGateway::Schema::EDGE_GATEWAY_SERVICES,
            @vars_config_file
          )
          @local_vcloud_config  = EdgeGateway::ConfigurationGenerator::LoadBalancerService.new(
            @edge_gateway.interfaces
          ).generate_fog_config(local_config[:load_balancer_service])
        end

        it "should be starting our tests from an empty LoadBalancerService" do
          edge_service_config = @edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
          remote_vcloud_config = edge_service_config[:LoadBalancerService]
          expect(remote_vcloud_config[:Pool].empty?).to be true
          expect(remote_vcloud_config[:VirtualServer].empty?).to be true
        end

        it "should only make one EdgeGateway update task, to minimise EdgeGateway reload events" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          last_task = IntegrationHelper.get_last_task(@test_params.edge_gateway)
          diff = EdgeGateway::Configure.new(@initial_load_balancer_config_file, @vars_config_file).update
          tasks_elapsed = IntegrationHelper.get_tasks_since(@test_params.edge_gateway, last_task)

          expect(diff.keys).to eq([:LoadBalancerService])
          expect(diff[:LoadBalancerService]).to have_at_least(1).items
          expect(tasks_elapsed).to have(1).items
        end

        it "should have configured at least one LoadBancer Pool entry" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          edge_service_config = @edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
          remote_vcloud_config = edge_service_config[:LoadBalancerService]
          expect(remote_vcloud_config[:Pool].empty?).to be false
        end

        it "should have configured at least one LoadBancer VirtualServer entry" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          edge_service_config = @edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
          remote_vcloud_config = edge_service_config[:LoadBalancerService]
          expect(remote_vcloud_config[:VirtualServer].empty?).to be false
        end

        it "should have configured the same number of Pools as in our configuration" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          edge_service_config = @edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
          remote_vcloud_config = edge_service_config[:LoadBalancerService]
          expect(remote_vcloud_config[:Pool].size).
            to eq(@local_vcloud_config[:Pool].size)
        end

        it "should have configured the same number of VirtualServers as in our configuration" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          edge_service_config = @edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
          remote_vcloud_config = edge_service_config[:LoadBalancerService]
          expect(remote_vcloud_config[:VirtualServer].size).
            to eq(@local_vcloud_config[:VirtualServer].size)
        end

        it "should not then configure the LoadBalancerService if updated again with the same configuration" do
          pending("This test will fail until https://github.com/fog/fog/pull/3695 is merged and released by Fog")

          expect(Vcloud::Core.logger).to receive(:info).
            with('EdgeGateway::Configure.update: Configuration is already up to date. Skipping.')
          diff = EdgeGateway::Configure.new(@initial_load_balancer_config_file, @vars_config_file).update

          expect(diff).to eq({})
        end

      end

      context "Check specific LoadBalancerService update cases" do

        it "should be able to configure with no pools and virtual_servers" do
          config_file = IntegrationHelper.fixture_file('load_balancer_empty.yaml.mustache')
          diff = EdgeGateway::Configure.new(config_file, @vars_config_file).update
          edge_config = @edge_gateway.vcloud_attributes[:Configuration]
          remote_vcloud_config = edge_config[:EdgeGatewayServiceConfiguration][:LoadBalancerService]

          expect(diff.keys).to eq([:LoadBalancerService])
          expect(diff[:LoadBalancerService]).to have_at_least(1).items
          expect(remote_vcloud_config[:Pool].size).to be == 0
          expect(remote_vcloud_config[:VirtualServer].size).to be == 0
        end

        it "should be able to configure with a single Pool and no VirtualServers" do
          config_file = IntegrationHelper.fixture_file('load_balancer_single_pool.yaml.mustache')
          diff = EdgeGateway::Configure.new(config_file, @vars_config_file).update
          edge_config = @edge_gateway.vcloud_attributes[:Configuration]
          remote_vcloud_config = edge_config[:EdgeGatewayServiceConfiguration][:LoadBalancerService]

          expect(diff.keys).to eq([:LoadBalancerService])
          expect(diff[:LoadBalancerService]).to have_at_least(1).items
          expect(remote_vcloud_config[:Pool].size).to be == 1
        end

        it "should raise an error when trying configure with a single VirtualServer, and no pool mentioned" do
          config_file = IntegrationHelper.fixture_file('load_balancer_single_virtual_server_missing_pool.yaml.mustache')
          expect { EdgeGateway::Configure.new(config_file, @vars_config_file).update }.
            to raise_error('Supplied configuration does not match supplied schema')
        end

        it "should raise an error when trying configure with a single VirtualServer, with an unconfigured pool" do
          config_file = IntegrationHelper.fixture_file('load_balancer_single_virtual_server_invalid_pool.yaml.mustache')
          expect { EdgeGateway::Configure.new(config_file, @vars_config_file).update }.
            to raise_error(
              /Load balancer virtual server integration-test-vs-1 does not have a valid backing pool/
            )
        end

      end

      after(:all) do
        IntegrationHelper.remove_temp_config_files(@files_to_delete)
      end

      def reset_edge_gateway
        edge_gateway = Core::EdgeGateway.get_by_name @test_params.edge_gateway
        edge_gateway.update_configuration({
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
          :edge_gateway_name => @test_params.edge_gateway,
          :edge_gateway_ext_network_id => @test_params.provider_network_id,
          :edge_gateway_ext_network_ip => @test_params.provider_network_ip,
        }
      end
    end

  end
end
