require_relative '../../../lib/error'

module Visits
  module Advertisings
    class Adsense < Advertising

      DOMAINS = ["www.googleadservices.com", "googleads.g.doubleclick.net"]

      include Errors

      def initialize(advertiser)

        @@logger.an_event.debug "advertiser #{advertiser}"

        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "advertiser"}) if advertiser.nil?
        @advertiser = advertiser
      end

      #advert retourne un Link_element ElementStub)
      def advert(browser)
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser"}) if browser.nil?
        link = nil
        links = []
        count_try = 0
        adverts = []


        begin
          links = browser.driver.get_windows.map { |w|
            @@logger.an_event.debug "window : #{w.to_s}"
            if DOMAINS.include?(w["domain"])
              @@logger.an_event.debug "domain : #{w["domain"]}"
              frame = browser.driver.domain(w["domain"])
              @@logger.an_event.debug "frame : #{frame.inspect}"
              adverts = frame.link("/.*#{w["domain"]}.*/").collect_similar
              @@logger.an_event.debug "adverts : adverts"
              adverts.each { |l|
                @@logger.an_event.debug "adverts : #{l} => #{l.fetch('href')}"
              }
              adverts2 = frame.link("/.*.*/").collect_similar
              @@logger.an_event.debug "adverts2 : adverts2"
              adverts2.each { |l|
                @@logger.an_event.debug "adverts2 : #{l} => #{l.fetch('href')}"
              }
              adverts
            end
          }.compact.flatten
          links.each { |l|
            @@logger.an_event.debug "link : #{{"href" => l.fetch("href"), "text" => l.fetch("text")}}"
          }
          raise "no advert link found" if links.empty?

        rescue Exception => e
          @@logger.an_event.warn "#{e.message}, try #{count_try}"
          sleep 5
          count_try += 1
          retry if count_try < 3
          @@logger.an_event.error e.message
          raise Errors::Error.new(NONE_ADVERT, :error => e)

        else
          @@logger.an_event.info "count advert #{self.class.name} links : #{links.size}"
          link = links.sample
          @@logger.an_event.debug "advert link chosen #{link}"

        end

        link

      end

    end
  end

end