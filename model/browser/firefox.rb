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
    def initialize(visitor_dir, browser_details)
      @@logger.an_event.debug "name #{browser_details[:name]}"
      @@logger.an_event.debug "version #{browser_details[:version]}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser name"}) if browser_details[:name].nil? or browser_details[:name] == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser version"}) if browser_details[:version].nil? or browser_details[:version] == ""

        super(visitor_dir,
              browser_details,
              "#{browser_details[:name]}_#{browser_details[:version]}_#{browser_details[:listening_ip_proxy]}_#{browser_details[:listening_port_proxy]}",
              DATA_URI,
              NO_ACCEPT_POPUP)


      rescue Exception => e
        @@logger.an_event.error "#{name} initialize : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "#{name} initialize"
      ensure

      end
    end

    def focus_popup
      popup = nil
      wait(60, true, 2) {
        @driver.get_windows.each { |win|
          @@logger.an_event.debug win.inspect
          if win["windowName"] == WINDOW_NAME
            popup = @driver.popup(win["sahiWinId"])
            @@logger.an_event.debug "window found <#{!popup.nil?}>"
            break
          end
        }

        raise "window not found" if popup.nil?
        !popup.nil?
      }
      @@logger.an_event.debug "replace driver by popup driver"
      @@logger.an_event.debug popup.inspect
      popup
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
        raise Errors::Error.new(BROWSER_NOT_OPEN, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "browser #{name} open"

      ensure

      end

    end


    def running?
      running_by_pid?
    end
  end
end
