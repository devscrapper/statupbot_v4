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
  class Error < Page
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

    #----------------------------------------------------------------------------------------------------------------
    # leve une exception si :
    # le proxy de genolocation retourne une erreur
    # le proxy Sahi n'arrive pas acceder à l'url demandée
    # si pas de pb connu alors retourne false
    #----------------------------------------------------------------------------------------------------------------
    def self.is_a?(browser)
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      url = browser.url
      body = browser.body

      sahi_connect_error = body.css("body > center > div > div > b").text
      @@logger.an_event.debug "sahi_connect_error : #{sahi_connect_error} => #{sahi_connect_error == "Sahi could not connect to the desired URL" }"

      geolocation_proxy_connect_error = body.css("body").text
      @@logger.an_event.debug "geolocation_proxy_connect_error : #{geolocation_proxy_connect_error.to_i >= 400}"

      raise Errors::Error.new(Pages::Page::URL_NOT_FOUND, :values => {:url => url}) if sahi_connect_error == "Sahi could not connect to the desired URL"
      raise Errors::Error.new(Pages::Page::PROXY_GEOLOCATION, :values => {:url => url, :error => geolocation_proxy_connect_error}) if geolocation_proxy_connect_error.to_i >= 400 #error http client et serveur

      false
    end

    def to_s
      super
    end

  end
end
