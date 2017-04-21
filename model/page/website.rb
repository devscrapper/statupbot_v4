require_relative '../../lib/error'

module Pages
  #----------------------------------------------------------------------------------------------------------------
  # action                    | id | produce Page
  #----------------------------------------------------------------------------------------------------------------
  # go_to_start_landing	      | a	 | Website
  # go_to_start_engine_search	| b	 | SearchEngine
  # go_back_engine_search	    | c	 | SearchEngine
  # go_to_landing	            | d	 | Website
  # go_to_referral	          | e	 | UnManage
  # go_to_search_engine 	    | f	 | SearchEngine
  # sb_search 	              | 0	 | Results
  # sb_final_search 	        | 1	 | Results
  # cl_on_next 	              | A	 | Results
  # cl_on_previous 	          | B	 | Results
  # cl_on_result 	            | C	 | UnManage
  # cl_on_landing 	          | D	 | Website
  # cl_on_link_on_website 	  | E	 | Website
  # cl_on_advert	            | F	 | UnManage
  # cl_on_link_on_unknown	    | G	 | UnManage
  # cl_on_link_on_advertiser	| H	 | UnManage
  #----------------------------------------------------------------------------------------------------------------
  class Website < Page
    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors

    #----------------------------------------------------------------------------------------------------------------
    # message exception
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # constant
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # variable de class
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------
    attr_reader :inside_fqdn_links,
                :inside_hostname_links,
                :outside_hostname_links,
                :outside_fqdn_links

    #----------------------------------------------------------------------------------------------------------------
    # class methods
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # instance methods
    #----------------------------------------------------------------------------------------------------------------


    #----------------------------------------------------------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def initialize(visit, browser)
      count_try = 3

      # sort le calcule de la priochaine duration car si il y a reload de la page en cas d'erreur, on perd
      # autant de duration que de reload => il manque alors des durations pour des prochaines page => ERROR et goback en boucle => overttl
      next_duration = visit.next_duration
      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visit"}) if visit.nil?
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser"}) if browser.nil?

        start_time = Time.now

        links = browser.all_links

        super(browser.url,
              browser.title,
              next_duration,
              Time.now - start_time)

        ar = @uri.hostname.split(".")
        host = "#{ar[ar.size-2]}.#{ar[ar.size-1]}"
        @inside_hostname_links = []
        @outside_hostname_links = []
        @inside_fqdn_links = []
        @outside_fqdn_links = []

        links.each { |d|
          begin
            l = Pages::Link.new(d["href"], @title, d["text"], d["coords"], d["sizes"])
          rescue
          else
            @inside_hostname_links << l if l.uri.hostname.end_with?(host)
            @outside_hostname_links << l if !l.uri.hostname.end_with?(host)
            @inside_fqdn_links << l if l.uri.hostname == @uri.hostname
            @outside_fqdn_links << l if l.uri.hostname != @uri.hostname
          end
        }

        raise Errors::Error.new(Pages::Page::PAGE_NONE_INSIDE_LINKS) if @inside_hostname_links.empty? and @inside_fqdn_links.empty?

      rescue Exception => e
        @@logger.an_event.debug "creation website page : #{e.message}"
        if count_try > 0 and !Pages::Captcha.is_a?(browser)
          count_try -= 1
          #recharge la page courante
          browser.reload
          @@logger.an_event.debug "website page reloaded, try again"
          retry

        end
        raise Errors::Error.new(PAGE_NOT_CREATE, :error => e)

      ensure
        @@logger.an_event.debug "#{self.to_s}"

      end
    end

    def link(around)

      @@logger.an_event.debug "around #{around}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "around"}) if around.nil?

        link = nil

        case around

          when :inside_fqdn

            link = @inside_fqdn_links.shuffle!.shift

          when :inside_hostname

            link = @inside_hostname_links.shuffle!.shift

          when :outside_hostname

            link = @outside_hostname_links.shuffle!.shift

          when :outside_fqdn

            link = @outside_fqdn_links_links.shuffle!.shift

          else
            @@logger.an_event.warn "around #{around} unknown"

            raise Errors::Error.new(PAGE_AROUND_UNKNOWN, :values => {:around => around})
        end

        raise Errors::Error.new(PAGE_NONE_LINK_BY_AROUND, :values => {:url => url, :around => around}) if link.nil?

      rescue Exception => e
        @@logger.an_event.error e.message
        raise e

      else
        @@logger.an_event.debug "chosen link #{link.to_s}"

        link

      ensure

      end

    end

    def to_s
      res = super
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += "| Inside Fqdn Links (#{@inside_fqdn_links.size})                                                                                                                     |" + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += '| Window tab                | Text                                     | Url                                                                                    |' + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      @inside_fqdn_links.each { |l| res += l.to_s }
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += "| Inside Hostname Links (#{@inside_hostname_links.size})                                                                                                             |" + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += '| Window tab                | Text                                     | Url                                                                                    |' + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      @inside_hostname_links.each { |l| res += l.to_s }
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += "| Outside Hostname Links (#{@outside_hostname_links.size})                                                                                                             |" + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += '| Window tab                | Text                                     | Url                                                                                    |' + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      @outside_hostname_links.each { |l| res += l.to_s }
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += "| Outside fqdn Links (#{@outside_fqdn_links.size})                                                                                                                   |" + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += '| Window tab                | Text                                     | Url                                                                                    |' + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      @outside_fqdn_links.each { |l| res += l.to_s }
      res += "|- END - DETAILS PAGE ------------------------------------------------------------------------------------------------------------------------------------------|"

      res
    end

  end
end
