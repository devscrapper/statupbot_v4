require_relative '../../../lib/error'

module Visits
  module Advertisings
    class Adwords < Advertising

      attr_reader :fqdns # array de fqdn de l'advert adwords déclaré dans statupweb
      include Errors

      def initialize(fqdns, advertiser)

        @@logger.an_event.debug "fqdns #{fqdns}"
        @@logger.an_event.debug "advertiser #{advertiser}"

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "advertiser"}) if advertiser.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "fqdns"}) if fqdns.nil?
        @advertiser = advertiser
        @fqdns = fqdns
      end

      #advert retourne un Link_element ElementStub contenant le domain de Advertiser.domain
      def advert(browser)
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser"}) if browser.nil?
        link = nil

        begin
          adwords = browser.engine_search.adverts(browser.body)
          adwords.each { |adword| @@logger.an_event.debug "adword : #{adword}" }

          #TODO remplacer @fqdns par @fqdns
          @fqdns.each { |fqdn| @@logger.an_event.debug "fqdns : #{fqdn}" }
          tmp_fqdns = @fqdns.dup

          # suppression des adwords dont le href n'est pas dans liste de fqdn
          href_adwords =[]
          adwords.map { |adword| adword[:href] }.each { |href|
            tmp_fqdns.each { |fqdn|
              href_adwords << href if href.include?(fqdn)
            }
          }

          raise "none fqdns advertisings #{@fqdns} found in adwords list #{adwords}" if href_adwords.empty?

          links = href_adwords.map { |href| browser.driver.link("#{href}") }
          @@logger.an_event.debug "links : #{links}"

          links.delete_if { |link| !link.exists? }
          @@logger.an_event.debug "links : #{links}"

          raise "none fqdn advertising visible" if links.empty?

          link = links.shuffle[0]
          @@logger.an_event.debug "link : #{link}"

        rescue Exception => e
          @@logger.an_event.error e.message
          raise Error.new(ADVERTISING_NOT_FOUND, :error => e, :values => {:advertising => self.class.name})

        else
          @@logger.an_event.info "advertising #{self.class.name} found #{link}"

        end

        link

      end

    end
  end

end
