module Vcloud
  module EdgeGateway
    module Schema

      EDGE_GATEWAY_SERVICES = {
          type: 'hash',
          allowed_empty: false,
          internals: {
              gateway: { type: 'string' },
              firewall_service: FIREWALL_SERVICE,
              nat_service: NAT_SERVICE,
              load_balancer_service: LOAD_BALANCER_SERVICE,
              static_routing_service: STATIC_ROUTING_SERVICE,
              gateway_ipsec_vpn_service: GATEWAY_IPSEC_VPN_SERVICE
          }
      }

    end
  end
end
