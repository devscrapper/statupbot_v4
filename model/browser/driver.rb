require_relative '../../lib/os'
require_relative '../../lib/error'
require 'win32/window'
require 'rexml/document'
require 'sahi'


#----------------------------------------------------------------------------------------------------------------
# enrichissment, surcharge pour personnaliser ou corriger le gem Sahi standard
#----------------------------------------------------------------------------------------------------------------

module Sahi
  class Browser
    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors
    include REXML
    #----------------------------------------------------------------------------------------------------------------
    # message exception
    #----------------------------------------------------------------------------------------------------------------
    ARGUMENT_UNDEFINE = 200 # à remonter en code retour de statupbot
    DRIVER_NOT_CREATE = 201 # à remonter en code retour de statupbot
    SAHI_PROXY_NOT_FOUND = 202 # à remonter en code retour de statupbot
    BROWSER_TYPE_NOT_EXIST = 203 # à remonter en code retour de statupbot
    OPEN_DRIVER_FAILED = 204 # à remonter en code retour de statupbot
    CLOSE_DRIVER_TIMEOUT = 205 # à remonter en code retour de statupbot
    CLOSE_DRIVER_FAILED = 206 # à remonter en code retour de statupbot
    CATCH_PROPERTIES_PAGE_FAILED = 207 # à remonter en code retour de statupbot
    DRIVER_SEARCH_FAILED = 208 # à remonter en code retour de statupbot
    BROWSER_TYPE_FILE_NOT_FOUND = 209 # à remonter en code retour de statupbot
    DRIVER_NOT_ACCESS_URL = 210
    TEXTBOX_SEARCH_NOT_FOUND = 211
    SUBMIT_SEARCH_NOT_FOUND = 212
    DRIVER_NOT_CATCH_LINKS = 213

    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # constant
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # variable de class
    #----------------------------------------------------------------------------------------------------------------
    @@logger = nil
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------

    attr_reader :browser_type,
                :browser_pid,
                :browser_process_name,
                :browser_window_handle

    #----------------------------------------------------------------------------------------------------------------
    # class methods
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # instance methods
    #----------------------------------------------------------------------------------------------------------------

    def back
      #fetch("_sahi.go_back()")
      fetch("window.history.go(-1)")

    end

    def body
      fetch("window.document.body.innerHTML")
    end


    def check_proxy_local
      begin
        response("http://localhost:9999/_s_/spr/blank.htm")
      rescue
        raise "Sahi proxy local is not available."
      end
    end

    def close_popups
      windows = get_windows
      windows.each { |win|
        if win["wasOpened"] == "1"
          popup(win["sahiWinId"]).close
        end
      }
    end

    def collect(els, attr=nil)
      if (attr == nil)
        return els.collect_similar()
      else
        return fetch("_sahi._collect(#{Utils.quoted(attr)}, #{Utils.quoted(els.to_type())}, #{els.to_identifiers()})").split(",___sahi___")
      end
    end

    def current_url
      fetch("window.location.href")
    end

    def display_start_page (url, window_parameters)

      fetch("window.open(\"#{url}\", \"_self\", \"#{window_parameters}\")")

    end

    def domain(name)
      win = Browser.new(@browser_type, @proxy_port)

      win.proxy_host = @proxy_host
      win.proxy_port = @proxy_port
      win.sahisid = @sahisid
      win.print_steps = @print_steps
      win.popup_name = @popup_name
      win.domain_name = name
      win
    end

    def domain_exist?
      windows = get_windows
      exist = false
      windows.each { |win| exist = exist || (win["domain"] == @domain_name) }
      exist
    end


    #
    def exec_command_local(cmd, qs={})
      res = response("http://localhost:9999/_s_/dyn/Driver_" + cmd, {"sahisid" => @sahisid}.update(qs))
      return res.force_encoding("UTF-8")
    end


    # evaluates a javascript expression on the browser and fetches its value
    def fetch(expression)
      key = "___lastValue___" + Time.now.getutc.to_s;
      #remplacement de cette ligne
      # execute_step("_sahi.setServerVarPlain('"+key+"', " + expression + ")")
      # par celle ci depuis la version 6.0.1 de SAHI
      execute_step("_sahi.setServerVarForFetchPlain('"+key+"', " + expression + ")")
      return check_nil(exec_command("getVariable", {"key" => key}))
    end

    def focus_popup
      windows = get_windows
      popup = nil
      windows.each { |win|
        if win["wasOpened"] == "1"
          popup = popup(win["sahiWinId"])
          break
        end
      }
      popup
    end


    #-----------------------------------------------------------------------------------------------------------------
    # initialize
    #-----------------------------------------------------------------------------------------------------------------
    # input :
    #    id_browser_type : type du browser qu'il faut créer, présent dans les fichiers  lib/sahi.in.co/config/browser_type/win32/64, mac, linux.xml
    #    listening_port_sahi : le port d'écoute du proxy Sahi
    # output : un objet browser
    # exception :
    # StandardError :
    #     - id_browser n'est pas défini ou absent
    #     - listening_port_sahi n'est pas défini ou absent
    #     - id_browser est absent des fichiers lib/sahi.in.co/config/browser_type/win32/64, mac, linux.xml
    #-----------------------------------------------------------------------------------------------------------------
    #
    #-----------------------------------------------------------------------------------------------------------------
    def initialize(browser_type, browser_process_name, listening_ip_sahi, listening_port_sahi)
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
      @@logger.an_event.debug "browser_type #{browser_type}"
      @@logger.an_event.debug "process_name #{browser_process_name}"
      @@logger.an_event.debug "listening_ip_sahi #{listening_ip_sahi}"
      @@logger.an_event.debug "listening_port_sahi #{listening_port_sahi}"

      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => browser_type}) if browser_type.nil? or browser_type == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => browser_process_name}) if browser_process_name.nil? or browser_process_name == ""
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => listening_port_sahi}) if listening_port_sahi.nil? or listening_port_sahi.nil? == ""

        # les requetes (check_proxy_local, launchPreconfiguredBrowser, quit) vers le proxy local sont exécutées avec localhst:9999
        @proxy_host = listening_ip_sahi # est utilisé pour le proxy remote
        @proxy_port = listening_port_sahi # est utilisé pour le proxy remote
        @browser_process_name = browser_process_name

        @popup_name = nil
        @domain_name = nil
        @sahisid = nil
        @print_steps = false
        @browser_pid = nil
        @browser_type = browser_type.gsub(" ", "_")

      rescue Exception => e
        @@logger.an_event.fatal "driver #{@browser_type} create : #{e.message}"
        raise Error.new(DRIVER_NOT_CREATE, :error => e)

      else
        @@logger.an_event.debug "driver #{@browser_type} create"
      ensure

      end

    end


    def kill
      unless @browser_pid.nil?
        count_try = 3

        @@logger.an_event.debug "going to kill pid #{@browser_pid} browser #{@browser_type}"
        begin
          #TODO remplacer taskkill par kill pour linux
          res = IO.popen("taskkill /PID #{@browser_pid} /T /F").read

          @@logger.an_event.debug "taskkill for #{@browser_type} pid #{@browser_pid} : #{res}"

        rescue Exception => e
          count_try -= 1

          if count_try > 0
            @@logger.an_event.debug "try #{count_try},kill browser type #{@browser_type} pid #{@browser_pid}: #{e.message}"
            sleep (1)
            retry

          else
            @@logger.an_event.error "failed to kill pid #{@browser_pid} browser #{@browser_type} : #{e.message}"
            raise Error.new(CLOSE_DRIVER_FAILED, :error => e)

          end
        else
          @@logger.an_event.debug "kill pid #{@browser_pid} browser #{@browser_type}"

        ensure

        end

      else
        @@logger.an_event.error "failed to kill browser #{@browser_type} because no pid"
        raise Error.new(CLOSE_DRIVER_FAILED, :error => e)

      end
    end

    def links

      fetch("_sahi.links()")

    end

    def new_popup_is_open? (url)
      windows = get_windows
      exist = false
      windows.each { |win| exist = exist || (win["wasOpened"] == "1" && win["windowURL"] != url) }
      exist
    end

    #-----------------------------------------------------------------------------------------------------------------
    # open
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # exception :
    # StandardError :
    #     - une erreur est survenue lors de demande de lancement du browser auprès de Sahi.
    # StandardError :
    #     - browser_type n'est pas défini ou absent
    #-----------------------------------------------------------------------------------------------------------------
    #
    #-----------------------------------------------------------------------------------------------------------------
    def open
      try_count = 3
      begin

        wait(60) {
          check_proxy_local
        }

      rescue Exception => e
        try_count -= 1
        @@logger.an_event.debug "check proxy local launcher browser, try #{try_count} : #{e.message}"
        sleep(3)
        retry if try_count > 0

        @@logger.an_event.error "check proxy local launcher browser : #{e.message}"
        raise Error.new(SAHI_PROXY_NOT_FOUND, :values => {:where => "local launcher"}, :error => e)

      else
        @@logger.an_event.debug "check proxy local launcher browser"

      end

      try_count = 3
      begin
        wait(60) {
          check_proxy
        }

      rescue Exception => e
        try_count -= 1
        @@logger.an_event.debug "check proxy remote #{@proxy_host}:#{@proxy_port}, try #{try_count} : #{e.message}"
        sleep(3)
        retry if try_count > 0

        @@logger.an_event.error "check proxy remote #{@proxy_host}:#{@proxy_port}: #{e.message}"
        raise Error.new(SAHI_PROXY_NOT_FOUND, :values => {:where => "remote"}, :error => e)

      else
        @@logger.an_event.debug "check proxy remote #{@proxy_host}:#{@proxy_port}"

      end


      begin
        @sahisid = Time.now.to_f
        start_url = "http://sahi.example.com/_s_/dyn/Driver_initialized"
        param = {"browserType" => @browser_type, "startUrl" => start_url}

        @@logger.an_event.debug "param #{param}"

        exec_command_local("launchPreconfiguredBrowser", param)
          #exec_command("launchPreconfiguredBrowser", param)

      rescue Exception => e
        @@logger.an_event.error "launchPreconfiguredBrowser : #{e.message}"
        raise Error.new(OPEN_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "launchPreconfiguredBrowser"

      end

              #modifie le titre de la fenetre pour rechercher le pid du navigateur
        execute_step("window.document.title =" + Utils.quoted(@sahisid.to_s))
        @@logger.an_event.debug "set windows title browser #{@browser_type} with #{@sahisid.to_s}"
        get_pid_browser
        get_handle_window_browser

=begin
      count_try = 3
      begin
        wait(60) {
          is_ready?
        }

        raise "browser type not ready" unless is_ready?

      rescue Exception => e
        @@logger.an_event.warn "try #{count_try}, #{e.message}"
        count_try-= 1
        retry if count_try >= 0
        @@logger.an_event.error "driver ready : #{e.message}"
        raise Error.new(OPEN_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "driver ready"
        #modifie le titre de la fenetre pour rechercher le pid du navigateur
        execute_step("window.document.title =" + Utils.quoted(@sahisid.to_s))
        @@logger.an_event.debug "set windows title browser #{@browser_type} with #{@sahisid.to_s}"
        get_pid_browser
        get_handle_window_browser
      ensure

      end
=end
    end

    # represents a popup window. The name is either the window name or its title.
    def popup(name)
      win = Browser.new(@browser_type, @proxy_port)

      win.proxy_host = @proxy_host
      win.proxy_port = @proxy_port
      win.sahisid = @sahisid
      win.print_steps = @print_steps
      win.popup_name = name
      win.domain_name = @domain_name
      win
    end

    def quit
      begin
        exec_command_local("kill") # kill piloté par SAHI proxy

      rescue Exception => e
        raise Error.new(CLOSE_DRIVER_TIMEOUT, :error => e)

      else

      end
    end


    def reload
      fetch("location.reload(true)")
    end

    def resize (width, height)
      #TODO update for linux
      Window.from_handle(@browser_window_handle).resize(width,
                                                        height)
      Window.from_handle(@browser_window_handle).move(0,
                                                      0)
    end

    def running?

      require 'csv'
      #TODO remplacer tasklist par ps pour linux
      res = IO.popen('tasklist /V /FI "PID eq ' + @browser_pid.to_s + '" /FO CSV /NH').read

      @@logger.an_event.debug "tasklist for #{@browser_pid.to_s} : #{res}"

      CSV.parse(res) do |row|
        if row[1].nil?
          # res == Informationÿ: aucune tƒche en service ne correspond aux critŠres sp‚cifi‚s.
          # donc le pid n'existe plus => le browser nest plus running
          return false
        else
          return true if row[1].include?(@browser_pid.to_s)

        end
      end
      #ne doit jamais arriver ici
      false


    end

    def take_screenshot(to_absolute_path)
      #TODO update for linux
      begin
        Win32::Screenshot::Take.of(:desktop).write!(to_absolute_path)


#        Win32::Screenshot::Take.of(:window,
#                                  hwnd: @browser_window_handle).write!(to_absolute_path)
      rescue Exception => e
        Win32::Screenshot::Take.of(:desktop).write!(to_absolute_path)
      else
      end
    end


    def take_area_screenshot(to_absolute_path, coord)
      #TODO update for linux
      begin
        Win32::Screenshot::Take.of(:desktop, area: coord).write!(to_absolute_path)

          #      Win32::Screenshot::Take.of(:window,
          #                                hwnd: @browser_window_handle, area: coord).write!(to_absolute_path)
      rescue Exception => e
        Win32::Screenshot::Take.of(:desktop, area: coord).write!(to_absolute_path)
      else
      end
    end

    def title
      fetch("window.document.title")
    end


    private


    def get_pid_browser
      # retourn le pid du browser ; au cas où Sahi n'arrive pas à le tuer.
      count_try = 3
      begin
        require 'csv'
        #TODO remplacer tasklist par ps pour linux
        res = IO.popen('tasklist /V /FI "IMAGENAME eq ' + @browser_process_name + '" /FO CSV /NH').read

        @@logger.an_event.debug "tasklist for #{@browser_process_name} : #{res}"

        CSV.parse(res) do |row|
          if row[8].include?(@sahisid.to_s)
            @browser_pid = row[1].to_i
            break

          end
        end

        raise "sahiid not found in title browser in tasklist " if @browser_pid.nil?

      rescue Exception => e
        if count_try > 0
          @@logger.an_event.debug "try #{count_try}, browser type #{@browser_type} has no pid : #{e.message}"
          sleep (1)
          retry
        else
          raise "browser type #{@browser_type} has no pid : #{e.message}"

        end

      else
        @@logger.an_event.debug "browser type #{@browser_type} has pid #{@browser_pid}"

      end
    end

    def get_handle_window_browser
      begin
        windows_lst = Window.find(:title => /#{@sahisid.to_s}/, :pid => @browser_pid)
        @@logger.an_event.debug "list windows #{windows_lst}"

        window = windows_lst.first
        @@logger.an_event.debug "choose first window #{window}"

        @browser_window_handle = window.handle

      rescue Exception => e
        @@logger.an_event.error "browser windows handle #{e.message}"

      else
        @@logger.an_event.debug "browser windows handle #{@browser_window_handle}"

      end
      @browser_window_handle
    end
  end # Browser


  #-------------------------------------------------------------------------------------------------------------
  # ElementStub
  #-------------------------------------------------------------------------------------------------------------


  class ElementStub
    # returns count of elements similar to this element
    def count_similar
      # return Integer(@browser.fetch("_sahi._count(\"_#{@type}\", #{concat_identifiers(@identifiers).join(", ")})"))
      @browser.fetch("_sahi._count(\"_#{@type}\", #{concat_identifiers(@identifiers).join(", ")})").to_i
    end


    def setAttribute(attr=nil, value="")
      if attr
        if attr.include? "."
          return @browser.fetch("#{self.to_s()}.#{attr}")
        else
          return @browser.fetch("_sahi.setAttribute(#{self.to_s()}, #{Utils.quoted(attr)}, #{Utils.quoted(value)})")
        end
      else
        return @browser.fetch("#{self.to_s()}")
      end
    end
  end


end
