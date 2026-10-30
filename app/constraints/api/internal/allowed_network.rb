module API
  module Internal
    class AllowedNetwork
      def initialize(allowed_ips)
        @networks = allowed_ips.to_s.split(",").map(&:strip).reject(&:empty?).map { network(it) }
      end

      def matches?(request)
        address = IPAddr.new(client_address(request))
        @networks.any? { it.include?(address) }
      rescue IPAddr::Error
        false
      end

      private

      # IPAddr ramènerait 10.0.0.5/8 à 10.0.0.0/8 sans prévenir : une coquille ouvrirait tout le réseau.
      def network(entry)
        range = IPAddr.new(entry)
        raise ArgumentError, "API_INTERNAL_ALLOWED_IPS : plage « #{entry} » trop large" if range.prefix.zero?
        return range if range == IPAddr.new(entry.split("/").first)

        raise ArgumentError, "API_INTERNAL_ALLOWED_IPS : entrée invalide « #{entry} » " \
          "(adresse hors du début de sa plage, voulu : #{range}/#{range.prefix} ?)"
      rescue IPAddr::Error => error
        raise ArgumentError, "API_INTERNAL_ALLOWED_IPS : entrée invalide « #{entry} » (#{error.message})"
      end

      # Pas de request.remote_ip : il croit X-Forwarded-For, Forwarded et Client-IP quel que soit
      # l'émetteur. Seul le dernier maillon, écrit par le proxy de confiance, fait foi.
      def client_address(request)
        peer = request.remote_addr
        return peer unless trusted_proxy?(peer)

        request.get_header("HTTP_X_FORWARDED_FOR").to_s.split(",").last&.strip || peer
      end

      def trusted_proxy?(address)
        ActionDispatch::RemoteIp::TRUSTED_PROXIES.any? { it === address }
      end
    end
  end
end
