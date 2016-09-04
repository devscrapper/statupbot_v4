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
  class EngineSearch < Page
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
    attr_reader :input, # zone de saisie des mot clés
                :type, #type de la zone de saisie
                :submit_button # bouton de validation du formulaire de recherche
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
      sleep 5
      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visit"}) if visit.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser"}) if browser.nil?

        start_time = Time.now

        @input = browser.engine_search.id_search
        @type = browser.engine_search.type_search
        @submit_button = browser.engine_search.label_button_search

        #teste la présence de la zone de saisie
        #parfois la page n'est pas affichée mais l'url ipv4.google... est bien dans la zone de l'url
        #dans ce cas on recharge la page
        raise Error.new(PAGE_NONE_ELEMENT,
                        :values => {:url => browser.url,
                                    :type => @type,
                                    :id => @input}) unless browser.exist_element?(type, input)

        super(browser.url,
              browser.title,
              visit.referrer.search_duration,
              Time.now - start_time)

      rescue Exception => e
        @@logger.an_event.debug  "creation engine search page : #{e.message}"
        if count_try > 0 and !Pages::Captcha.is_a?(browser)
          count_try -= 1
          #recharge la page courante
          browser.reload
          @@logger.an_event.debug "engine search page reloaded, try again"
          retry

        end

        raise Error.new(PAGE_NOT_CREATE, :error => e)

      ensure
        @@logger.an_event.debug "page engine search #{self.to_s}"

      end
    end


  end
end
