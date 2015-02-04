module Vcloud
  module EdgeGateway
    class StaticRoutingConfigurationDiffer < ConfigurationDiffer
      def strip_fields_for_differ_to_ignore(config)
        Marshal.load(Marshal.dump(config))
      end
    end
  end

end
