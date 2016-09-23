require_relative '../../lib/os'
require_relative '../../lib/error'

require 'win32/window'
require 'rexml/document'
require 'sahi'
require 'mini_magick'

#----------------------------------------------------------------------------------------------------------------
#
# Enrichissment, surcharge pour personnaliser ou corriger le gem Sahi standard
#
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
    ARGUMENT_UNDEFINE = 200
    DRIVER_NOT_CREATE = 201
    SAHI_PROXY_NOT_FOUND = 202
    BROWSER_TYPE_NOT_EXIST = 203
    OPEN_DRIVER_FAILED = 204
    CLOSE_DRIVER_TIMEOUT = 205
    CLOSE_DRIVER_FAILED = 206
    CATCH_PROPERTIES_PAGE_FAILED = 207
    DRIVER_SEARCH_FAILED = 208
    BROWSER_TYPE_FILE_NOT_FOUND = 209
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
    @@sem_screenshot = nil # protège la prise d'image pour assurer que se qui est photographie est bien celui du navigateur
    # quand plusieurs exécution son réalisées en //
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
      fetch("window.history.go(-1)")

    end

    def body
      body = nil
      wait(60) {
        body = fetch("window.document.body.innerHTML")
        !body.nil? and !body.empty?
      }
      raise "window.document.body.innerHTML return none body page" if body == "" or body.nil?
      body

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
      url = nil
      wait(60) {
        url = fetch("window.location.href")
        !url.nil? and !url.empty?
      }
      raise "window.location.href return none url" if url.empty? or url.nil?
      url
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


    def get_body_height

      fetch("Math.max(window.innerHeight || 0, \
            document.documentElement.clientHeight || 0,
      document.body.clientHeight || 0)").to_i
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

        @@sem_screenshot = Mutex.new
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
      links = nil
      wait(60) {
        links = fetch("_sahi.links()")
        !links.nil?
      }
      raise "_sahi.links() return none link of page" if links == "" or links.nil?
      links
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

      begin
        wait(60) {
          check_proxy
        }

      rescue Exception => e
        @@logger.an_event.error "driver open : #{e.message}"
        raise Error.new(SAHI_PROXY_NOT_FOUND, :values => {:where => "remote"}, :error => e)

      else
        @@logger.an_event.debug "check proxy #{@proxy_host}:#{@proxy_port}"

      end


      begin
        @sahisid = Time.now.to_f
        start_url = "http://sahi.example.com/_s_/dyn/Driver_initialized"
        param = {"browserType" => @browser_type, "startUrl" => start_url}

        @@logger.an_event.debug "param #{param}"

        exec_command("launchPreconfiguredBrowser", param)

      rescue Exception => e
        @@logger.an_event.error "driver open, launchPreconfiguredBrowser : #{e.message}"
        raise Error.new(OPEN_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "launchPreconfiguredBrowser"

      end


      begin
        wait(60) {
          is_ready?
        }

        raise "browser type not ready" unless is_ready?

      rescue Exception => e
        @@logger.an_event.error "driver open : #{e.message}"
        raise Error.new(OPEN_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "driver ready"
        #modifie le titre de la fenetre pour rechercher le pid du navigateur
        execute_step("window.document.title =" + Utils.quoted(@sahisid.to_s))
        @@logger.an_event.debug "set windows title browser #{@browser_type} with #{@sahisid.to_s}"
        get_pid_browser
        get_handle_window_browser
        RAutomation::Window.new(:hwnd => @browser_window_handle).minimize
      end
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
        exec_command("kill") # kill piloté par SAHI proxy

      rescue Exception => e
        raise Error.new(CLOSE_DRIVER_TIMEOUT, :error => e)

      else

      end
    end


    def reload
      fetch("location.reload(true)")
    end

    def resize (width, height)
      action = "resize"
      title = fetch("window.top.document.title")
      title = prepare_window_action(title)
      exec_command("windowAction",
                   {"action" => action,
                    "title" => title,
                    "width" => width,
                    "height" => height})

      # si screenshot est pris avec sahi et peut prendre un element graphique et pas une page ou destop alors on peut
      # eviter de deplacer à l'origine du repere pour fiabiliser la prise de photo du captcha.
      #TODO move to linux
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


    def take_screenshot(screenshot_flow, brw_height)
      @@sem_screenshot.synchronize {

        begin
          #-------------------------------------------------------------------------------------------------------------
          # affiche le browser en premier plan
          #-------------------------------------------------------------------------------------------------------------
          #TODO update for linux
          window = RAutomation::Window.new(:hwnd => @browser_window_handle)
          window.restore if window.minimized?
          window.activate
          window.wait_until_exists
          window.wait_until_present
          @@logger.an_event.debug "restore de la fenetre du browser"

          #-------------------------------------------------------------------------------------------------------------
          # prise du screenshot
          #-------------------------------------------------------------------------------------------------------------
          # recuperation de la hauteur du body de la page courante
          body_height = get_body_height
          @@logger.an_event.debug "body height #{body_height}"

          # calcul du nombre de page en fonction de la hauteur du browser
          page_count = body_height.divmod(brw_height)[1] == 0 ?
              body_height.divmod(brw_height)[0] :
              body_height.divmod(brw_height)[0] + 1

          if page_count == 1
            # une page dans le screenshot
            screenshot(screenshot_flow)

          else
            # plusieurs pages dans le screenshot
            screenshots(screenshot_flow, page_count, brw_height)

          end

        rescue Exception => e
          @@logger.an_event.error "take screenshot #{screenshot_flow.basename} : #{e.message}"

        else
          @@logger.an_event.debug "take screenshot #{screenshot_flow.basename}"

        ensure
          #-------------------------------------------------------------------------------------------------------------
          # cache le browser
          #-------------------------------------------------------------------------------------------------------------
          window.minimize
          @@logger.an_event.debug "minimize de la fenetre du browser"

        end
      }
    end


    def take_area_screenshot(screenshot_flow, coord)
      @@sem_screenshot.synchronize {
        begin
          #-------------------------------------------------------------------------------------------------------------
          # affiche le browser en premier plan
          #-------------------------------------------------------------------------------------------------------------
          #TODO update for linux
          window = RAutomation::Window.new(:hwnd => @browser_window_handle)
          window.restore if window.minimized?
          window.activate
          window.wait_until_exists
          window.wait_until_present
          @@logger.an_event.debug "restore de la fenetre du browser"

          screenshot(screenshot_flow, coord)

        rescue Exception => e
          @@logger.an_event.error "take screenshot area #{screenshot_flow.basename} : #{e.message}"

        else
          @@logger.an_event.debug "take screenshot area #{screenshot_flow.basename}"

        ensure
          #-------------------------------------------------------------------------------------------------------------
          # cache le browser
          #-------------------------------------------------------------------------------------------------------------
          window.minimize
          @@logger.an_event.debug "minimize de la fenetre du browser"

        end
      }
    end

    def title
      title = nil
      wait(60) {
        title = fetch("_sahi._title()")
        !title.nil? and !title.empty?
      }
      raise "window.document.title return none title page" if title == "" or title.nil?
      title

    end

    def window_action(action)
      @@logger.an_event.debug "action #{action}"
      title = fetch("window.top.document.title")
      @@logger.an_event.debug "title #{title}"
      title = prepare_window_action(title)
      @@logger.an_event.debug "title #{title}"

      exec_command("windowAction", {"action" => action, "title" => title})
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
        windows_lst = Window.find(:title => /#{@sahisid.to_s}/)

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

    # est capable de screener :
    # soit le desktop
    # soit la fenetre
    # soit une zone de la page
    # en premiere intention on screen la fenetre.
    # si win32 n'arrive pas à trouevr la fenetre alors on screen le desktop
    def screenshot(screenshot_flow, coord=nil)
      begin
        #TODO update for linux
        # screen la fenetre
        if coord.nil?
          Win32::Screenshot::Take.of(:desktop).write!(screenshot_flow.absolute_path)
        else
          Win32::Screenshot::Take.of(:desktop,
                                     area: coord).write!(screenshot_flow.absolute_path)
        end
      rescue Exception => e
        #si le screen de la fenetre echoue, on screen le desktop
        @@logger.an_event.warn "prise du screenshot #{screenshot_flow.basename} : #{e.message}"
        #TODO update for linux
        if coord.nil?
          Win32::Screenshot::Take.of(:desktop).write!(screenshot_flow.absolute_path)

        else
          Win32::Screenshot::Take.of(:desktop,
                                     area: coord).write!(screenshot_flow.absolute_path)

        end
      end
    end

    # screen toutes les page d'un body dont la hauteur est supérieure à la hauteur du browser afin tout recuperer.
    def screenshots(screenshot_flow, page_count, page_height)
      # comme les objets sont passés par référence alors l'objet Flow screenshot_flow et que on modifie le volume
      # on travaille sur une duplication d'un objet pour ne pas trouver un Flow avec un volume different de nil ou empty/
      screenshot_tmp = screenshot_flow.dup

      a = fetch("Math.max(window.innerHeight")
            b = fetch("document.documentElement.clientHeight")
      c = fetch("document.body.clientHeight")

      @@logger.an_event.debug "page count #{page_count}"
      @@logger.an_event.debug "page height #{page_height}"
      #-------------------------------------------------------------------------------------------------------------
      # screen des pages du body html
      #-------------------------------------------------------------------------------------------------------------
      fetch("document.body.scrollTop=0")
      @@logger.an_event.debug "positionnement en haut de la fenetre"

      page_count.times { |page_index|

        screenshot_tmp.vol = page_index + 1
        @@logger.an_event.debug "page #{screenshot_tmp.vol} du screenshot #{screenshot_tmp.basename}"

        screenshot(screenshot_tmp)

        # attend que l'image ait été enregistrée pour ne pas en perdre
        wait(60) { screenshot_tmp.exist? }
        @@logger.an_event.debug "page #{screenshot_tmp.vol} du screenshot #{screenshot_tmp.basename} existe"

        #si pas derniere page alors on passe à la page suivante
        if screenshot_tmp.vol.to_i <= page_count
          scrolling = (page_height * (page_index + 1)) + 1
          fetch("document.body.scrollTop=#{scrolling}")
          @@logger.an_event.debug "scrolling #{scrolling}"
        end
      }

      #-------------------------------------------------------------------------------------------------------------
      # fusion  des screens dans un fichier image
      #-------------------------------------------------------------------------------------------------------------
      @@logger.an_event.debug "merge les #{page_count} screenshots"
      MiniMagick.cli = :imagemagick
      MiniMagick.cli_path = $image_magick_path
      MiniMagick.debug = true if $debugging

      MiniMagick::Tool::Montage.new do |builder|
        builder.background << '#000000'
        builder.geometry << "+1+1"
        page_count.times { |page_index|
          screenshot_tmp.vol = page_index + 1
          @@logger.an_event.debug "ajout du screenshot #{screenshot_tmp.basename}"
          builder << screenshot_tmp.absolute_path if screenshot_tmp.vol.to_i <= page_count
        }
        screenshot_tmp.vol = nil
        builder << screenshot_tmp.absolute_path
      end

      @@logger.an_event.debug "merge des screenshots #{screenshot_tmp.basename} over"

      #-------------------------------------------------------------------------------------------------------------
      # delete screenshots de page
      #-------------------------------------------------------------------------------------------------------------
      page_count.times { |page_index|
        screenshot_tmp.vol = page_index + 1
        screenshot_tmp.delete
        @@logger.an_event.debug "suppression du screenshot #{screenshot_tmp.basename}"
      }
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
