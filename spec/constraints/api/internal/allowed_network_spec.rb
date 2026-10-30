require "rails_helper"

# Request spec : la contrainte juge la requête telle que la pile Rails l'a reçue. Aucune route
# interne n'existe encore, d'où une URL /api quelconque.
RSpec.describe API::Internal::AllowedNetwork, type: :request do
  def request_from(peer, headers = {})
    get "/api/inconnu", headers:, env: {"REMOTE_ADDR" => peer}
    request
  end

  describe "#matches?" do
    context "with addresses and ranges allowed" do
      subject(:constraint) { described_class.new(" 198.51.100.7, 192.0.2.0/24 ,10.0.0.5,2001:db8::/32") }

      # 203.0.113.10 : un client extérieur non autorisé. 10.0.0.2 : le proxy (adresse privée,
      # donc de confiance pour Rails). 10.0.0.5 : un client interne autorisé.
      {
        "the exact allowed address" =>
          {peer: "198.51.100.7", headers: {}, allowed: true},
        "an address in an allowed range" =>
          {peer: "192.0.2.42", headers: {}, allowed: true},
        "an IPv6 address in an allowed range" =>
          {peer: "2001:db8::1", headers: {}, allowed: true},
        "an internal client reaching the application directly" =>
          {peer: "10.0.0.5", headers: {}, allowed: true},
        "another address" =>
          {peer: "203.0.113.10", headers: {}, allowed: false},
        "a forged X-Forwarded-For from an unauthorized address" =>
          {peer: "203.0.113.10", headers: {"X-Forwarded-For" => "198.51.100.7"}, allowed: false},
        "a forged X-Forwarded-For with the allowed address first" =>
          {peer: "203.0.113.10", headers: {"X-Forwarded-For" => "198.51.100.7, 203.0.113.99"}, allowed: false},
        "a forged X-Forwarded-For with the allowed address last" =>
          {peer: "203.0.113.10", headers: {"X-Forwarded-For" => "203.0.113.99, 198.51.100.7"}, allowed: false},
        "a forged X-Forwarded-For chain" =>
          {peer: "203.0.113.10", headers: {"X-Forwarded-For" => "203.0.113.99, 198.51.100.7, 192.0.2.42"}, allowed: false},
        "a forged X-Forwarded-For carrying an allowed private address" =>
          {peer: "203.0.113.10", headers: {"X-Forwarded-For" => "10.0.0.5"}, allowed: false},
        "a forged Forwarded header" =>
          {peer: "203.0.113.10", headers: {"Forwarded" => "for=198.51.100.7"}, allowed: false},
        "a forged Client-IP header" =>
          {peer: "203.0.113.10", headers: {"Client-IP" => "198.51.100.7"}, allowed: false},
        "an allowed address forwarded by the proxy" =>
          {peer: "10.0.0.2", headers: {"X-Forwarded-For" => "198.51.100.7"}, allowed: true},
        "an allowed internal client forwarded by the proxy" =>
          {peer: "10.0.0.2", headers: {"X-Forwarded-For" => "10.0.0.5"}, allowed: true},
        "an unauthorized address forwarded by the proxy" =>
          {peer: "10.0.0.2", headers: {"X-Forwarded-For" => "203.0.113.10"}, allowed: false},
        "a forged address the proxy appended to instead of overwriting" =>
          {peer: "10.0.0.2", headers: {"X-Forwarded-For" => "198.51.100.7, 203.0.113.10"}, allowed: false},
        "a forged Forwarded header passed through by the proxy" =>
          {peer: "10.0.0.2", headers: {"X-Forwarded-For" => "203.0.113.10", "Forwarded" => "for=198.51.100.7"}, allowed: false},
        "a forged Client-IP header passed through by the proxy" =>
          {peer: "10.0.0.2", headers: {"X-Forwarded-For" => "203.0.113.10", "Client-IP" => "198.51.100.7"}, allowed: false},
        "a malformed X-Forwarded-For" =>
          {peer: "10.0.0.2", headers: {"X-Forwarded-For" => "not-an-address"}, allowed: false}
      }.each do |label, request_case|
        it "#{request_case[:allowed] ? "lets through" : "refuses"} #{label}" do
          expect(constraint.matches?(request_from(request_case[:peer], request_case[:headers])))
            .to be(request_case[:allowed])
        end
      end

      # Toute machine d'une plage privée est crue comme le proxy (TRUSTED_PROXIES) : ne croire que
      # le proxy suppose de connaître son adresse, et rien ne garantit encore qu'elle soit fixe.
      it "refuses a private host that is not the proxy, with a forged X-Forwarded-For" do
        pending "trust restricted to the proxy address, once it is known to be fixed"

        expect(constraint.matches?(request_from("10.0.0.9", {"X-Forwarded-For" => "198.51.100.7"})))
          .to be(false)
      end
    end

    context "with an allow list with no address" do
      {"absent" => nil, "empty" => "", "made of separators only" => " , "}.each do |label, allowed_ips|
        it "refuses everyone when the list is #{label}" do
          closed = described_class.new(allowed_ips)

          expect(closed.matches?(request_from("127.0.0.1"))).to be(false)
          expect(closed.matches?(request_from("10.0.0.2", {"X-Forwarded-For" => "198.51.100.7"}))).to be(false)
        end
      end
    end
  end

  describe ".new" do
    it "refuses an allow list with a malformed entry, naming the variable and the entry" do
      expect { described_class.new("198.51.100.7, serveur-interne") }
        .to raise_error(ArgumentError, /API_INTERNAL_ALLOWED_IPS.*serveur-interne/)
    end

    it "refuses a range whose address has host bits set, naming the entry and the range it would be" do
      expect { described_class.new("198.51.100.7, 10.0.0.5/8") }
        .to raise_error(ArgumentError, %r{API_INTERNAL_ALLOWED_IPS.*10\.0\.0\.5/8.*10\.0\.0\.0/8})
    end

    it "refuses a range covering every address, in IPv4 as in IPv6, naming the entry" do
      expect { described_class.new("198.51.100.7, 0.0.0.0/0") }
        .to raise_error(ArgumentError, %r{API_INTERNAL_ALLOWED_IPS.*0\.0\.0\.0/0.*trop large})
      expect { described_class.new("198.51.100.7, ::/0") }
        .to raise_error(ArgumentError, %r{API_INTERNAL_ALLOWED_IPS.*::/0.*trop large})
    end
  end
end
