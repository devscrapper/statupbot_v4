require_relative '../../../lib/error'

module Visits
  module Advertisings
    class Adsense < Advertising

      DOMAINS = ["googleads.g.doubleclick.net", "tpc.googlesyndication.com"]

      include Errors

      def initialize(advertiser)

        @@logger.an_event.debug "advertiser #{advertiser}"

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "advertiser"}) if advertiser.nil?
        @advertiser = advertiser
      end

      #advert retourne un Link_element ElementStub)
      def advert(driver)
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "driver"}) if driver.nil?
        link = nil
        links = []
        count_try = 0
        adverts = []
        begin
          DOMAINS.each { |domain|
            frame = driver.domain(domain)

            if frame.domain_exist?
              adverts += frame.link("/.*googleads.g.doubleclick.net.*/").collect_similar
              adverts += frame.link("/.*googleadservices.*/").collect_similar
              adverts.each{|a|  @@logger.an_event.debug "advert : #{a.text}"}
              links += adverts
            else
              @@logger.an_event.debug "frame with domain <#{domain}> not exist"
            end
=begin
            adverts.map! { |f|
              href = f.fetch("href")
              frame.link(href) unless /.*googleads.g.doubleclick.net.*/.match(href).nil?
            }.compact!
=end
          }
          raise "no advert link found" if links.empty?

        rescue Exception => e
          @@logger.an_event.warn "#{e.message}, try #{count_try}"
          sleep 5
          count_try += 1
          retry if count_try < 3
          @@logger.an_event.error e.message
          raise Error.new(NONE_ADVERT, :error => e)

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
