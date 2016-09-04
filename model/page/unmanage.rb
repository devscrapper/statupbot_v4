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
  class Unmanage < Page
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

    def initialize (duration, browser)
      count_try = 3
      sleep 5
      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "duration"}) if duration.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser"}) if browser.nil?

        sleep 5

        start_time = Time.now

        links = browser.all_links

        super(browser.url,
              browser.title,
              duration,
              Time.now - start_time)

        ar = @uri.hostname.split(".")
        host = "#{ar[ar.size-2]}.#{ar[ar.size-1]}"
        @inside_hostname_links = []
        @outside_hostname_links = []
        @inside_fqdn_links = []
        @outside_fqdn_links = []

        links.each { |d|
          begin
            l = Pages::Link.new(d["href"], @title, d["text"])

          rescue Exception => e
            @@logger.an_event.debug "link #{d["href"]} #{e.message}"

          else
            @inside_hostname_links << l if l.uri.hostname.end_with?(host)
            @outside_hostname_links << l if !l.uri.hostname.end_with?(host)
            @inside_fqdn_links << l if l.uri.hostname == @uri.hostname
            @outside_fqdn_links << l if l.uri.hostname != @uri.hostname
          end
        }
        raise Error.new(PAGE_NONE_INSIDE_LINKS) if @inside_hostname_links.empty? and @inside_fqdn_links.empty?

      rescue Exception => e
        @@logger.an_event.debug  "creation website unmanage page : #{e.message}"
        if count_try > 0 and !Pages::Captcha.is_a?(browser)
          count_try -= 1
          #recharge la page courante
          browser.reload
          @@logger.an_event.debug "website unmanage page reloaded, try again"
          retry

        end
        raise Error.new(PAGE_NOT_CREATE, :error => e)

      else
        @@logger.an_event.debug "#{self.to_s}"

      end
    end

     #----------------------------------------------------------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    #retourne un Objet Link
    def link(around)

      @@logger.an_event.debug "around #{around}"

      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "around"}) if around.nil?

        link = nil

        case around

          when :inside_fqdn
            # on ne bloque pas un surf sur un site que l'on ne gere pas et maitrise pas les stats
            # donc si pas de lien qui sont dans le meême fqdn, on elargie au hostname
            # si pas de lien qui ont le même hostname, on elargie au hors site
            if @inside_fqdn_links.size > 0
              link = @inside_fqdn_links.shuffle!.shift
            elsif @inside_hostname_links.size > 0
              link = @inside_hostname_links.shuffle!.shift
            else
              link = @outside_fqdn_links.shuffle!.shift
            end

          when :inside_hostname
            # on ne bloque pas un surf sur un site que l'on ne gere pas et maitrise pas les stats
            # si pas de lien qui ont le même hostname, on elargie au hors site
            if @inside_hostname_links.size > 0
              link = @inside_hostname_links.shuffle!.shift
            else
              link = @outside_fqdn_links.shuffle!.shift
            end

          when :outside_hostname

            link = @outside_hostname_links.shuffle!.shift

          when :outside_fqdn

            link = @outside_fqdn_links.shuffle!.shift

          else
            @@logger.an_event.warn "around #{around} unknown"

            raise Error.new(PAGE_AROUND_UNKNOWN, :values => {:around => around})
        end

        raise Error.new(PAGE_NONE_LINK_BY_AROUND, :values => {:url => url, :around => around}) if link.nil?

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
      "Page : #{self.class.name}\n" +
          super.to_s +
          "inside_fqdn_links (#{@inside_fqdn_links.size}) : #{@inside_fqdn_links}\n" +
          "inside_hostname_links (#{@inside_hostname_links.size}) : #{@inside_hostname_links}\n" +
          "outside_hostname_links (#{@outside_hostname_links.size}) : #{@outside_hostname_links}\n" +
          "outside_fqdn_links (#{@outside_fqdn_links.size}) : #{@outside_fqdn_links}\n"

    end

  end
end
