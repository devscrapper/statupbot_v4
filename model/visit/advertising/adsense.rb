require_relative '../../../lib/error'

module Visits
  module Advertisings
    class Adsense < Advertising

      DOMAINS = ["tpc.googlesyndication.com", #w3school
                 "www.googleadservices.com",
                 "googleads.g.doubleclick.net"]

      BLOC_CLASS_NAME = "tr > td > ins.adsbygoogle"
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


        begin
          links = browser.driver.get_windows.map { |w|

            @@logger.an_event.debug "window : #{w.to_s}"

            if DOMAINS.include?(w["domain"])

              @@logger.an_event.debug "domain : #{w["domain"]}"

              frame = browser.driver.domain(w["domain"])
              @@logger.an_event.debug "frame : #{frame.inspect}"

              adverts = []

              # on recupere les liens qui sont dans les DOMAIN
              for d in DOMAINS
                ads = frame.link("/.*#{d}.*/").collect_similar
                ads.map! { |a| {
                    :href => a.fetch("href"),
                    :text => a.fetch("text"),
                    :link => a
                }
                }.select! { |a| !a[:href].include?('whythisad') }

                @@logger.an_event.debug "#{ads.size} adverts found for #{d} : "
                ads.each { |a| @@logger.an_event.debug "#{a}" }
                adverts += ads
              end

              # trace tous les liens pour savoir ce qui se passe.
              all_links = frame.link("/.*.*/").collect_similar
              all_links.map! { |l| {
                  :href => l.fetch("href"),
                  :text => l.fetch("text"),
                  :link => l
              }
              }
              @@logger.an_event.debug "#{all_links.size} links found"
              all_links.each { |l| @@logger.an_event.debug "#{l}" }

              adverts
            end

          }.compact.flatten

          @@logger.an_event.debug "#{links.size} adverts found"

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

        link[:link]

      end

      def bloc
        BLOC_CLASS_NAME
      end


      def to_s
        super.to_s

      end

    end
  end

end