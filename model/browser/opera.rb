# encoding: utf-8
require_relative '../page/page'

module Browsers
  class Opera < Browser
    include Pages
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
    def initialize(tools_dir, browser_details)
      @@logger.an_event.debug "name #{browser_details[:name]}"
      @@logger.an_event.debug "version #{browser_details[:version]}"
      @@logger.an_event.debug "proxy system #{browser_details[:proxy_system]}"
      @@logger.an_event.debug "tools_dir #{tools_dir}"

      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser name"}) if browser_details[:name].nil? or browser_details[:name] == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser version"}) if browser_details[:version].nil? or browser_details[:version] == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "tools_dir"}) if tools_dir.nil? or tools_dir == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "proxy_system"}) if browser_details[:proxy_system].nil? or browser_details[:proxy_system] == ""


        super(browser_details,
              "#{browser_details[:name]}_#{browser_details[:version]}" + (browser_details[:proxy_system] ? "" : "_#{@listening_port_proxy}"),
              DATA_URI)

        customize_properties (tools_dir)
      rescue Exception => e
        @@logger.an_event.error "opera #{@version} initialize : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "opera #{@version} initialize"

      ensure

      end
    end

    def customize_properties(tools_dir)
      @@logger.an_event.debug "tools_dir #{tools_dir}"

      begin

        # \tools\proxy.properties :
        # le port d'ecoute du proxy pour internet explorer
        proxy_properties = File.join(tools_dir , 'proxy.properties')
        FileUtils.cp_r(File.join([File.dirname(__FILE__), "..", "..", "lib","mim", "proxy.properties"]), proxy_properties)

        file_custom = File.read(proxy_properties)
        file_custom.gsub!(/listening_ip_proxy/, @listening_ip_proxy.to_s)
        file_custom.gsub!(/listening_port_proxy/, @listening_port_proxy.to_s)
        File.write(proxy_properties, file_custom)

      rescue Exception => e
        @@logger.an_event.error "opera #{@version} customize config file proxy sahi : #{e.message}"
        raise Error.new(BROWSER_NOT_CUSTOM_FILE, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "opera #{@version} customize config file proxy sahi"

      ensure

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # display_start_page
    #----------------------------------------------------------------------------------------------------------------
    # ouvre un nouvelle fenetre du navigateur adaptée aux propriété du naviagateur et celle de la visit
    # affiche la root page du site https pour initialisé le référer à non défini
    #----------------------------------------------------------------------------------------------------------------
    # input : url (String)
    # output : RAS
    # exception : RAS
    #----------------------------------------------------------------------------------------------------------------
    def display_start_page(start_url, visitor_id)
      #@driver.navigate_to "http://jenn.kyrnin.com/about/showreferer.html"
      #fullscreen=yes|no|1|0 	Whether or not to display the browser in full-screen mode. Default is no. A window in full-screen mode must also be in theater mode. IE only
      #height=pixels 	The height of the window. Min. value is 100
      #left=pixels 	The left position of the window. Negative values not allowed
      #location=yes|no|1|0 	Whether or not to display the address field. Opera only
      #menubar=yes|no|1|0 	Whether or not to display the menu bar
      #scrollbars=yes|no|1|0 	Whether or not to display scroll bars. IE, Firefox & Opera only
      #status=yes|no|1|0 	Whether or not to add a status bar
      #titlebar=yes|no|1|0 	Whether or not to display the title bar. Ignored unless the calling application is an HTML Application or a trusted dialog box
      #top=pixels 	The top position of the window. Negative values not allowed
      #width=pixels 	The width of the window. Min. value is 100
      @@logger.an_event.debug "start_url : #{start_url}"
      @@logger.an_event.debug "visitor_id : #{visitor_id}"

      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "start_url"}) if start_url.nil? or start_url ==""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_id"}) if visitor_id.nil? or visitor_id == ""

        window_parameters = "fullscreen=0,left=0,location=1,menubar=1,scrollbars=1,status=1,titlebar=1"
        @@logger.an_event.debug "windows parameters : #{window_parameters}"

        encode_start_url = Addressable::URI.encode_component(start_url, Addressable::URI::CharacterClasses::UNRESERVED)

        start_page_visit_url = "http://#{$start_page_server_ip}:#{$start_page_server_port}/start_link?method=#{@method_start_page}&url=#{encode_start_url}&visitor_id=#{visitor_id}"
        @@logger.an_event.debug "start_page_visit_url : #{start_page_visit_url}"

        super(start_page_visit_url, window_parameters)

      rescue Exception => e
        @@logger.an_event.error "#{name} display start page #{start_url} : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "#{name} display start page #{start_url}"

      ensure

      end

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

