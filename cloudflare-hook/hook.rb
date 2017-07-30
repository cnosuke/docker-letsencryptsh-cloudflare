require 'rubyflare'
require 'resolv'
require 'logger'

LOGFILE = ENV['LOGFILE'] || STDOUT
LOGGER = Logger.new(LOGFILE)
unless ENV['LOGFILE']
  LOGGER.formatter = proc { |severity, datetime, progname, message|
    "#{message}\n"
  }
end

NAMESERVERS = ENV['NAMESERVERS']&.split(',') || %w(8.8.8.8 8.8.4.4)
SLEEP_TIME = ENV['SLEEP_TIME']&.to_i || 30

CF_API_KEY = ENV['CF_API_KEY']
CF_API_MAIL = ENV['CF_API_MAIL']
CF_SUBDOMAIN = ENV['CF_SUBDOMAIN']
CF_ZONE = ENV['CF_ZONE']
ACME_CHALLENGE = '_acme-challenge'
ACME_CHALLENGE_SUBDOIMAIN = [ACME_CHALLENGE, CF_SUBDOMAIN, CF_ZONE].compact.join('.')

TOKEN_TTL = 120

class DnsPropagandaChecker
  class << self
    def has_dns_propagated?(name, token)
      resolver = Resolv::DNS.new(nameserver: NAMESERVERS)
      resolver.getresource(name, Resolv::DNS::Resource::IN::TXT)
        .strings.each do |txt|
          return true if txt == token
        end
      return false
    rescue Resolv::ResolvError
      return false
    end

    def wait_dns_propagated(name, token)
      10.times do
        if has_dns_propagated?(name, token)
          LOGGER.info(" + TXT `#{name}` matched.")
          return true
        else
          LOGGER.info(" + TXT `#{name}` does not matched. Retrying after #{SLEEP_TIME} sec...")
          sleep SLEEP_TIME
          LOGGER.info(" + Retry: #{Time.now.to_s}")
        end
      end

      LOGGER.info(" + TXT `#{name}` does not matched. Tried 10 times.")
      return false
    end
  end
end

class CloudFlareHandler
  class << self
    def connection
      @connection ||= Rubyflare.connect_with(CF_API_MAIL, CF_API_KEY)
    end

    def zone_id
      @zone_id ||= connection.get('zones', { name: CF_ZONE }).result[:id]
    end

    def fetch_txt_record
      connection.get(
        "zones/#{zone_id}/dns_records",
        base_txt_params
      ).result
    end

    def base_txt_params
      { type: 'TXT', name: ACME_CHALLENGE_SUBDOIMAIN }
    end

    def create_txt_record!(token)
      txt_record_params = base_txt_params.merge(content: token, ttl: TOKEN_TTL)
      exist_txt_record_id = fetch_txt_record&.fetch(:id, nil)
      if exist_txt_record_id
        connection.put("zones/#{zone_id}/dns_records/#{exist_txt_record_id}", txt_record_params)
        LOGGER.info(" + Updated `#{ACME_CHALLENGE_SUBDOIMAIN}` TXT to `#{token}`")
      else
        connection.post("zones/#{zone_id}/dns_records", txt_record_params)
        LOGGER.info(" + Created `#{ACME_CHALLENGE_SUBDOIMAIN}` TXT `#{token}`")
      end
    end

    def delete_txt_record!
      exist_txt_record_id = fetch_txt_record&.fetch(:id, nil)
      if exist_txt_record_id
        connection.delete("zones/#{zone_id}/dns_records/#{exist_txt_record_id}")
      else
        raise ArgumentError, 'ERROR: Record does not exist.'
      end
    end
  end
end

class Main
  class << self
    def run(method, args)
      case method
      when 'deploy_challenge'
        create_txt_record(args)
      when 'clean_challenge'
        delete_txt_record(args)
      when 'deploy_cert'
        deploy_cert(args)
      when 'unchanged_cert'
        LOGGER.info(" + Do nothing...")
      when 'startup_hook'
        LOGGER.info(" + Do nothing...")
      else
        LOGGER.error("ERROR: Method not found.")
        exit 1
      end
    end

    def create_txt_record(args)
      token = args[2]
      CloudFlareHandler.create_txt_record!(token)

      if DnsPropagandaChecker.wait_dns_propagated(ACME_CHALLENGE_SUBDOIMAIN, token)
        return true
      else
        raise 'ERROR: DNS TXT record not propagated!'
      end
    end

    def delete_txt_record(args)
      CloudFlareHandler.delete_txt_record!
      LOGGER.info(" + Successfully deleted.")
    end

    def deploy_cert(args)
      domain, privkey_pem, cert_pem, fullchain_pem, chain_pem, timestamp = *args
      LOGGER.info(" + ssl_certificate: \n#{fullchain_pem}")
      LOGGER.info(" + ssl_certificate_key: \n#{privkey_pem}")
    end
  end
end

Main.run(ARGV[0], ARGV[1..-1])
