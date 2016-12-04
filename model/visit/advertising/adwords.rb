require_relative '../../../lib/error'

module Visits
  module Advertisings
    class Adwords < Advertising

      attr_reader :fqdns # array de fqdn de l'advert adwords déclaré dans statupweb
      include Errors

      def initialize(fqdns, advertiser)
        @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
        @@logger.an_event.debug "fqdns #{fqdns}"
        @@logger.an_event.debug "advertiser #{advertiser}"

        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "advertiser"}) if advertiser.nil?
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "fqdns"}) if fqdns.nil?
        @advertiser = advertiser
        @fqdns = fqdns
      end

      #advert retourne un Link_element ElementStub contenant le domain de Advertiser.domain
      def advert(browser)
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser"}) if browser.nil?
        link = nil

        begin
          #url = browser.url
          adwords = []
          #parfois, browser body ne recupere pas le contenu de la page Google contenant les resulats et les adword
          # alors que la page est affichée dans le navigateur : blurps !!!
          # par sécurité on attend et test à concurrence de 60s, jusqu'à ce que la liste ne soit pas vide.
          # en desespoir de cause, si le pb persiste alors elle sera vide.
          # ou bien il ny a vraimenet pas d'awords sur la page Google.
          wait(30, true, 1.3) {
            body = browser.body
            adwords = browser.engine_search.adverts(body)
            !adwords.empty?
          }
          #TODO faire un affichage comme pour les links
          adwords.each { |adword| @@logger.an_event.debug "adword : #{adword}" }

          #TODO remplacer @fqdns par @fqdn
          @fqdns.each { |fqdn| @@logger.an_event.debug "fqdns : #{fqdn}" }
          tmp_fqdns = @fqdns.dup

          # suppression des adwords dont le href n'est pas dans liste de fqdn
          href_adwords =[]
          adwords.map { |adword| adword[:href] }.each { |hrefs| hrefs.each { |href|
            tmp_fqdns.each { |fqdn| href_adwords << href if href.include?(fqdn) }
          }
          }


          raise "none fqdn advertising #{@fqdns} found in adwords list #{adwords}" if href_adwords.empty?

          links = href_adwords.map { |href| browser.driver.link("#{href}") }
          @@logger.an_event.debug "links : #{links}"

          links.delete_if { |link| !link.exists? }
          @@logger.an_event.debug "links : #{links}"

          raise "none fqdn advertising visible" if links.empty?

          link = links.shuffle[0]
          @@logger.an_event.debug "link : #{link}"

        rescue Exception => e
          @@logger.an_event.error "advertising #{self.class.name} found #{link} : #{e.message}"
          raise Errors::Error.new(ADVERTISING_NOT_FOUND, :error => e, :values => {:advertising => self.class.name})

        else
          @@logger.an_event.info "advertising #{self.class.name} found #{link}"

        end

        link

      end

      private

      def wait(timeout, exception = false, interval=0.2)

        if !block_given?
          sleep(timeout)
          return
        end

        #timeout = interval if $staging == "development" # on execute une fois

        while (timeout > 0)
          sleep(interval)
          timeout -= interval
          begin
            return if yield
          rescue Exception => e
            @@logger.an_event.warn "try again : #{e.message}"
          else
            @@logger.an_event.debug "try again."
          end
        end

        raise e if !e.nil? and exception == true

      end

    end
  end

end
