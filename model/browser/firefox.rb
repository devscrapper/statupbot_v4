
require_relative '../../lib/error'
module Browsers
  class Firefox < Browser
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
    def initialize(profiles_dir, browser_details)
      @@logger.an_event.debug "name #{browser_details[:name]}"
      @@logger.an_event.debug "version #{browser_details[:version]}"

      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser name"}) if browser_details[:name].nil? or browser_details[:name] == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser version"}) if browser_details[:version].nil? or browser_details[:version] == ""

        super(browser_details,
              "#{browser_details[:name]}_#{browser_details[:version]}_#{browser_details[:listening_ip_proxy]}_#{browser_details[:listening_port_proxy]}",
              DATA_URI)


        customize_properties (profiles_dir)
      rescue Exception => e
        @@logger.an_event.error "#{name} initialize : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "#{name} initialize"
      ensure

      end
    end

    def customize_properties(profiles_dir)
      @@logger.an_event.debug "profiles_dir #{profiles_dir}"

      begin

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "profiles_dir"}) if profiles_dir.nil? or profiles_dir == ""

        # userdata\proxy\config\ff_profile_template\prefs.js :
        # le port d'ecoute du proxy pour firefox
        prefs_js = File.join(profiles_dir + ["sahi_#{@listening_ip_proxy}_#{@listening_port_proxy}", "prefs.js"])
        FileUtils.cp_r(File.join([File.dirname(__FILE__), "..", "..", "lib","mim", "prefs.js."]), prefs_js)

        file_custom = File.read(prefs_js)
        file_custom.gsub!(/listening_ip_proxy/, @listening_ip_proxy.to_s)
        file_custom.gsub!(/listening_port_proxy/, @listening_port_proxy.to_s)
        File.write(prefs_js, file_custom)

      rescue Exception => e
        @@logger.an_event.error "#{name} customize config file proxy sahi : #{e.message}"
        raise Error.new(BROWSER_NOT_CUSTOM_FILE, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "#{name} customize config file proxy sahi"

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
    #scrollbars=yes|no|1|0 	Whether or not to display scroll bars. IE, Firefox & Opera only
    #status=yes|no|1|0 	Whether or not to add a status bar
    #titlebar=yes|no|1|0 	Whether or not to display the title bar. Ignored unless the calling application is an HTML Application or a trusted dialog box
    #toolbar=yes|no|1|0 	Whether or not to display the browser toolbar. IE and Firefox only
    #top=pixels 	The top position of the window. Negative values not allowed
    #width=pixels 	The width of the window. Min. value is 100
    #@driver.open_start_page("width=#{@width},height=#{@height},fullscreen=no,left=0,menubar=yes,scrollbars=yes,status=yes,titlebar=yes,toolbar=yes,top=0")

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

        window_parameters = "fullscreen=no,left=0,menubar=yes,scrollbars=yes,status=yes,titlebar=yes,toolbar=yes"
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
  end
end
