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
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------

    attr_reader :browser_type,
                :browser_process_name

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
      wait(60, false, 1) {
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
      wait(60, false, 1) {
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
      win = Browser.new(@browser_type, @browser_process_name, @proxy_host, @proxy_port)

      win.proxy_host = @proxy_host
      win.proxy_port = @proxy_port
      win.sahisid = @sahisid
      win.print_steps = @print_steps
      win.popup_name = @popup_name
      win.domain_name = name
      win.browser_type = @browser_type
      win.browser_process_name = @browser_process_name
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

      popup = nil
      if chrome?

      else
        get_windows.each { |win|
          if win["wasOpened"] == "1"
            popup = popup(win["sahiWinId"])
            break
          end
        }
      end
      popup
    end

    def history_size
      fetch("window.history.length")
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
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => browser_type}) if browser_type.nil? or browser_type == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => browser_process_name}) if browser_process_name.nil? or browser_process_name == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => listening_port_sahi}) if listening_port_sahi.nil? or listening_port_sahi.nil? == ""

        @@sem_screenshot = Mutex.new
        # les requetes (check_proxy_local, launchPreconfiguredBrowser, quit) vers le proxy local sont exécutées avec localhst:9999
        @proxy_host = listening_ip_sahi # est utilisé pour le proxy remote
        @proxy_port = listening_port_sahi # est utilisé pour le proxy remote
        @browser_process_name = browser_process_name

        @popup_name = nil
        @domain_name = nil
        @sahisid = nil
        @print_steps = false
        @browser_type = browser_type.gsub(" ", "_")

      rescue Exception => e
        @@logger.an_event.fatal "driver #{@browser_type} create : #{e.message}"
        raise Errors::Error.new(DRIVER_NOT_CREATE, :error => e)

      else
        @@logger.an_event.debug "driver #{@browser_type} create"
      ensure

      end

    end


    def links
      links = nil
      wait(60, false, 1) {
        links = fetch("_sahi.links()")
        !links.nil?
      }
      raise "_sahi.links() return none link of page" if links == "" or links.nil?
      links
    end

    def new_popup_is_open? (url=nil)

      exist = false
      if chrome?
       # exist = popup_name != get_windows[0]["sahiWinId"]
        exist = false
      else
        wait(10, false, 2) {
          if url.nil?
            get_windows.each { |win| exist = exist || (win["wasOpened"] == "1") }
          else
            get_windows.each { |win| exist = exist || (win["wasOpened"] == "1" and win["windowURL"] != url) }
          end
          exist
        }
      end
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
        wait(60, true) {
          check_proxy
          true
        }

      rescue Exception => e
        @@logger.an_event.error "driver open : #{e.message}"
        raise Errors::Error.new(SAHI_PROXY_NOT_FOUND, :values => {:where => "remote"}, :error => e)

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
        raise Errors::Error.new(OPEN_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "launchPreconfiguredBrowser"

      end

      begin
        wait(5 * 60, true, 2) {
          # attend 5mn que le navigateur soit pret pour eviter des faux positif qd le navigateur est
          #long a démarré qd la machine est surchargée
          raise "browser type not ready" unless is_ready?
          true
        }

      rescue Exception => e
        @@logger.an_event.error "driver open : #{e.message}"
        raise Errors::Error.new(OPEN_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "driver ready"

      end
    end

    # represents a popup window. The name is either the window name or its title.
    def popup(name)
      win = Browser.new(@browser_type, @browser_process_name, @proxy_host, @proxy_port)

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
        raise Errors::Error.new(CLOSE_DRIVER_TIMEOUT, :error => e)

      end
    end

    def referrer
      fetch("document.referrer")
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


    end

    def take_screenshot_body_by_canvas(screenshot_flow)
      count = 3

      begin
        #----------------------------------------------------------------------------------------------------------------
        # prise du screenshot  (execution asynchrone par html2canvas avec Promise)
        #----------------------------------------------------------------------------------------------------------------
        @@logger.an_event.debug "#{count} => going to take screenshot body by canvas"
        fetch("_sahi.screenshot_body()")

        #----------------------------------------------------------------------------------------------------------------
        # donc attend que le screenshot soit fini
        #----------------------------------------------------------------------------------------------------------------
        @@logger.an_event.debug "waiting screenshot ..."
        screenshot_base64 = ""

        wait(60, false, 2) {
          # on va chercher le resultat dans le local storage du bronwser
          screenshot_base64 = fetch("localStorage.screenshot_base64")

          @@logger.an_event.debug "screenshot_base64 <#{screenshot_base64[0..32]}>"
          @@logger.an_event.debug "screenshot_base64 is empty? <#{screenshot_base64.empty?}>"
          @@logger.an_event.debug "screenshot_base64 is nil? <#{screenshot_base64.nil?}>"

          !screenshot_base64.include?("undefined") and !screenshot_base64.empty? and !screenshot_base64.nil?
        }

        raise "screenshot_base64 : #{screenshot_base64}" if screenshot_base64.include?("undefined") or screenshot_base64.empty? or screenshot_base64.nil?

        # suppressin de la variable screenshot_base64 dans le local storuage du browser
        fetch("localStorage.removeItem(\"screenshot_base64\")")

        # sauvegarde du screenshot dans le fichier
        File.open(screenshot_flow.absolute_path, 'wb') do |f|
          f.write(Base64.decode64(screenshot_base64))
        end

      rescue Exception => e
        @@logger.an_event.warn "#{count} => take screenshot body by canvas #{screenshot_flow.basename} : #{e.message}"
        count -= 1
        retry if count > 0
        @@logger.an_event.error "take screenshot body by canvas #{screenshot_flow.basename} : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "take screenshot body by canvas #{screenshot_flow.basename}"
      end
    end

    def take_screenshot_element_by_id_by_canvas(screenshot_flow, id_captcha)
      count = 3

      begin
        #----------------------------------------------------------------------------------------------------------------
        # prise du screenshot  (execution asynchrone par html2canvas avec Promise)
        #----------------------------------------------------------------------------------------------------------------
        @@logger.an_event.debug "#{count} => going to take screenshot captcha by canvas"
        fetch("_sahi.screenshot_element_by_css(\"#{id_captcha}\")")

        #----------------------------------------------------------------------------------------------------------------
        # donc attend que le screenshot soit fini
        #----------------------------------------------------------------------------------------------------------------
        @@logger.an_event.debug "waiting screenshot ..."
        screenshot_base64 = ""

        wait(60, false, 2) {
          screenshot_base64 = fetch("localStorage.screenshot_base64")

          @@logger.an_event.warn "screenshot_base64 <#{screenshot_base64[0..32]}>"
          @@logger.an_event.debug "screenshot_base64 is empty? <#{screenshot_base64.empty?}>"
          @@logger.an_event.debug "screenshot_base64 is nil? <#{screenshot_base64.nil?}>"

          !screenshot_base64.include?("undefined") and !screenshot_base64.empty? and !screenshot_base64.nil?
        }

        raise "screenshot_base64 : #{screenshot_base64}" if screenshot_base64.include?("undefined") or screenshot_base64.empty? or screenshot_base64.nil?

        fetch("localStorage.removeItem(\"screenshot_base64\")")

        # sauvegarde du screenshot dans le fichier
        File.open(screenshot_flow.absolute_path, 'wb') do |f|
          f.write(Base64.decode64(screenshot_base64))
        end
      rescue Exception => e
        @@logger.an_event.warn "#{count} => take screenshot element by id by canvas #{screenshot_flow.basename} : #{e.message}"
        count -= 1
        retry if count > 0
        @@logger.an_event.error "take screenshot element by id #{id_captcha} by canvas #{screenshot_flow.basename} : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "take screenshot element by id #{id_captcha} by canvas #{screenshot_flow.basename}"
      end
    end

    def take_screenshot(screenshot_flow, brw_height)
      begin
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

      end

    end


    def take_screenshot_area(screenshot_flow, coord)

      begin


        screenshot(screenshot_flow, coord)

      rescue Exception => e
        @@logger.an_event.error "take screenshot area #{screenshot_flow.basename} : #{e.message}"

      else
        @@logger.an_event.debug "take screenshot area #{screenshot_flow.basename}"

      ensure


      end

    end

    def set_title(title)
      execute_step("window.document.title =" + Utils.quoted(title.to_s))
    end

    def title
      title = nil
      wait(30, false, 1) {
        title = fetch("_sahi._title()")
        !title.nil? and !title.empty?
      }
      raise "window.document.title return none title page" if title == "" or title.nil?
      title

    end

    def to_s

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
    def get_body_height
      window_innerHeight = fetch("window.innerHeight").to_i || 0
      @@logger.an_event.debug "window_innerHeight : #{window_innerHeight}"

      document_documentElement_clientHeight = fetch("document.documentElement.clientHeight").to_i || 0
      @@logger.an_event.debug "document_documentElement_clientHeight : #{document_documentElement_clientHeight}"

      document_body_clientHeight = fetch("document.body.clientHeight").to_i || 0
      @@logger.an_event.debug "document_body_clientHeight : #{document_body_clientHeight}"

      document_documentElement_scrollHeight = fetch("document.documentElement.scrollHeight").to_i || 0
      @@logger.an_event.debug "document.documentElement.scrollHeight : #{document_documentElement_scrollHeight}"


      [window_innerHeight,
       document_documentElement_clientHeight,
       document_body_clientHeight,
       document_documentElement_scrollHeight].max

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
        wait(60, false, 1) { screenshot_tmp.exist? }
        @@logger.an_event.debug "page #{screenshot_tmp.vol} du screenshot #{screenshot_tmp.basename} existe"

        #si pas derniere page alors on passe à la page suivante
        if screenshot_tmp.vol.to_i <= page_count
          scrolling = (page_height * (page_index + 1)) + 1
          @@logger.an_event.debug "scrolling #{scrolling}"

          if chrome? || safari? || opera?
            fetch("document.body.scrollTop=#{scrolling}")
          end
          if ie? || firefox?
            fetch("document.documentElement.scrollTop=#{scrolling}")
          end
          @@logger.an_event.debug "scrolling down to #{scrolling}"
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

    def wait(timeout, exception = false, interval=0.2)

      if !block_given?
        sleep(timeout)
        return
      end

      #timeout = interval if $staging == "development" # on execute une fois

      while (timeout > 0)
        sleep(interval)
        timeout -= interval
        begin
          return if yield
        rescue Exception => e
          @@logger.an_event.warn "try again : #{e.message}"
        else
          @@logger.an_event.debug "try again."
        end
      end

      raise e if !e.nil? and exception == true

    end


  end

# Browser


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
