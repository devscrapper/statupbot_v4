require 'uuid'
require 'uri'
require 'json'
require 'csv'
require 'pathname'
require 'nokogiri'
require 'addressable/uri'
require 'win32/screenshot'
require 'win32/window'
require 'win32/mutex'
require_relative '../engine_search/engine_search'
require_relative '../page/link'
require_relative '../page/page'
require_relative '../../lib/error'
require_relative '../../lib/flow'
require_relative 'driver'
#bilbiothèque interface avec sahi :
require_relative '../mim/browser_type' #gestion des browser type


module Browsers
  class Browser
    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors
    include Pages
    include EngineSearches
    include Mim
    #----------------------------------------------------------------------------------------------------------------
    # Exception message
    #----------------------------------------------------------------------------------------------------------------
    ARGUMENT_UNDEFINE = 300
    BROWSER_NOT_CREATE = 301
    BROWSER_UNKNOWN = 302
    BROWSER_NOT_FOUND_LINK = 303
    BROWSER_NOT_DISPLAY_PAGE = 304
    BROWSER_NOT_CLICK = 305
    BROWSER_NOT_OPEN = 306
    BROWSER_NOT_CLOSE = 307
    BROWSER_NOT_SEARCH = 308
    BROWSER_NOT_TAKE_SCREENSHOT = 309
    BROWSER_NOT_CUSTOM_FILE = 310
    BROWSER_NOT_ACCESS_URL = 311
    BROWSER_NOT_DISPLAY_START_PAGE = 312
    BROWSER_NOT_CONNECT_TO_SERVER = 313
    BROWSER_NOT_GO_BACK = 314
    BROWSER_NOT_SUBMIT_FORM = 315
    BROWSER_NOT_FOUND_ALL_LINK = 316
    BROWSER_NOT_FOUND_URL = 317
    BROWSER_NOT_FOUND_TITLE = 318
    BROWSER_NOT_GO_TO = 319
    BROWSER_NOT_FOUND_BODY = 320
    BROWSER_CLICK_MAX_COUNT = 321
    BROWSER_NOT_SET_INPUT_SEARCH = 322
    BROWSER_NOT_SET_INPUT_CAPTCHA = 323
    BROWSER_NOT_TAKE_CAPTCHA = 324
    BROWSER_NOT_RELOAD = 325
    BROWSER_NOT_RESIZE = 326

    #----------------------------------------------------------------------------------------------------------------
    # constants
    #----------------------------------------------------------------------------------------------------------------
    WINDOW_NAME = "main_tab" #nom de la fenetre ou de longlet ouvert dans le navigateur pour la visit exclusivement
    #afin de demarrer avec un history vide (sans display start page, ...)
    ACCEPT_POPUP = true # autorise l'ouverture d'une nouvelle fentre ou tab pour executer la visite apres le display start page
    NO_ACCEPT_POPUP = false # execution de la viste dans la fenetre ou tab courante du display start page
    NO_REFERER = "noreferrer"
    DATA_URI = "datauri"
    WITHOUT_LINKS = false #utiliser pour préciser que on ne recupere pas les links avec la fonction de l'extension javascript : get_details_cuurent_page
    WITH_LINKS = true
    DIR_TMP = [File.dirname(__FILE__), "..", "..", "tmp"]
    #----------------------------------------------------------------------------------------------------------------
    # variable de class
    #----------------------------------------------------------------------------------------------------------------
    @@logger = nil
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------
    attr_accessor :driver, # moyen Sahi pour piloter le browser
                  :listening_ip_proxy, # machine qui execute le proxy Sahi
                  :listening_port_proxy # port d'ecoute du proxy Sahi


    attr_reader :pid, # du processu du browser
                :id, #id du browser
                :height, :width, #dimension de la fenetre du browser
                :current_page, #page/onglet visible du navigateur
                :method_start_page, # pour cacher le referrer aux yeux de GA, on utiliser 2 methodes choisies en focntion
                # du type de browser.
                :method_access_popup, #determine si le display start page s'ouvre dans un nouvel onglet ou fenetre
                :version, # la version du browser
                :engine_search, #moteur de recherche associé par defaut au navigateur
                :window #object windows contenant les proprietes

    #----------------------------------------------------------------------------------------------------------------
    # class methods
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # instance methods
    #----------------------------------------------------------------------------------------------------------------
    #-----------------------------------------------------------------------------------------------------------------
    # all_links
    #-----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : tableau de link
    # Array of {'href' => ...., 'target' => ...., 'text' => ...}
    # exception :
    # si aucun link n'a été trouvé
    #-----------------------------------------------------------------------------------------------------------------
    #
    #-----------------------------------------------------------------------------------------------------------------
    def all_links

      links = []

      begin
        results_hsh = JSON.parse(@driver.links)
        @@logger.an_event.debug format_links(results_hsh["links"])

        links_str = results_hsh["links"]
        @@logger.an_event.debug "links_str String ? #{links_str.is_a?(String)}"
        @@logger.an_event.debug "links_str Array ? #{links_str.is_a?(Array)}"

        if links_str.is_a?(String)
          links_arr = JSON.parse(links_str)
        else
          links_arr = links_str
        end

        links_arr.each { |d|
          if d["text"] != "undefined"
            links << {"href" => d["href"], "text" => URI.unescape(d["text"].gsub(/&#44;/, "'"))} # if @driver.link(d["href"]).visible?
          else
            links << {"href" => d["href"], "text" => d["href"]}
          end
        }

        @@logger.an_event.debug format_links(links)

      rescue Exception => e
        @@logger.an_event.error e.message
        raise Errors::Error.new(BROWSER_NOT_FOUND_ALL_LINK, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "browser found all links"
        links

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # build
    #----------------------------------------------------------------------------------------------------------------
    # crée un geolocation :
    #----------------------------------------------------------------------------------------------------------------
    # input :
    # repertoire de runtime du visitor
    # détails du browser issue du fichier de visit :
    # :name: Chrome
    # :version: '33.0.1750.117'
    # :operating_system: Windows
    # :operating_system_version: '7'
    # :flash_version: 11.5 r502      # 2014/09/10 : non utilisé
    # :java_enabled: 'Yes'           # 2014/09/10 : non utilisé
    # :screens_colors: 32-bit        # 2014/09/10 : non utilisé
    # :screen_resolution: 1366x768
    # output : none
    # StandardError :
    # les paramètres en entrée font défaut
    # le type de browser est inconnu
    # une exception provenant des classes Firefox, InterneEexplorer, Chrome
    #----------------------------------------------------------------------------------------------------------------
    #         #Les navigateurs disponibles sont definis dans le fichier d:\sahi\userdata\config\browser_types.xml
    #----------------------------------------------------------------------------------------------------------------
    def self.build(visitor_dir, browser_details)
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      @@logger.an_event.debug "visitor_dir #{visitor_dir}"
      @@logger.an_event.debug "browser_details #{browser_details}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_dir"}) if visitor_dir.nil? or visitor_dir == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "browser name"}) if browser_details.nil? or \
        browser_details[:name].nil? or \
        browser_details[:name] == ""

        browser_name = browser_details[:name]
        # le browser name doit rester une chaine de car (et pas un symbol) car tout le param BrowserType utilise le format chaine de caractere
        case browser_name
          when "Firefox"
            return Firefox.new(visitor_dir, browser_details)

          when "Internet Explorer"
            return InternetExplorer.new(visitor_dir, browser_details)

          when "Chrome"
            return Chrome.new(visitor_dir, browser_details)

          when "Safari"
            return Safari.new(visitor_dir, browser_details)

          when "Edge"
            return Edge.new(visitor_dir, browser_details)

          when "Opera"
            return Opera.new(visitor_dir, browser_details)

          else
            raise Errors::Error.new(BROWSER_UNKNOWN, :values => {:browser => browser_name})
        end
      rescue Exception => e
        @@logger.an_event.error "browser create : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_CREATE, :values => {:browser => browser_name}, :error => e)

      else
        @@logger.an_event.debug "browser create"
      ensure

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # body
    #----------------------------------------------------------------------------------------------------------------
    # fournit le source du body de la page courante
    #----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : Nokogiri Object contenant le body
    # exception :
    # si on ne trouve pas le body
    # si parsing html du source echoue
    #----------------------------------------------------------------------------------------------------------------
    def body
      begin

        src = ""
        src = @driver.body

      rescue Exception => e
        @@logger.an_event.error "browser get html page : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_FOUND_BODY, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "browser get html page"

      end

      begin

        body = Nokogiri::HTML(src)

      rescue Exception => e
        @@logger.an_event.error "browser parse html page : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_FOUND_BODY, :values => {:browser => name}, :error => e)

      else

        @@logger.an_event.debug "browser parse html page"
        body

      end
    end


    #-----------------------------------------------------------------------------------------------------------------
    # click_on
    #-----------------------------------------------------------------------------------------------------------------
    # input : objet Link, elementStub, String, URI
    # output : RAS
    # exception :
    # StandardError :
    # si link n'est pas defini
    # StandardError :
    # si impossibilité technique de clicker sur le lien
    #-----------------------------------------------------------------------------------------------------------------
    #
    #-----------------------------------------------------------------------------------------------------------------
    def click_on(link, accept_popup = false)
      @@logger.an_event.debug "link to click #{link}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "link"}) if link.nil?

        # recherche du link dans la page courante
        link_element = search_link?(link)

        # on interdit les ouvertures de fenetre pour rester dans la fenetre courante.
        if !accept_popup and link_element.fetch("target") == "_blank"
          link_element.setAttribute("target", "")
          @@logger.an_event.debug "target of #{link_element.identifiers} change to ''"
        end


        url_before = url
        @@logger.an_event.debug "url before #{url_before}"

        link_element.click
        @@logger.an_event.debug "click on #{link_element}"

        # on attend tq que les url_before et url courante sont identiques, au max 20s.
        url_after = ""
        wait(20, true, 2) {
          raise "page not refresh with url #{link_element.identifiers}" if url_before == (url_after = url)
          url_before != url_after
        }
        @@logger.an_event.debug "url after #{url_after}"

        # on autorise d'ouvrir un nouvel onglet ou fenetre que pour les pub qui le demande sinon les autres liens
        # restent dans leur fenetre.
        # est ce qu'une nouvelle fenetre ou onglet a été créé qui est difféerent de celui sur lequel on est qd on est
        # déjà sur une nouvelle fenetre ou onglet
        if @driver.new_popup_is_open?(url_after)
          if accept_popup
            # si popup est ouverte sur au click d'une pub alors on remplace le driver principal par celui de la nouvelle fenetre
            @driver = @driver.focus_popup(url_after)
            @@logger.an_event.debug "replace driver by popup driver"

          else
            # si un bout de code javascript ouvre une nouvelle fenetre <=> impossible de l'identifier et de corriger le
            #comportement avant de cliquer sur le lien
            # => clos les fenetres apres le click.
            @driver.close_popups(url_after)
            @@logger.an_event.debug "close popup"
          end
        end

      rescue Exception => e
        @@logger.an_event.error "browser click on url : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_CLICK, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "browser click on url #{link_element.identifiers}"

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # display_start_page
    #----------------------------------------------------------------------------------------------------------------
    # ouvre un nouvelle fenetre du navigateur adaptée aux propriété du naviagateur et celle de la visit
    # affiche la root page du site https pour initialisé le référer à non défini
    #----------------------------------------------------------------------------------------------------------------
    # input : url (String)
    # output : Objet Page
    # exception :
    # StandardError :
    # si il est impossble d'ouvrir la page start
    # StandardError :
    # Si il est impossible de recuperer les propriétés de la page
    #----------------------------------------------------------------------------------------------------------------
    def display_start_page (start_url)

      @@logger.an_event.debug "start_url : #{start_url}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "start_url"}) if start_url.nil? or start_url == ""

        @driver.replace(start_url)

        Pages::Error.is_a?(self) # leve automatiquement une exception si erreur connue

      rescue Exception => e
        raise Errors::Error.new(BROWSER_NOT_DISPLAY_START_PAGE,
                                :values => {:browser => name, :page => start_url},
                                :error => e)
      else
        @@logger.an_event.info "history_size <#{@driver.history_size}>"
        @@logger.an_event.info "referrer <#{@driver.referrer}>"

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # exist_element?
    #----------------------------------------------------------------------------------------------------------------
    # test l'existance d'un element sur la page courante
    #----------------------------------------------------------------------------------------------------------------
    # input : type de l'objet html(textbox, button, ...), id de lobjet html
    # output : true si trouvé, sinon false
    #
    #----------------------------------------------------------------------------------------------------------------
    def exist_element?(type, id)
      raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "type"}) if type.nil? or type.empty?
      raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "id"}) if id.nil? or id.empty?

      @@logger.an_event.debug "type #{type}"
      @@logger.an_event.debug "id #{id}"

      r = "@driver.#{type}(\"#{id}\")"
      @@logger.an_event.debug "r : #{r}"
      @@logger.an_event.debug "eval(r) : #{eval(r)}"

      exist = eval(r).exists?
      @@logger.an_event.debug "eval(r).exists? : #{exist}"

      exist

    end


    def get_window_by_pid

      begin
        @window = RAutomation::Window.new(:pid => @pid)

      rescue Exception => e
        @@logger.an_event.error "browser get window by pid #{e.message}"

      else
        @@logger.an_event.debug "browser get window by pid"

      end

    end


    def get_pid_by_process_name

      # retourn le pid du browser ; au cas où Sahi n'arrive pas à le tuer.
      count_try = 3
      begin
        require 'csv'
        #TODO remplacer tasklist par ps pour linux
        res = IO.popen('tasklist /V /FI "IMAGENAME eq ' + @driver.browser_process_name + '" /FO CSV /NH').read

        @@logger.an_event.debug "result tasklist : #{res}"

        CSV.parse(res) do |row|
          @pid = row[1].to_i
          break
        end

        raise "sahiid not found in title browser in tasklist " if @pid.nil?

      rescue Exception => e
        if count_try > 0
          @@logger.an_event.debug "try #{count_try}, browser has no pid : #{e.message}"
          sleep (1)
          retry
        else
          raise "browser type has no pid : #{e.message}"

        end

      else
        @@logger.an_event.debug "browser has pid #{@pid}"

      end
    end

    def get_pid_by_title
      #modifie le titre de la fenetre pour rechercher le handle de la fenetre
      @driver.set_title(@driver.sahisid)
      @@logger.an_event.debug "set windows title browser with #{@driver.sahisid.to_s}"

      # retourn le pid du browser ; au cas où Sahi n'arrive pas à le tuer.
      count_try = 3
      begin
        require 'csv'
        #TODO remplacer tasklist par ps pour linux
        res = IO.popen('tasklist /V /FI "IMAGENAME eq ' + @driver.browser_process_name + '" /FO CSV /NH').read

        @@logger.an_event.debug "result tasklist : #{res}"

        CSV.parse(res) do |row|
          if row[8].include?(@driver.sahisid.to_s)
            @pid = row[1].to_i
            break

          end
        end

        raise "sahiid not found in title browser in tasklist " if @pid.nil?

      rescue Exception => e
        if count_try > 0
          @@logger.an_event.debug "try #{count_try}, browser has no pid : #{e.message}"
          sleep (1)
          retry
        else
          raise "browser type has no pid : #{e.message}"

        end

      else
        @@logger.an_event.debug "browser has pid #{@pid}"

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # go_back
    #----------------------------------------------------------------------------------------------------------------
    # cick sur le bouton back du navigateur
    #----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : RAS
    #----------------------------------------------------------------------------------------------------------------
    def go_back
      begin
        @driver.back

      rescue Exception => e
        @@logger.an_event.error "browser go back : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_GO_BACK, :values => {:browser => name}, :error => e)

      else

        @@logger.an_event.debug "browser go back"

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # go_to
    #----------------------------------------------------------------------------------------------------------------
    # force le navigateur à aller à la page referencée par l'url
    #----------------------------------------------------------------------------------------------------------------
    # input : url
    # output : RAS
    #----------------------------------------------------------------------------------------------------------------
    def go_to (url)
      begin
        @driver.navigate_to(url)

      rescue Exception => e
        @@logger.an_event.error "browser go to #{url} : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_GO_TO, :values => {:browser => name, :url => url}, :error => e)

      else

        @@logger.an_event.debug "browser go to #{url}"

      ensure

      end
    end

    #-----------------------------------------------------------------------------------------------------------------
    # initialize
    #-----------------------------------------------------------------------------------------------------------------
    # input : hash decrivant les propriétés du browser de la visit
    # :name : Internet Explorer
    # :version : '9.0'
    # :operating_system : Windows
    # :operating_system_version : '7'
    # :flash_version : 11.7 r700   -- not use
    # :java_enabled : 'Yes'        -- not use
    # :screens_colors : 32-bit     -- not use
    # :screen_resolution : 1600 x900
    # output : un objet Browser
    # exception :
    # StandardError :
    # si le listening_port_proxy n'est pas defini
    # si la resolution d'ecran du browser n'est pas definie
    # si le type de browser n'est pas definie
    # si la méthode démarrage n'est pas définie
    # si le runtime dir n'est pas definie
    #-----------------------------------------------------------------------------------------------------------------
    #
    #-----------------------------------------------------------------------------------------------------------------
    def initialize(visitor_dir, browser_details, browser_type, method_start_page, method_access_popup)


      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "listening_port_proxy"}) if browser_details[:listening_port_proxy].nil? or browser_details[:listening_port_proxy] == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "screen_resolution"}) if browser_details[:screen_resolution].nil? or browser_details[:screen_resolution] == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "method_start_page"}) if method_start_page.nil? or method_start_page == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "method_access_popup"}) if method_access_popup.nil? or method_access_popup == ""

        @@logger.an_event.debug "listening_port_proxy #{browser_details[:listening_port_proxy]}"
        @@logger.an_event.debug "screen_resolution #{browser_details[:screen_resolution]}"
        @@logger.an_event.debug "method_start_page #{method_start_page}"
        @@logger.an_event.debug "method_access_popup #{method_access_popup}"

        @id = UUID.generate
        @method_start_page = method_start_page
        @method_access_popup = method_access_popup
        @listening_port_proxy = browser_details[:listening_port_proxy]
        @listening_ip_proxy = browser_details[:listening_ip_proxy]
        @width, @height = browser_details[:screen_resolution].split(/x/)

        BrowserTypes.exist?([visitor_dir, "userdata", "config"], browser_type)

        @engine_search = EngineSearch.build(browser_details[:engine_search])

        @driver = Sahi::Browser.new(browser_type,
                                    BrowserTypes.process_name([visitor_dir, "userdata", "config"], browser_type),
                                    @listening_ip_proxy,
                                    @listening_port_proxy)


        initialized_htm = File.join(visitor_dir, "htdocs", "spr", 'initialized.htm')
        file_custom = File.read(initialized_htm)
        file_custom.gsub!(/start_url/, @engine_search.fqdn_search + @engine_search.path_search)

        File.write(initialized_htm, file_custom)
        @@logger.an_event.debug "update start url in htdocs/spr/initialized.htm"

      rescue Exception => e
        @@logger.an_event.error "browser initialize : #{e.message}"
        raise e

      else
        @@logger.an_event.debug "browser initialize"

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # is_captcha_page?
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    # input :
    # output :
    #----------------------------------------------------------------------------------------------------------------
    def is_captcha_page?
      current_url = url
      bool = @engine_search.is_captcha_page?(current_url)
      if bool
        @@logger.an_event.info "current url #{current_url} is captcha page"

      else
        @@logger.an_event.info "current url #{current_url} not captcha page"

      end
      bool
    end

    #----------------------------------------------------------------------------------------------------------------
    # is_reachable_url?
    #----------------------------------------------------------------------------------------------------------------
    # controle que l'url est accessible
    #----------------------------------------------------------------------------------------------------------------
    # input : url
    # output : true|false
    #----------------------------------------------------------------------------------------------------------------
    def is_reachable_url?(url)
      begin
        wait(15, true, 1) {
          RestClient.get url
        }

      rescue Exception => e
        @@logger.an_event.debug "url #{url} unreachable : #{e.message}"
        false

      else
        @@logger.an_event.debug "url #{url} reachable"
        true

      end
    end

    #-----------------------------------------------------------------------------------------------------------------
    # kill_by_pid
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # exception :
    # StandardError :
    #-----------------------------------------------------------------------------------------------------------------
    #   1-kill du  process avec son pid
    #-----------------------------------------------------------------------------------------------------------------

    def kill_by_pid
      count_try = 3

      @@logger.an_event.debug "going to kill browser with pid #{@pid}"
      begin
        #TODO remplacer taskkill par kill pour linux
        res = IO.popen("taskkill /PID #{@pid} /T /F").read

        @@logger.an_event.debug "result taskkill : #{res}"

      rescue Exception => e
        if count_try > 0
          @@logger.an_event.debug "try #{count_try}, kill pid #{@pid} : #{e.message}"
          count_try -= 1
          sleep (1)
          retry
        end

        @@logger.an_event.error "kill browser with pid #{@pid} : #{e.message}"
        raise Errors::Error.new(CLOSE_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "kill browser with pid #{@pid}"

      end
    end

    #-----------------------------------------------------------------------------------------------------------------
    # kill_by_process_name
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # exception :
    # StandardError :
    #-----------------------------------------------------------------------------------------------------------------
    #   1-kill tous les process avec leur nom de processus
    #-----------------------------------------------------------------------------------------------------------------

    def kill_by_process_name
      count_try = 3

      @@logger.an_event.debug "going to kill browser with process name #{@driver.browser_process_name}"
      begin
        #TODO remplacer taskkill par kill pour linux
        res = IO.popen("taskkill /IM #{@driver.browser_process_name}* /T /F").read

        @@logger.an_event.debug "result taskkill : #{res}"

      rescue Exception => e
        if count_try > 0
          @@logger.an_event.debug "try #{count_try},kill process name #{@driver.browser_process_name} : #{e.message}"
          count_try -= 1
          sleep (1)
          retry
        end

        @@logger.an_event.error "kill browser with process name #{@driver.browser_process_name} : #{e.message}"
        raise Errors::Error.new(CLOSE_DRIVER_FAILED, :error => e)

      else
        @@logger.an_event.debug "kill browser with process name #{@driver.browser_process_name}"

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # name
    #----------------------------------------------------------------------------------------------------------------
    # retourne le nom du navigateur
    #----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : le nom du browser
    #----------------------------------------------------------------------------------------------------------------
    def name
      @driver.browser_type
    end


    #-----------------------------------------------------------------------------------------------------------------
    # quit
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # StandardError :
    # si il n'a pas été possible de killer le browser
    #-----------------------------------------------------------------------------------------------------------------
    #   1-demande la fermeture du browser au driver
    #   2-kill du browser si la demande d'arret a sahi à echouer
    #-----------------------------------------------------------------------------------------------------------------
    def quit

      begin

        @driver.quit

      rescue Exception => e
        @@logger.an_event.warn "browser close : #{e.message}"

      else
        @@logger.an_event.debug "browser close"

      end

      begin
        kill if running?

      rescue Exception => e
        @@logger.an_event.error "browser kill : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_CLOSE, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "browser kill"

      end

    end

    #----------------------------------------------------------------------------------------------------------------
    # reload
    #----------------------------------------------------------------------------------------------------------------
    # recharge la page courant
    #----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : RAS
    #----------------------------------------------------------------------------------------------------------------
    def reload
      begin
        @driver.reload

      rescue Exception => e
        @@logger.an_event.error "browser reload #{url}"
        raise Errors::Error.new(BROWSER_NOT_RELOAD, :values => {:url => url}, :error => e)

      else

        @@logger.an_event.debug "browser reload #{url}"

      ensure

      end
    end


    def running_by_pid?

      require 'csv'
      #TODO remplacer tasklist par ps pour linux
      res = IO.popen('tasklist /V /FI "PID eq ' + @pid.to_s + '" /FO CSV /NH').read

      @@logger.an_event.debug "tasklist for #{@pid.to_s} : #{res}"

      CSV.parse(res) do |row|
        if row[1].nil?
          # res == Informationÿ: aucune tƒche en service ne correspond aux critŠres sp‚cifi‚s.
          # donc le pid n'existe plus => le browser nest plus running
          return false
        else
          return true if row[1].include?(@pid.to_s)

        end
      end
      #ne doit jamais arriver ici
      false

    end


    def running_by_process_name?

      require 'csv'
      #TODO remplacer tasklist par ps pour linux
      res = IO.popen('tasklist /V /FI "IMAGENAME eq ' + @driver.browser_process_name + '" /FO CSV /NH').read

      @@logger.an_event.debug "result tasklist : #{res}"

      CSV.parse(res) do |row|
        if row[0].nil?
          # res == Informationÿ: aucune tƒche en service ne correspond aux critŠres sp‚cifi‚s.
          # donc le pid n'existe plus => le browser nest plus running
          return false
        else
          return true if row[0].include?(@driver.browser_process_name.to_s)

        end
      end
      #ne doit jamais arriver ici
      false

    end

    #-----------------------------------------------------------------------------------------------------------------
    # resize
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # exception :
    # StandardError :
    #-----------------------------------------------------------------------------------------------------------------
    #-----------------------------------------------------------------------------------------------------------------
    def resize
      begin
        #Rautomation ne sait pas resizé
        @driver.resize(@width.to_i, @height.to_i)

        # si screenshot est pris avec sahi et peut prendre un element graphique et pas une page ou destop alors on peut
        # eviter de deplacer à l'origine du repere pour fiabiliser la prise de photo du captcha.
        #TODO move to linux
        # move n'existe pas dans Rautomation
        #@window.move(0, 0)

        #cache la fenetre du navigateur
        @window.minimize

      rescue Exception => e
        @@logger.an_event.error "browser resize : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_RESIZE, :values => {:browser => name}, :error => e)

      else

        @@logger.an_event.debug "browser resize"

      ensure

      end

    end

    #----------------------------------------------------------------------------------------------------------------
    # searchbox
    #----------------------------------------------------------------------------------------------------------------
    # affecte une valeur à une searchbox
    #----------------------------------------------------------------------------------------------------------------
    # input :
    # nom de la variable
    # valeur de la variable
    # output : RAS
    #----------------------------------------------------------------------------------------------------------------
    def searchbox(var, val)
      input = @driver.searchbox(var)
      input.value = val
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

        @@logger.an_event.debug "type : #{type}"
        @@logger.an_event.debug "input : #{input}"
        @@logger.an_event.debug "keywords : #{keywords}"

        #teste la présence de la zone de saisie pour eviter d'avoir une erreur technique
        raise "search textbox not found" unless exist_element?(type, input)

        #remplissage de la zone caractère par caractère pour simuler qqun qui tape au clavier
        kw = ""
        keywords.split(//).each { |c|
          kw += c
          r = "#{type}(\"#{input}\", \"#{kw}\")"
          @@logger.an_event.debug "eval(r) : #{r}"
          eval(r)
        }


      rescue Exception => e
        @@logger.an_event.fatal "set input search #{type} #{input} with #{keywords} : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_SET_INPUT_SEARCH, :values => {:browser => name, :type => type, :input => input, :keywords => keywords}, :error => e)

      else
        @@logger.an_event.debug "set input search #{type} #{input} with #{keywords}"

      end
    end

    def url_start_page(start_url, visitor_id)
      encode_start_url = Addressable::URI.encode_component(start_url, Addressable::URI::CharacterClasses::UNRESERVED)

      url = "http://#{$start_page_server_ip}:#{$start_page_server_port}/start_link?"
      url += "method=#{@method_start_page}&"
      url += "url=#{encode_start_url}&"
      url += "visitor_id=#{visitor_id}&"
      url += "popup=#{@method_access_popup}&"
      url += "window=#{WINDOW_NAME}"
      url
    end

    #----------------------------------------------------------------------------------------------------------------
    # set_input_captcha
    #----------------------------------------------------------------------------------------------------------------
    # affecte le mot du captcha dans la zone de saisie du captcha
    #----------------------------------------------------------------------------------------------------------------
    # input :
    # type :
    # input :
    # keywords :
    # output : RAS
    #----------------------------------------------------------------------------------------------------------------
    def set_input_captcha(type, input, captcha)
      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "type"}) if type.nil? or type == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "input"}) if input.nil? or input == ""
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "captcha"}) if captcha.nil? or captcha == ""

        @@logger.an_event.debug "type : #{type}"
        @@logger.an_event.debug "input : #{input}"
        @@logger.an_event.debug "captcha : #{captcha}"

        r = "#{type}(\"#{input}\", \"#{captcha}\")"
        @@logger.an_event.debug "eval(r) : #{r}"
        eval(r)

      rescue Exception => e
        @@logger.an_event.error "set input captcha #{type} #{input} with #{captcha} : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_SET_INPUT_CAPTCHA, :values => {:browser => name, :type => type, :input => input, :keywords => captcha}, :error => e)

      else
        @@logger.an_event.debug "set input search #{type} #{input} with #{captcha}"

      end
    end


    #-----------------------------------------------------------------------------------------------------------------
    # submit
    #-----------------------------------------------------------------------------------------------------------------
    # input : un formulaire
    # output : RAS
    # exception :
    # StandardError :
    # si la soumission echoue
    # si le formulaire n'est pas fourni
    #-----------------------------------------------------------------------------------------------------------------
    #-----------------------------------------------------------------------------------------------------------------
    def submit(form)

      @@logger.an_event.debug "form #{form}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "form"}) if form.nil?

        @driver.submit(form).click

      rescue Exception => e
        @@logger.an_event.error "browser submit form #{form} : #{ e.message}"
        raise Errors::Error.new(BROWSER_NOT_SUBMIT_FORM, :values => {:browser => name, :form => form}, :error => e)

      else
        @@logger.an_event.debug "browser submit form #{form}"

      ensure

      end

    end

    #-----------------------------------------------------------------------------------------------------------------
    # take_screenshot
    #-----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : image du contenu du browser stocker dans un fichier :
    #  localisé dans le repertoire screenshot (par default), sinon défini par le flow
    #  nom du fichier : browser_name, beowser_version, title_crt_page[0..32], date du jour.png, nombre de minute depuis 00:00
    #  sinon défini par le flow
    # exception : none
    #-----------------------------------------------------------------------------------------------------------------
    # on ne genere pas d'execption pour ne pas perturber la remonter des exception de visitor_bot, car ce n'est pas
    # grave si on ne pas faire de screenshot
    # => on ne fait que logger
    #-----------------------------------------------------------------------------------------------------------------
    def take_screenshot(output_file=nil)
      if output_file.nil?

        title = @driver.title
        @@logger.an_event.debug title
        output_file = Flow.new(DIR_TMP,
                               @driver.name.gsub(" ", "-"),
                               title[0..32],
                               Date.today,
                               Time.parse(Tim.now).hour * 3600 + Time.parse(Time.now).min * 60,
                               ".png")

      end

      #-------------------------------------------------------------------------------------------------------------
      # prise du screenshot avec canvas, en premiere intention
      #-------------------------------------------------------------------------------------------------------------
      begin
        #prise du screenshot
        @driver.take_screenshot_body_by_canvas(output_file)

      rescue Exception => e
        @@logger.an_event.error "screenshot by canvas : #{e.message}"
        # echec de la prise du screenshot avec canvas on essaie avec win32screenshot
        #-------------------------------------------------------------------------------------------------------------
        # prise du screenshot avec win32screenshot
        #-------------------------------------------------------------------------------------------------------------
        #creation d'une section critique, car avec win32screenshot on mt en avant plan le browser car on prend
        #une photo du destop ; screener que le browser generait des white & blanc screen
        File.open(File.join($dir_tmp || DIR_TMP, "screenshot"), File::RDWR|File::CREAT, 0644) { |f|
          f.flock(File::LOCK_EX)
          begin
            # affiche le browser en premier plan
            #TODO update for linux
            @window.restore if @window.minimized?
            @window.activate
            @@logger.an_event.debug "restore de la fenetre du browser"

            #prise du screenshot
            @driver.take_screenshot(output_file, @height.to_i)

            # cache le browser
            @window.minimize
            @@logger.an_event.debug "minimize de la fenetre du browser"
          rescue Exception => e
            @@logger.an_event.error "browser take screen shot avec win32screenshot #{output_file.basename} : #{e.message}"
            @@logger.an_event.error Messages.instance[BROWSER_NOT_TAKE_SCREENSHOT, {:browser => name, :title => title}]

          else
            @@logger.an_event.info "browser take screen shot #{output_file.basename}"

          ensure

          end
        }
      else
        @@logger.an_event.info "browser take screen shot avec canvas #{output_file.basename}"

      end


      output_file.absolute_path

    end

    #-----------------------------------------------------------------------------------------------------------------
    # take_captcha
    #-----------------------------------------------------------------------------------------------------------------
    # input : output file captcha, coordonate of captcha on screen
    # output : image du captcha
    # exception : technique
    #-----------------------------------------------------------------------------------------------------------------
    #-----------------------------------------------------------------------------------------------------------------


    def take_captcha(output_file, coord_captcha)
      #-------------------------------------------------------------------------------------------------------------
      # prise du captcha avec canvas, en premiere intention
      #-------------------------------------------------------------------------------------------------------------
      begin
        #prise du screenshot
        @driver.take_screenshot_element_by_id_by_canvas(output_file, @engine_search.css_image_captcha)

      rescue Exception => e
        @@logger.an_event.error "captcha by canvas : #{e.message}"
        # echec de la prise du captcha avec canvas on essaie avec win32screenshot
        #-------------------------------------------------------------------------------------------------------------
        # prise du captcha avec win32screenshot
        #-------------------------------------------------------------------------------------------------------------
        #creation d'une section critique, car avec win32screenshot on mt en avant plan le browser car on prend
        #une photo du destop ; screener que le browser generait des white & blanc screen
        File.open(File.join($dir_tmp || DIR_TMP, "screenshot"), File::RDWR|File::CREAT, 0644) { |f|
          f.flock(File::LOCK_EX)
          begin
            # affiche le browser en premier plan
            @window.restore if window.minimized?
            @window.activate
            @@logger.an_event.debug "restore de la fenetre du browser"

            @driver.take_screenshot_area(output_file, coord_captcha)

          rescue Exception => e
            @@logger.an_event.fatal "take captcha : #{e.message}"
            raise Errors::Error.new(BROWSER_NOT_TAKE_CAPTCHA, :values => {:browser => name, :title => title}, :error => e)

          else

            @@logger.an_event.info "browser take captcha"

          ensure
            #-------------------------------------------------------------------------------------------------------------
            # cache le browser
            #-------------------------------------------------------------------------------------------------------------
            @window.minimize
            @@logger.an_event.debug "minimize de la fenetre du browser"

          end
        }

      else
        @@logger.an_event.info "browser take captcha"

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # textbox
    #----------------------------------------------------------------------------------------------------------------
    # affecte une valeur à un textbox
    #----------------------------------------------------------------------------------------------------------------
    # input :
    # nom de la variable
    # valeur de la variable
    # output : RAS
    #----------------------------------------------------------------------------------------------------------------
    def textbox(var, val)
      input = @driver.textbox(var)
      input.value = val
    end

    #-----------------------------------------------------------------------------------------------------------------
    # title
    #-----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : titre de la page courante
    # exception :
    #-----------------------------------------------------------------------------------------------------------------
    #
    #-----------------------------------------------------------------------------------------------------------------
    def title

      begin
        title ||= @driver.title

      rescue Exception => e
        @@logger.an_event.error "browser found title : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_FOUND_TITLE, :values => {:browser => name}, :error => e)

      else

        @@logger.an_event.debug "browser found title #{title}"
        title

      ensure

      end
    end

    #-----------------------------------------------------------------------------------------------------------------
    # url
    #-----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : url de la page
    # exception :
    #-----------------------------------------------------------------------------------------------------------------
    #
    #-----------------------------------------------------------------------------------------------------------------
    def url

      begin
        url = @driver.current_url

      rescue Exception => e
        @@logger.an_event.error "get current url : #{e.message}"
        raise Errors::Error.new(BROWSER_NOT_FOUND_URL, :values => {:browser => name}, :error => e)

      else
        @@logger.an_event.debug "get current url : #{url}"
        url
      end
    end

    private

    #----------------------------------------------------------------------------------------------------------------
    # exist_link
    #----------------------------------------------------------------------------------------------------------------
    # test l'existance du link
    #----------------------------------------------------------------------------------------------------------------
    # input : Object Link, Objet URI, String url   , elementStub,
    # output : RAS si trouvé, sinon une exception Browser not found link
    #
    #----------------------------------------------------------------------------------------------------------------
    def search_link?(link)

      begin
        @@logger.an_event.debug "link is a #{link.class.name}"
        links = []
        if link.is_a?(Pages::Link)
          links += [link.text, link.url, link.url_escape].map! { |l| @driver.create_link(l) }
          link_url = link.url

        else
          links << @driver.create_link(link)
          link_url = links[0].identifiers

        end
        @@logger.an_event.debug "search links : "; links.each { |l| @@logger.an_event.debug l.inspect }

        exist = false
        link_found = nil
        links.each { |l|
          begin # pour eviter les exception sahi
            if exist = l.exists?
              link_found = l
              break
            end
          rescue Exception => e
            @@logger.an_event.debug "l.exists?(#{l.inspect}) : #{e.message}"

          end
        }

        raise "none link found" unless exist

      rescue Exception => e
        @@logger.an_event.error "search_link?: #{e.message}"

        raise Errors::Error.new(BROWSER_NOT_FOUND_LINK, :values => {:domain => "", :identifier => link_url}, :error => e)

      else
        @@logger.an_event.debug "search_link? success"

        link_found

      end
    end

    def format_links(links)
      end_col0 = 145
      end_col1 = 40
      end_col2 = 83
      end_col3 = 25
      res = "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += "| Counts : #{links.size.to_s[0..end_col0].ljust(end_col0 + 2)}|" + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += '| Text                                      | Url                                                                                  | Target                     |' + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      links.each { |l|
        res += "| #{URI.unescape(l["text"]).gsub(/[\n\r\t]/, ' ')[0..end_col1].ljust(end_col1 + 2)}"
        res += "| #{l["href"][0..end_col2].ljust(end_col2 + 2)}"
        res += "| #{(l["target"].nil? ? "none" : l["target"])[0..end_col3].ljust(end_col3 + 2)}"
        res += "|\n"
      }
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res
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


end
require_relative 'firefox'
require_relative 'internet_explorer'
require_relative 'chrome'
require_relative 'safari'
require_relative 'opera'
require_relative 'edge'