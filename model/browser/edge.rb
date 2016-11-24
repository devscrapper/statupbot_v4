# encoding: utf-8
require_relative '../../lib/error'
module Browsers
  class Edge < Browser
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
      @@logger.an_event.debug "visitor_dir #{visitor_dir}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser name"}) if browser_details[:name].nil? or browser_details[:name] == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser version"}) if browser_details[:version].nil? or browser_details[:version] == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_dir"}) if visitor_dir.nil? or visitor_dir == ""

        super(visitor_dir,
              browser_details,
              "#{browser_details[:name].gsub(" ", "_")}",
              DATA_URI,
              NO_ACCEPT_POPUP)

      rescue Exception => e
        @@logger.an_event.error "edge #{@version} initialize : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "edge #{@version} initialize"

      ensure

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # display_start_page
    #----------------------------------------------------------------------------------------------------------------
    # ouvre un nouvelle fenetre du navigateur adaptée aux propriété du naviagateur et celle de la visit
    # affiche la root page du site https pour initialisé le référer à non défini
    #@driver.navigate_to "http://jenn.kyrnin.com/about/showreferer.html"
    #channelmode=yes|no|1|0 	Whether or not to display the window in theater mode. Default is no. IE only
    #fullscreen=yes|no|1|0 	Whether or not to display the browser in full-screen mode. Default is no. A window in full-screen mode must also be in theater mode. IE only
    #height=pixels 	The height of the window. Min. value is 100
    #left=pixels 	The left position of the window. Negative values not allowed
    #menubar=yes|no|1|0 	Whether or not to display the menu bar
    #resizable=yes|no|1|0 	Whether or not the window is resizable. IE only
    #scrollbars=yes|no|1|0 	Whether or not to display scroll bars. IE, Firefox & Opera only
    #status=yes|no|1|0 	Whether or not to add a status bar
    #titlebar=yes|no|1|0 	Whether or not to display the title bar. Ignored unless the calling application is an HTML Application or a trusted dialog box
    #toolbar=yes|no|1|0 	Whether or not to display the browser toolbar. IE and Firefox only
    #top=pixels 	The top position of the window. Negative values not allowed
    #width=pixels 	The width of the window. Min. value is 100
    #@driver.open_start_page("width=#{@width},height=#{@height},channelmode=0,fullscreen=0,left=0,menubar=1,resizable=1,scrollbars=1,status=1,titlebar=1,toolbar=1,top=0")

    #----------------------------------------------------------------------------------------------------------------
    # input : url (String)
    # output : Objet Page
    # exception :
    # StandardError :
    # si il est impossble d'ouvrir la page start
    # StandardError :
    # Si il est impossible de recuperer les propriétés de la page
    #----------------------------------------------------------------------------------------------------------------
    def display_start_page (start_url, visitor_id)

      @@logger.an_event.debug "start_url : #{start_url}"
      @@logger.an_event.debug "visitor_id : #{visitor_id}"
      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "start_url"}) if start_url.nil? or start_url ==""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_id"}) if visitor_id.nil? or visitor_id == ""


        window_parameters = "channelmode=0,fullscreen=0,left=0,menubar=1,resizable=1,scrollbars=1,status=1,titlebar=1,toolbar=1"
        @@logger.an_event.debug "windows parameters : #{window_parameters}"

        # edge genere une page d'erreur directement et qui ne passe par Sahi donc elle n'est pas manipulable et bloque donc
        # la visite.
        if is_reachable_url?(url_start_page(start_url, visitor_id, @method_access_popup))
          super(start_url, visitor_id, window_parameters)

        else
          raise Errors::Error.new(Pages::Page::URL_NOT_FOUND, :values => {:url => url_start_page})

        end

      rescue Exception => e
        @@logger.an_event.error "browser display start page : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "browser display start page"

      end
    end

    def get_pid
      get_pid_by_process_name
    end

    def kill
      kill_by_process_name
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
        #par securité on fait du nettoyage. On peut le faire car il y a qu'une seule instance du navigateur à la fois
        kill if running?

        @driver.open

        get_pid

        get_window_by_pid

      rescue Exception => e
        @@logger.an_event.error "browser #{name} open : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_OPEN, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "browser #{name} open"

      ensure

      end

    end

    def running?
      running_by_process_name?
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
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "type"}) if type.nil? or type == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "input"}) if input.nil? or input == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "keywords"}) if keywords.nil? or keywords == ""

        r = "#{type}(\"#{input}\", \"#{keywords}\")"
        eval(r)
        sleep(4) #liasse le temps à Chrome de raffraichir la page.
        # google pour IE au travers de sahi fait ubn redirect wevrs www.google.fr/webhp? ... en supprimant les keywords
        # on rejoue alors l'affectation de la zone de recherche par le keyword
        eval(r)

      rescue Exception => e
        @@logger.an_event.fatal "set input search #{type} #{input} with #{keywords} : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_SET_INPUT_SEARCH, :values => {:browser => name, :type => type, :input => input, :keywords => keywords}, :error => e)

      else
        @@logger.an_event.debug "set input search #{type} #{input} with #{keywords}"

      end
    end
  end
end

