require_relative '../../lib/error'
module Browsers
  class Chrome < Browser
    #----------------------------------------------------------------------------------------------------------------
    # message exception
    #----------------------------------------------------------------------------------------------------------------

    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors
    #----------------------------------------------------------------------------------------------------------------
    # class methods
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # instance methods
    #----------------------------------------------------------------------------------------------------------------
    #["browser", "Firefox"]
    #["browser_version", "16.0"]
    #["operating_system", "Windows"]
    #["operating_system_version", "7"]
    def initialize(visitor_dir, browser_details)
      @@logger.an_event.debug "name #{browser_details[:name]}"
      @@logger.an_event.debug "version #{browser_details[:version]}"


      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser name"}) if browser_details[:name].nil? or browser_details[:name] == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser version"}) if browser_details[:version].nil? or browser_details[:version] == ""


        super(visitor_dir,
              browser_details,
              "#{browser_details[:name]}_#{browser_details[:version]}_#{browser_details[:listening_ip_proxy]}_#{browser_details[:listening_port_proxy]}",
              NO_REFERER)
      rescue Exception => e
        @@logger.an_event.error "chrome #{@version} initialize : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "chrome #{@version} initialize"

      ensure

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # display_start_page
    #----------------------------------------------------------------------------------------------------------------
    # ouvre un nouvelle fenetre du navigateur adaptée aux propriété du naviagateur et celle de la visit
    # affiche la root page du site https pour initialisé le référer à non défini
    #@driver.navigate_to "http://jenn.kyrnin.com/about/showreferer.html"
    #fullscreen=yes|no|1|0 	Whether or not to display the browser in full-screen mode. Default is no. A window in full-screen mode must also be in theater mode. IE only
    #height=pixels 	The height of the window. Min. value is 100
    #left=pixels 	The left position of the window. Negative values not allowed
    #menubar=yes|no|1|0 	Whether or not to display the menu bar
    #status=yes|no|1|0 	Whether or not to add a status bar
    #titlebar=yes|no|1|0 	Whether or not to display the title bar. Ignored unless the calling application is an HTML Application or a trusted dialog box
    #top=pixels 	The top position of the window. Negative values not allowed
    #width=pixels 	The width of the window. Min. value is 100
    #@driver.open_start_page("width=#{@width},height=#{@height},fullscreen=0,left=0,menubar=1,status=1,titlebar=1,top=0")
    # pour maitriser le referer on passe par un site local en https qui permet de ne pas affecter le referer
    # incontournable sinon Google analityc enregistre la page de lancement de Sahi initializer
    #----------------------------------------------------------------------------------------------------------------
    # input : url (String)
    # output : RAS
    # exception : RAS
    #----------------------------------------------------------------------------------------------------------------
    def display_start_page(start_url, visitor_id)
      @@logger.an_event.debug "start_url : #{start_url}"
      @@logger.an_event.debug "visitor_id : #{visitor_id}"


      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "start_url"}) if start_url.nil? or start_url ==""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_id"}) if visitor_id.nil? or visitor_id == ""

        window_parameters = "menubar=1,status=1,titlebar=1,top=0"
        @@logger.an_event.debug "windows parameters : #{window_parameters}"

        encode_start_url = Addressable::URI.encode_component(start_url, Addressable::URI::CharacterClasses::UNRESERVED)

        start_page_visit_url = "http://#{$start_page_server_ip}:#{$start_page_server_port}/start_link?method=#{@method_start_page}&url=#{encode_start_url}&visitor_id=#{visitor_id}"
        @@logger.an_event.debug "start_page_visit_url : #{start_page_visit_url}"

        super(start_page_visit_url, window_parameters)

        click_on(start_url)

      rescue Exception => e
        @@logger.an_event.debug "#{name} display start page : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "#{name} display start page"

      ensure

      end


    end

    def get_pid
      get_pid_by_title
    end

    def kill
      kill_by_pid
    end

    #-----------------------------------------------------------------------------------------------------------------
    # open
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # exception :
    # StandardError :
    # si il n'a pas été possible de lancer le browser  au moyen de sahi
    # si le titre de la fenetre du browser n'a pas pu être initialisé avec ld_browser
    # si le pid du browser n'a pas pu être recuperé
    #-----------------------------------------------------------------------------------------------------------------
    #   1-kill tous les process edge existants par securité car il nepeut y avoir qu'une instance de edge à la fois car
    #   il utilise le proxy systeme
    #   2-ouvre le browser
    #   3-recupere le pid du browser
    #   4-reupere le handle de la fenetre du browser
    #-----------------------------------------------------------------------------------------------------------------
    def open
      #TODO suivre les cookies du browser : s'assurer qu'il sont vide et alimenté quand il faut hahahahaha

      begin
        @driver.open

        #recuêration de pid du navigateur
        get_pid

        #recuperation du handle de la fenetre du navigateur
        get_window_by_pid

      rescue Exception => e
        @@logger.an_event.error "browser #{name} open : #{e.message}"
        raise Error.new(BROWSER_NOT_OPEN, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "browser #{name} open"

      ensure

      end

    end


    def running?
      running_by_pid?
    end

    #----------------------------------------------------------------------------------------------------------------
    # set_input_search
    #----------------------------------------------------------------------------------------------------------------
    # affecte les mot clés dans la zone de recherche du moteur de recherche
    #----------------------------------------------------------------------------------------------------------------
    # input :
    # type :
    # input :
    # keywords :
    # output : RAS
    #----------------------------------------------------------------------------------------------------------------
    def set_input_search(type, input, keywords)
      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "type"}) if type.nil? or type == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "input"}) if input.nil? or input == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "keywords"}) if keywords.nil? or keywords == ""

        r = "#{type}(\"#{input}\", \"#{keywords}\")"
        eval(r)
        sleep(4) #liasse le temps à Chrome de raffraichir la page.
        # google pour IE au travers de sahi fait ubn redirect wevrs www.google.fr/webhp? ... en supprimant les keywords
        # on rejoue alors l'affectation de la zone de recherche par le keyword
        eval(r)

      rescue Exception => e
        @@logger.an_event.fatal "set input search #{type} #{input} with #{keywords} : #{e.message}"
        raise Error.new(BROWSER_NOT_SET_INPUT_SEARCH, :values => {:browser => name, :type => type, :input => input, :keywords => keywords}, :error => e)

      else
        @@logger.an_event.debug "set input search #{type} #{input} with #{keywords}"

      end
    end

  end
end
