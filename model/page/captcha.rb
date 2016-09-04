require_relative '../../lib/error'
require_relative '../../lib/captchas'
require_relative '../../lib/flow'


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
  class Captcha < Page
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
    attr_reader :input, # zone de saisie du capcha
                :type, #type de la zone de saisie
                :submit_button, # bouton de validation du formulaire de saisie de captcha
                :image, # le capcha sous forme image
                :text # la repr�sentation du captcha sous forme d'une chaine de caractere
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

    def initialize(browser, id_visitor, home_visitor)
      count_try = 3
      sleep 5
      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser"}) if browser.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "id_visitor"}) if id_visitor.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "home_visitor"}) if home_visitor.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser.engine_search"}) if browser.engine_search.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser.engine_search.id_captcha"}) if browser.engine_search.id_captcha.nil? or browser.engine_search.id_captcha.empty?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser.engine_search.type_captcha"}) if browser.engine_search.type_captcha.nil? or browser.engine_search.type_captcha.empty?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser.engine_search.label_button_captcha"}) if browser.engine_search.label_button_captcha.nil? or browser.engine_search.label_button_captcha.empty?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser.engine_search.coord_captcha"}) if browser.engine_search.coord_captcha.empty?

        @input = browser.engine_search.id_captcha
        @type = browser.engine_search.type_captcha
        @submit_button = browser.engine_search.label_button_captcha


        #teste la présence de la zone de saisie
        #parfois la page n'est pas affichée mais l'url ipv4.google... est bien dans la zone de l'url
        #dans ce cas on recharge la page
        raise Error.new(PAGE_NONE_ELEMENT,
                        :values => {:url => browser.url,
                                    :type => @type,
                                    :id => @input}) unless browser.exist_element?(type, input)

        @@logger.an_event.debug "captcha page not empty"
        super(browser.url,
              browser.title,
              0,
              0)

        i = 0
        while (screenshot_file = Flow.new(home_visitor, "screenshot", id_visitor, Date.today, i = i + 1, ".png")).exist?
        end
        @@logger.an_event.debug "screenshot file #{screenshot_file}"

        browser.take_screenshot(screenshot_file)

        i = 0
        while (captcha_file = Flow.new(home_visitor, "captcha", id_visitor, Date.today, i = i + 1, ".png")).exist?
        end
        @@logger.an_event.debug "captcha file #{captcha_file}"

        browser.take_captcha(captcha_file, browser.engine_search.coord_captcha)

        @text = Captchas::convert_to_text(:screenshot => screenshot_file.absolute_path,
                                          :captcha => captcha_file.absolute_path,
                                          :id_visitor => id_visitor)

        @@logger.an_event.debug "captcha converted to string : #{@text}"

      rescue Error => e

        if e.code == PAGE_NONE_ELEMENT and count_try > 0
          @@logger.an_event.debug "captcha page empty, try #{count_try}"
          count_try -= 1
          #recharge la page courante
          browser.reload
          @@logger.an_event.debug "captcha page reloaded, try again"
          retry

        end

        @@logger.an_event.error "captcha converted to string : #{e.message}"
        raise Error.new(PAGE_NOT_CREATE, :error => e)

      rescue Exception => e

        @@logger.an_event.error "captcha converted to string : #{e.message}"
        raise Error.new(PAGE_NOT_CREATE, :error => e)

      else
        # i = 0
        # while (screenshot_file = Flow.new(home_visitor, "screenshot", id_visitor, Date.today, i = i + 1, ".png")).exist?
        #   screenshot_file.delete
        # end
        # les screenshot ou les captcha seront supprimé par la suppression du repertoire d"execution du visitor lors de l'hinume"
        @@logger.an_event.info "captcha converted to string : #{@text}"

      ensure

        @@logger.an_event.debug "#{self.to_s}"

      end

    end

    def self.is_a?(browser)
      current_url = browser.url
      bool = browser.engine_search.is_captcha_page?(current_url)
      if bool
        @@logger.an_event.info "current url #{current_url} is captcha page"

      else
        @@logger.an_event.info "current url #{current_url} not captcha page"

      end
      bool
    end

    def to_s
      super +
          "input : #{@input}\n" +
          "type : #{@type}\n" +
          "submit_button : #{@submit_button}\n" +
          "image : #{@image}\n" +
          "str : #{@text}\n"
    end

  end
end
