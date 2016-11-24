# encoding: utf-8
require_relative '../page/page'
require_relative '../browser/browser'
require_relative '../visit/referrer/referrer'
require_relative '../visit/advertising/advertising'
require_relative '../../lib/monitoring'
require_relative '../../lib/error'
require_relative '../../model/mim/proxy'
require 'pathname'

module Visitors

  class Visitor
    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors
    include Browsers
    include Visits::Referrers
    include Visits::Advertisings


    #----------------------------------------------------------------------------------------------------------------
    # Message exception
    #----------------------------------------------------------------------------------------------------------------

    ARGUMENT_UNDEFINE = 600
    VISITOR_NOT_CREATE = 601
    VISITOR_NOT_BORN = 602
    VISITOR_NOT_INHUME = 603
    VISITOR_NOT_FULL_EXECUTE_VISIT = 604
    VISITOR_NOT_CLOSE = 605
    VISITOR_NOT_DIE = 606
    VISITOR_NOT_OPEN = 607
    LOG_VISITOR_NOT_DELETE = 608
    VISITOR_NOT_CLICK_ON_ADVERT = 609
    VISITOR_NOT_CLICK_ON_LINK = 610
    VISITOR_NOT_CLICK_ON_LINK_ON_WEBSITE = 611
    VISITOR_NOT_CLICK_ON_LINK_ON_ADVERTISER = 612
    VISITOR_NOT_CLICK_ON_LINK_ON_UNKNOWN = 613
    VISITOR_NOT_START_LANDING = 614
    VISITOR_NOT_START_ENGINE_SEARCH = 615
    VISITOR_NOT_GO_BACK = 616
    VISITOR_NOT_CLICK_ON_RESULT = 617
    VISITOR_NOT_SUBMIT_FINAL_SEARCH = 618
    VISITOR_NOT_CLICK_ON_LANDING = 619
    VISITOR_NOT_GO_TO_LANDING = 620
    VISITOR_NOT_GO_TO_ENGINE_SEARCH = 621
    VISITOR_NOT_GO_TO_REFERRAL = 622
    VISITOR_NOT_CLICK_ON_NEXT= 623
    VISITOR_NOT_CLICK_ON_PREV = 624
    VISITOR_NOT_SUBMIT_SEARCH = 625
    VISITOR_NOT_KNOWN_ACTION = 626
    VISITOR_NOT_READ_PAGE = 627
    VISITOR_NOT_CHOOSE_LINK = 628
    VISITOR_NOT_CHOOSE_ADVERT = 629
    VISITOR_NOT_FOUND_LANDING = 630
    VISITOR_NOT_CLICK_ON_REFERRAL = 631
    VISITOR_SEE_CAPTCHA = 632
    VISITOR_NOT_SUBMIT_CAPTCHA = 633
    VISITOR_TOO_MANY_CAPTCHA = 634

    #----------------------------------------------------------------------------------------------------------------
    # constants
    #----------------------------------------------------------------------------------------------------------------
    DIR_VISITORS = [File.dirname(__FILE__), '..', '..', 'visitors']

    COMMANDS = {"a" => "go_to_start_landing",
                "b" => "go_to_start_engine_search",
                "c" => "go_back",
                "d" => "go_to_landing",
                "e" => "go_to_referral",
                "f" => "go_to_search_engine",
                "A" => "cl_on_next",
                "B" => "cl_on_prev",
                "C" => "cl_on_link_on_result",
                "D" => "cl_on_landing",
                "E" => "cl_on_link_on_website",
                "F" => "cl_on_advert",
                "G" => "cl_on_link_on_unknown",
                "H" => "cl_on_link_on_advertiser",
                "I" => "cl_on_referral",
                "0" => "sb_search",
                "2" => "sb_search",
                "1" => "sb_final_search",
                "3" => "manage_captcha"}

    MAX_COUNT_SUBMITING_CAPTCHA = 10 # nombre max de submission de captcha
    #----------------------------------------------------------------------------------------------------------------
    # variable de class
    #----------------------------------------------------------------------------------------------------------------
    @@logger = nil

    #----------------------------------------------------------------------------------------------------------------
    # attributs
    #----------------------------------------------------------------------------------------------------------------
    attr_reader :id, #id du visitor
                :browser, #browser utilisé par le visitor
                :visit, #la visit à exécuter
                :current_page, #page encours de visualisation par le visitor
                :home, #repertoire d'execution du visitor
                :proxy, #sahi : utilise le proxy sahi
                :failed_links, #liste links sur lesquels le visior a cliquer et une eexception a été elvée
                :history # liste des pages vues par le visitor lors du surf

    #----------------------------------------------------------------------------------------------------------------
    # class methods
    #----------------------------------------------------------------------------------------------------------------


    #----------------------------------------------------------------------------------------------------------------
    # instance methods
    #----------------------------------------------------------------------------------------------------------------
    #-----------------------------------------------------------------------------------------------------------------
    # born
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # exception :
    # StandardError :
    #
    #-----------------------------------------------------------------------------------------------------------------
    #  demarre le proxy sahi qui fait office de visitor
    #-----------------------------------------------------------------------------------------------------------------
    def born
      begin

        @proxy.start

      rescue Exception => e
        @@logger.an_event.error e.message
        raise Errors::Error.new(VISITOR_NOT_BORN, :error => e)

      else
        @@logger.an_event.info "visitor  is born"

      ensure

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------------------------------------------------------
    # - crée le visitor, le browser, la geolocation
    #----------------------------------------------------------------------------------------------------------------
    # input :
    #----------------------------------------------------------------------------------------------------------------
    def initialize(visitor_details)

      @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      @@logger.an_event.debug "visitor detail #{visitor_details}"

      begin
        raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_details"}) if visitor_details.nil?
        @history = History.new(COMMANDS)
        @failed_links = []

        @id = visitor_details[:id]


        @home = File.join($dir_visitors || DIR_VISITORS, @id)


        #------------------------------------------------------------------------------------------------------------
        #
        # on fait du nettoyage pour eviter de perturber le proxy avec un paramètrage bancal
        # creation du repertoitre d'execution du visitor
        #
        #------------------------------------------------------------------------------------------------------------

        if File.exist?(@home)
          FileUtils.rm_r(@home, :force => true) if File.exist?(@home)
          @@logger.an_event.debug "clean config files visitor dir #{@home}"
        end
        FileUtils.mkdir_p(@home)

        @@logger.an_event.debug "visitor create runtime directory #{@home}"

        #------------------------------------------------------------------------------------------------------------
        #
        #Configure SAHI PROXY
        #
        #------------------------------------------------------------------------------------------------------------
        @proxy = Mim::Proxy.new(@home,
                                visitor_details[:browser][:listening_ip_proxy],
                                visitor_details[:browser][:listening_port_proxy],
                                visitor_details[:browser][:proxy_ip],
                                visitor_details[:browser][:proxy_port],
                                visitor_details[:browser][:proxy_user],
                                visitor_details[:browser][:proxy_pwd])

        #------------------------------------------------------------------------------------------------------------
        #
        # configure Browser
        #
        #------------------------------------------------------------------------------------------------------------
        @browser = Browsers::Browser.build(@home,
                                           visitor_details[:browser])

      rescue Exception => e
        @@logger.an_event.error "visitor create runtime directory, config proxy Sahi and browser : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CREATE, :error => e)

      else
        @@logger.an_event.info "visitor create runtime directory, config proxy Sahi and browser"

      ensure

      end


    end


    #----------------------------------------------------------------------------------------------------------------
    # close_browser
    #----------------------------------------------------------------------------------------------------------------
    # ferme le navigateur :
    # inputs : RAS
    # output : RAS
    # StandardError : VISITOR_NOT_CLOSE
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def close_browser

      begin

        @browser.quit

      rescue Exception => e
        @@logger.an_event.error "visitor  close browser : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CLOSE, :error => e)

      else
        @@logger.an_event.info "visitor  close browser"
      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # die
    #----------------------------------------------------------------------------------------------------------------
    # arrete le proxy :
    # inputs : RAS
    # output : RAS
    # StandardError : VISITOR_NOT_DIE
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    def die
      begin

        @proxy.stop

      rescue Exception => e
        @@logger.an_event.error "visitor  die : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_DIE, :error => e)
      else
        @@logger.an_event.info "visitor  die"
      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # delete_log
    #----------------------------------------------------------------------------------------------------------------
    # supprimer les fichier de log
    # inputs : RAS
    # output : RAS
    # StandardError  : LOG_VISITOR_NOT_DELETE
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    def delete_log

      begin

        dir = Pathname(File.join(File.dirname(__FILE__), "..", '..', "log")).realpath
        files = File.join(dir, "visitor_bot_#{@id}.{*}")
        FileUtils.rm_r(Dir.glob(files), :force => true)

      rescue Exception => e
        @@logger.an_event.error "visitor  delete log  : #{e.message}"
        raise Errors::Error.new(LOG_VISITOR_NOT_DELETE, :error => e)

      else
        @@logger.an_event.info "visitor  delete log"

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # execute
    #----------------------------------------------------------------------------------------------------------------
    # execute une visite
    # inputs : object visit
    # output : RAS
    # StandardError  : ???
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    def execute (visit)
      #TODO tenter d'utiliser un Object ElementStub de Sahi pour les actions click
      #TODO tenter d'utiliser un Object Uri pour les actions go_to
      begin
        @visit = visit

        script = @visit.script
        @@logger.an_event.debug "script #{script}"

        count_finished_actions = 0

        for action in script
          @@logger.an_event.debug "current action  <#{action}>"

          begin

            raise Errors::Error.new(VISITOR_NOT_KNOWN_ACTION, :values => {:action => action}) if COMMANDS[action].nil?
            eval(COMMANDS[action])

          rescue Errors::Error => e

            case e.code

              when VISITOR_NOT_CLICK_ON_REFERRAL
                # le click sur le link du referral dans la page de results a échoué
                # force l'accès au referral par un accès direct
                act = "e"
                script.insert(count_finished_actions + 1, act)
                @@logger.an_event.info "visitor  make action <#{COMMANDS[act]}> instead of  <#{COMMANDS[action]}>"
                @@logger.an_event.debug "script #{script}"

              when VISITOR_NOT_READ_PAGE
                # ajout dans le script d'action pour revenir à la page précédent pour refaire l'action qui a planté.
                # ceci s'arretera quand il n'y aura plus de lien sur lesquel clickés ; lien choisi dans les 3 actions
                script.insert(count_finished_actions + 1, ["c", action]).flatten!
                @@logger.an_event.info "visitor  go back to make action #{COMMANDS[action]} again"
                @@logger.an_event.debug "script #{script}"

              when VISITOR_NOT_CLICK_ON_RESULT,
                  VISITOR_NOT_CLICK_ON_LINK_ON_ADVERTISER,
                  VISITOR_NOT_CLICK_ON_LINK_ON_UNKNOWN,
                  VISITOR_NOT_CLICK_ON_LINK_ON_WEBSITE
                # ajout dand le script d'une action pour choisir un autres results  ou un autre lien
                #  ceci s'arretera quand il n'y aura plus de lien sur lesquels clickés
                script.insert(count_finished_actions + 1, action)
                @@logger.an_event.info "visitor  make action <#{COMMANDS[action]}> again"
                @@logger.an_event.debug "script #{script}"

              when VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
                # un captcha est survenu, il a été impossible de le gerer
                # monitoring vers la console du script
                # arret de l'execution du script et donc de la visit
                @@logger.an_event.info "visitor stop visit because captcha"
                raise e #stop la visite

              else
                @@logger.an_event.error "visitor  make action  <#{COMMANDS[action]}> : #{e.message}"
                raise e #stop la visite
            end

          rescue Exception => e
            @@logger.an_event.error "visitor  make action <#{COMMANDS[action]}> : #{e.message}"
            raise e #stop la visit

          else
            @@logger.an_event.info "visitor  executed action <#{COMMANDS[action]}>."


          ensure
            # les Error : 
            # VISITOR_NOT_CLICK_ON_REFERRAL
            # VISITOR_NOT_READ_PAGE
            # VISITOR_NOT_CLICK_ON_RESULT,
            # VISITOR_NOT_CLICK_ON_LINK_ON_ADVERTISER,
            # VISITOR_NOT_CLICK_ON_LINK_ON_UNKNOWN,
            # VISITOR_NOT_CLICK_ON_LINK_ON_WEBSITE
            # passent par ENSURE 
            # les autres levent une exception dans le RESCUE donc ne passent pas par là. Elle seront captées par
            # les RESCUE qui englobele FOR
            @@logger.an_event.info @history.to_s
            source_path, screenshot_path = take_screenshot(count_finished_actions, action)

            Thread.new(@visit.id,
                       script,
                       source_path,
                       screenshot_path,
                       count_finished_actions) { |visit_id, script, source_path, screenshot_path, count_finished_actions|

              Monitoring.page_browse(visit_id, script, source_path,screenshot_path, count_finished_actions)

            }.join
            @@logger.an_event.info "visitor  executed #{count_finished_actions + 1}/#{script.size}(#{((count_finished_actions + 1) * 100 /script.size).round(0)}%) actions."
            count_finished_actions +=1

          end

        end


      rescue Exception => e
        @@logger.an_event.error "visitor execute visit : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_FULL_EXECUTE_VISIT, :error => e)

      else
        @@logger.an_event.info "visitor execute visit."

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------------------------------------------------------
    # demarre un proxy :
    # inputs

    # output
    # StandardError
    # StandardError
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    def inhume

      begin
        #-----------------------------------------------------------------------------------------------------------
        # supprime dir /visitors/visitor_id
        #-----------------------------------------------------------------------------------------------------------
        wait(10) {
          FileUtils.rm_r(File.join(@home)) if File.exist?(File.join(@home))
        }
        @@logger.an_event.debug "delete dir visitor_id <#{@home}>"

      rescue Exception => e
        @@logger.an_event.error "visitor  inhume : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_INHUME, :error => e)

      else
        @@logger.an_event.info "visitor  inhume"

      end
    end


    #----------------------------------------------------------------------------------------------------------------
    # open_browser
    #----------------------------------------------------------------------------------------------------------------
    # ouvre un browser :
    # inputs : none
    # output : none
    # StandardError
    # si le visiteur n'a pas pu lancer le navigateur.
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    def open_browser
      #creation d'une section critique
      File.open("screenshot", File::RDWR|File::CREAT, 0644) { |f|
        f.flock(File::LOCK_EX)
        begin

          @browser.open
          @browser.resize

        rescue Exception => e
          @@logger.an_event.error "visitor  open and resize browser : #{e.message}"
          raise Errors::Error.new(VISITOR_NOT_OPEN, :error => e)

        else
          @@logger.an_event.info "visitor  open and resize browser"


        end
      }
    end

    private


    # permet de choisir un link en s'assurant que ce link n'est pas un lien comme déja identifié ne fonctionnant pas car
    # il apprtient à la liste des failed_links connnu du visitor
    # les links déjà parcourus ne sont pas éliminé du choix car un visitor peut avoir envie
    # de revenir sur un lien déjà consulté
    # quand il n'y a plus de lien, on relais l'exception

    def choose_link(around = nil)
      begin

        link = @current_page.link(around) unless around.nil?
        link = @current_page.link if around.nil?
        while @failed_links.include?(link.url)
          link = @current_page.link(around) unless around.nil?
          link = @current_page.link if around.nil?
        end
        @failed_links.each { |l| @@logger.an_event.debug "failed_link : #{l}" }

      rescue Exception => e
        raise Errors::Error.new(VISITOR_NOT_CHOOSE_LINK, :error => e)

      else
        link

      end

    end

    def cl_on_advert

      @@logger.an_event.debug "action #{__method__}"
      #--------------------------------------------------------------------------------------------------------
      # Chose link
      #--------------------------------------------------------------------------------------------------------
      begin
        #Contrairement aux links qui sont calculés lors de la creation de l'objet Page, les liens des Adverts sont calculés
        #seulement avant de cliquer dessus car on evite de rechercher des liens pour rien.
        advert = @visit.advertising.advert(@browser)

        @@logger.an_event.debug "advert #{advert}"

      rescue Exception => e

        @@logger.an_event.error "visitor  chose advert on website : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CHOOSE_ADVERT, :error => e)

      else
        @@logger.an_event.info "visitor  chose advert on website."

      end

      #--------------------------------------------------------------------------------------------------------
      # Click on link
      #--------------------------------------------------------------------------------------------------------
      begin

        @browser.click_on(advert, true)

      rescue Exception => e

        @@logger.an_event.error "visitor  clicked on link advert on website : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_ADVERT, :error => e)

      else
        @@logger.an_event.info "visitor  clicked on link advert on website."

      end

      #--------------------------------------------------------------------------------------------------------
      # read Page
      #--------------------------------------------------------------------------------------------------------
      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Unmanage.new(@visit.advertising.advertiser.next_duration,
                                            @browser)

      rescue Errors::Error => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------

          @@logger.an_event.info "visitor browsed captcha instead advertiser website page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse advertiser website page"

          retry

        end

        @@logger.an_event.error "visitor browsed advertiser website page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Unmanage Website displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed advertiser website page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"
      end
    end

    def cl_on_landing

      @@logger.an_event.debug "action #{__method__}"

      #--------------------------------------------------------------------------------------------------------
      # Click on link
      #--------------------------------------------------------------------------------------------------------
      begin
        link = @visit.landing_link #Object Link

        @browser.click_on(link)

      rescue Exception => e

        @@logger.an_event.error "visitor clicked on landing link #{link.url} on results page : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_LANDING, :error => e)

      else
        @@logger.an_event.info "visitor  clicked on link #{link.url} on results page."

      end

      #--------------------------------------------------------------------------------------------------------
      # read Page
      #--------------------------------------------------------------------------------------------------------
      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Website.new(@visit, @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------

          @@logger.an_event.info "visitor browsed captcha instead website landing page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse website landing page"

          retry

        end
        @@logger.an_event.error "visitor browsed website landing page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Webiste displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed website landing page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end


    end


    def cl_on_link_on_advertiser
      @@logger.an_event.debug "action #{__method__}"
      #--------------------------------------------------------------------------------------------------------
      # Chose link
      #--------------------------------------------------------------------------------------------------------
      begin

        link = choose_link(@visit.advertising.advertiser.next_around)

      rescue Exception => e

        @@logger.an_event.error "visitor  chose link <#{link.url}> on advertiser website : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CHOOSE_LINK, :error => e)

      else
        @@logger.an_event.info "visitor  chose link <#{link.url}> on advertiser website."

      end

      #--------------------------------------------------------------------------------------------------------
      # Click on link
      #--------------------------------------------------------------------------------------------------------
      begin

        @browser.click_on(link)

      rescue Exception => e
        @failed_links << link.url
        @@logger.an_event.error "visitor clicked on link #{link.url} on advertiser website : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_LINK_ON_ADVERTISER, :error => e)

      else
        @@logger.an_event.info "visitor  clicked on link #{link.url}> on advertiser website."

      end

      #--------------------------------------------------------------------------------------------------------
      # read Page
      #--------------------------------------------------------------------------------------------------------
      begin
        @current_page = Pages::Unmanage.new(@visit.advertising.advertiser.next_duration,
                                            @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        @@logger.an_event.error "visitor browsed unmanage page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed unmanage page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    def cl_on_link_on_result
      #--------------------------------------------------------------------------------------------------------
      # Chose link
      #--------------------------------------------------------------------------------------------------------
      begin

        link = choose_link

      rescue Exception => e

        @@logger.an_event.error "visitor  chose link <#{link.url}> on results search : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CHOOSE_LINK, :error => e)

      else
        @@logger.an_event.info "visitor  chose link <#{link.url}> on results search."

      end

      #--------------------------------------------------------------------------------------------------------
      # Click on link
      #--------------------------------------------------------------------------------------------------------
      begin

        @browser.click_on(link)

      rescue Exception => e
        @failed_links << link.url
        @@logger.an_event.error "visitor clicked on link #{link.url} on results page : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_RESULT, :error => e)

      else
        @@logger.an_event.info "visitor clicked on link #{link.url} on results page."

      end

      #--------------------------------------------------------------------------------------------------------
      # read Page
      #--------------------------------------------------------------------------------------------------------
      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Unmanage.new(@visit.referrer.search_duration,
                                            @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------

          @@logger.an_event.info "visitor browsed captcha instead unknown website page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse unknown website page"

          retry

        end
        @@logger.an_event.error "visitor browsed unknown website page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed unknown website page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    def cl_on_link_on_unknown
      @@logger.an_event.debug "action #{__method__}"
      #--------------------------------------------------------------------------------------------------------
      # Chose link
      #--------------------------------------------------------------------------------------------------------
      begin

        link = choose_link(:inside_fqdn)

      rescue Exception => e

        @@logger.an_event.error "visitor chose link <#{link.url}> on unknown website : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CHOOSE_LINK, :error => e)

      else
        @@logger.an_event.info "visitor chose link <#{link.url}> on unknown website."

      end

      #--------------------------------------------------------------------------------------------------------
      # Click on link
      #--------------------------------------------------------------------------------------------------------
      begin

        @browser.click_on(link)

      rescue Exception => e
        @failed_links << link.url
        @@logger.an_event.error "visitor clicked on link #{link.url} on unknown website : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_LINK_ON_UNKNOWN, :error => e)

      else
        @@logger.an_event.info "visitor  clicked on link <#{link.url}> on unknown website."

      end

      #--------------------------------------------------------------------------------------------------------
      # read Page
      #--------------------------------------------------------------------------------------------------------
      begin
        @current_page = Pages::Unmanage.new(@visit.referrer.surf_duration,
                                            @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        @@logger.an_event.error "visitor browsed unmanage page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed unmanage page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    def cl_on_link_on_website
      @@logger.an_event.debug "action #{__method__}"

      #--------------------------------------------------------------------------------------------------------
      # Chose link
      #--------------------------------------------------------------------------------------------------------
      begin

        link = choose_link(@visit.around)

      rescue Exception => e

        @@logger.an_event.error "visitor  chose link <#{link.url}> on website : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CHOOSE_LINK, :error => e)

      else
        @@logger.an_event.info "visitor  chose link <#{link.url}> on website."

      end

      #--------------------------------------------------------------------------------------------------------
      # Click on link
      #--------------------------------------------------------------------------------------------------------
      begin

        @browser.click_on(link)

      rescue Exception => e
        @failed_links << link.url
        @@logger.an_event.error "visitor clicked on link #{link.url} on website : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_LINK_ON_WEBSITE, :error => e)

      else
        @@logger.an_event.info "visitor  clicked on link #{link.url} on website."

      end

      #--------------------------------------------------------------------------------------------------------
      # read Page
      #--------------------------------------------------------------------------------------------------------
      begin

        @current_page = Pages::Website.new(@visit, @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        @@logger.an_event.error "visitor browsed website page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed website page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end

    end

    def cl_on_next
      begin
        @@logger.an_event.debug "action #{__method__}"

        nxt = @current_page.next
        @@logger.an_event.debug "nxt #{nxt}"

        @browser.click_on(nxt)
        @@logger.an_event.debug "click on next"

      rescue Exception => e
        @@logger.an_event.error "visitor clicked on next : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_NEXT, :error => e)

      else
        @@logger.an_event.info "visitor clicked on next"

      end

      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Results.new(@visit,
                                           @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead next results search page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse next results search page"

          retry

        end

        @@logger.an_event.error "visitor browsed next results search page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed next results search page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    def cl_on_prev
      begin
        @@logger.an_event.debug "action #{__method__}"

        prv = @current_page.prev
        @@logger.an_event.debug "prv #{prv}"

        @browser.click_on(prv)
        @@logger.an_event.debug "click on prev"

      rescue Exception => e
        @@logger.an_event.error "visitor clicked on prev : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_PREV, :error => e)

      else
        @@logger.an_event.info "visitor clicked on prev"

      end

      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Results.new(@visit,
                                           @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead prev results search page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse prev results search page"

          retry

        end

        @@logger.an_event.error "visitor browsed prev results search page"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed prev results search page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    def cl_on_referral
      @@logger.an_event.debug "action #{__method__}"

      #--------------------------------------------------------------------------------------------------------
      # Click on link referral
      #--------------------------------------------------------------------------------------------------------
      begin
        link = @visit.referrer.referral_uri_search #Object Link

        @browser.click_on(link)

      rescue Exception => e

        @@logger.an_event.error "visitor clicked on referral link #{link.url} on results page : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_CLICK_ON_REFERRAL, :error => e)

      else
        @@logger.an_event.info "visitor clicked on link #{link.url} on results page."

      end

      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Unmanage.new(visit.referrer.duration, @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------

          @@logger.an_event.info "visitor browsed captcha instead referral website page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse referral website page"

          retry

        end
        @@logger.an_event.error "visitor browsed referral website page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed referral website page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end

    end

    def go_back
      begin
        @@logger.an_event.debug "action #{__method__}"

        before_last_page = @history.before_last_page
        current_url = @browser.url
        @@logger.an_event.debug "before_last_page  = #{before_last_page}"
        @@logger.an_event.debug "current_url = #{current_url}"

        if @history.is_before_last?(@browser.driver)
          # on est dans la même fenetre que la fenetre où on veut aller

          #2016/08/23 : simplification du go_back : si le go_back du browser n'amene pas sur la page voulu (IE, cpatcha, ...)
          # alors on navigue directement vers l'url du last_page
          #  while last_page.url != @browser.url
          #    url = @browser.url
          #    @browser.go_back
          #    # pour gérer le retour vers une page de resultats google pour IE : lors du go_back, IE execute à nouveau le redirect Google
          #    # porté par le lien resultat => boucle
          #    # comportement différent pour Chrome/FF qui ne réexécute pas la redirection.
          #    @browser.go_to(last_page.url) if @browser.url == url
          # end
          # simplification complete du go_back
          @browser.go_to(before_last_page.url)

        else
          #on en dans 2 fenetre differente : la principale et celle ouverte par le click sur la advert
          # on repositionne le focus sur la fenetre précédent
          # et on clos la fenetre ouverte par le click
          @@logger.an_event.debug "close popup #{@browser.driver.popup_name}"
          @browser.driver.close
          @browser.driver = @history.before_last_driver
        end

      rescue Exception => e

        @@logger.an_event.error "visitor went back to previous page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_GO_BACK, :error => e)

      else
        @@logger.an_event.info "visitor went back to previous page"

      end

      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin
        # @current_page = @history[@history.size - 2][1].
        # on ne reutitilise pas la page dan sl'history car cela permet de prendre en compte des changement qui
        # aurait été apporter par le Moteur de recherche lors de la redirection post captcha
        # cela permet aussi de déclencher à nouveau la détection d'une nouveau captcha
        @current_page = Pages::Results.new(@visit,
                                           @browser) if before_last_page.is_a?(Pages::Results)

        @current_page = Pages::EngineSearch.new(@visit,
                                                @browser) if before_last_page.is_a?(Pages::EngineSearch)

        @current_page = Pages::Unmanage.new(before_last_page.duration,
                                            @browser) if before_last_page.is_a?(Pages::Unmanage)
      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead #{before_last_page.class.name} page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse #{@current_page.class.name} page"

          retry

        end

        @@logger.an_event.error "visitor browsed #{@current_page.class.name} page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # go back to previous page displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed #{@current_page.class.name} page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    def go_to_landing
      begin
        @@logger.an_event.debug "action #{__method__}"
        url = @visit.landing_link.url
        @browser.go_to(url)

        @current_page = Pages::Website.new(@visit, @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        @@logger.an_event.error "visitor browsed landing page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_GO_TO_LANDING, :error => e)

      else

        @@logger.an_event.info "visitor browsed landing page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"
      end
    end

    def go_to_referral
      begin
        @@logger.an_event.debug "action #{__method__}"

        url = @visit.referrer.page_url.to_s
        @browser.go_to(url)

        @current_page = Pages::Unmanage.new(visit.referrer.duration, @browser)


      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        @@logger.an_event.error "visitor browsed referral page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_GO_TO_REFERRAL, :error => e)

      else

        @@logger.an_event.info "visitor browsed referral page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"
      end
    end

    def go_to_search_engine
      #--------------------------------------------------------------------------------------------------------
      # go to engine search page
      #--------------------------------------------------------------------------------------------------------
      begin
        @@logger.an_event.debug "action #{__method__}"

        url = @browser.engine_search.page_url

        @browser.go_to(url)

      rescue Exception => e
        @@logger.an_event.error "visitor went to engine search page <#{url}> : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_GO_TO_ENGINE_SEARCH, :error => e)

      else
        @@logger.an_event.info "visitor  went to engine search page <#{url}>"

      end

      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::EngineSearch.new(@visit,
                                                @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead results search page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse results search page"

          retry

        end

        @@logger.an_event.error "visitor browsed enginesearch page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page EngineSearch displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed enginesearch page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end

    end

    def go_to_start_engine_search
      #--------------------------------------------------------------------------------------------------------
      # Display start engine search page
      #--------------------------------------------------------------------------------------------------------
      begin
        @@logger.an_event.debug "action #{__method__}"

        url = @browser.engine_search.page_url

        @browser.display_start_page(url, @id)

      rescue Exception => e
        @@logger.an_event.error "visitor went to engine search page <#{url}> : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_START_ENGINE_SEARCH, :error => e)

      else
        @@logger.an_event.info "visitor went to engine search page <#{url}>"

      end

      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::EngineSearch.new(@visit,
                                                @browser)

      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead results search page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse results search page"

          retry

        end

        @@logger.an_event.error "visitor browsed enginesearch page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        @@logger.an_event.info "visitor browsed enginesearch page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end

    end

    def go_to_start_landing
      begin
        @@logger.an_event.debug "action #{__method__}"

        url = @visit.landing_link.url

        @browser.display_start_page(url, @id)

      rescue Exception => e
        @@logger.an_event.error "visitor went to landing page <#{url}> : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_START_LANDING, :error => e)

      else
        @@logger.an_event.info "visitor went to landing page <#{url}>"

      end

      begin

        @current_page = Pages::Website.new(@visit, @browser)


      rescue Exception => e
        Pages::Error.is_a?(@browser) # leve automatiquement une exception si erreur connue

        @@logger.an_event.error "visitor browsed website page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else

        @@logger.an_event.info "visitor browsed website page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"
      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # manage_captcha
    #----------------------------------------------------------------------------------------------------------------
    # n'est pas une action sb_, cl_, go_to_.
    # Elle n'apparait pas dans le script d'exécution des actions, car non programmable au moyen d'une grammaire en raison
    # du caractère aléatoire de la survenue du captcha.
    # inputs : RAS
    # output : RAS
    # VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def manage_captcha(max_count_submiting_captcha)

      begin
        #--------------------------------------------------------------------------------------------------------
        # captcha page replace a page : EngineSearch, Results, Unmanage
        #--------------------------------------------------------------------------------------------------------
        captcha_page = Pages::Captcha.new(@browser, @visit.id, @home)

        @browser.set_input_captcha(captcha_page.type, captcha_page.input, captcha_page.text)

        @browser.submit(captcha_page.submit_button)

      rescue Exception => e
        @@logger.an_event.error "visitor managed captcha : #{e.message}."
        raise Errors::Error.new(VISITOR_NOT_SUBMIT_CAPTCHA, :error => e)

      else
        @@logger.an_event.info "visitor managed captcha"
        max_count_submiting_captcha -= 1

        #si la soumission du text du captcha a échoué alors, google en affiche un nouveau.
        #le nouveau screenshot est dans un nouveau volume du flow.
        #le captcha précédent peut être déclaré comme bad aupres de de-capcher.
        #TODO Captchas::bad_string(id_visitor)
        Thread.new(@visit, captcha_page, max_count_submiting_captcha) { |visit, captcha_page, max_count_submiting_captcha|
          Monitoring::captcha_browse(visit.id,
                                     captcha_page.image.absolute_path,
                                     MAX_COUNT_SUBMITING_CAPTCHA - max_count_submiting_captcha + 1,
                                     captcha_page.text)
        }.join

        raise Errors::Error.new(VISITOR_TOO_MANY_CAPTCHA, :error => e) if max_count_submiting_captcha == 0

        max_count_submiting_captcha

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # read
    #----------------------------------------------------------------------------------------------------------------
    # lit le contenu d'une page affichée,
    # inputs : un objet page
    # output : none
    # StandartError
    # si aucune page n'est définie
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    def read(page)

      raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "page"}) if page.nil?

      @@logger.an_event.info "visitor begin reading <#{page.url}> during #{page.sleeping_time}s"

      sleep page.sleeping_time if $staging != "development"

      @@logger.an_event.debug "visitor finish reading on page <#{page.url}>"


    end


    def sb_final_search
      #--------------------------------------------------------------------------------------------------------
      # input keywords & submit search
      #--------------------------------------------------------------------------------------------------------
      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin
        @@logger.an_event.debug "action #{__method__}"

        keywords = @visit.referrer.keywords

        #permet d'utiliser des méthodes differentes en fonction des moteurs de recherche qui n'identifie pas l'input
        #des mot clé avec le même objet html
        #le omportement de Internet Explorer/Chrome/Opera est différent donc creation d'une méthode pour gérer l'initialisation de la zone de recherche.
        @browser.set_input_search(@current_page.type, @current_page.input, keywords)

        @@logger.an_event.debug "set input search #{@current_page.type} #{@current_page.input} #{keywords}"

        @browser.submit(@current_page.submit_button)

      rescue Exception => e
        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead final search page: #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse final search page"

          retry

        end
        @@logger.an_event.error "visitor submited final search <#{keywords}> : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_SUBMIT_FINAL_SEARCH, :error => e)

      else
        @@logger.an_event.info "visitor submited final search <#{keywords}>."

      end

      #--------------------------------------------------------------------------------------------------------
      # read Page
      #--------------------------------------------------------------------------------------------------------
      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Results.new(@visit,
                                           @browser)

      rescue Exception => e
        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead results search page: #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse results search page"

          retry

        end

        @@logger.an_event.error "visitor browsed results search page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed results search page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    def sb_search
      #--------------------------------------------------------------------------------------------------------
      # input keywords & submit search
      #--------------------------------------------------------------------------------------------------------
      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin
        @@logger.an_event.debug "action #{__method__}"

        keywords = @visit.referrer.next_keyword

        #permet d'utiliser des méthodes differentes en fonction des moteurs de recherche qui n'identifie pas l'input
        #des mot clé avec le même objet html
        #le omportement de Internet Explorer/Chrome/Opera est différent donc creation d'une méthode pour gérer l'initialisation de la zone de recerche.
        @browser.set_input_search(@current_page.type, @current_page.input, keywords)

        @@logger.an_event.debug "set input search #{@current_page.type} #{@current_page.input} #{keywords}"

        @browser.submit(@current_page.submit_button)

      rescue Exception => e
        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead search page: #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse search page"

          retry

        end

        @@logger.an_event.error "visitor submited search <#{keywords}> : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_SUBMIT_SEARCH, :error => e)

      else
        @@logger.an_event.info "visitor submited search <#{keywords}>."

      end

      max_count_submiting_captcha = MAX_COUNT_SUBMITING_CAPTCHA
      begin

        @current_page = Pages::Results.new(@visit,
                                           @browser)

      rescue Exception => e
        if Pages::Captcha.is_a?(@browser)
          #--------------------------------------------------------------------------------------------------------
          # Page Captcha displayed
          #--------------------------------------------------------------------------------------------------------
          @@logger.an_event.info "visitor browsed captcha instead results search page : #{e.message}"

          # leve les exception VISITOR_NOT_SUBMIT_CAPTCHA, VISITOR_TOO_MANY_CAPTCHA
          # max_count_submiting_captcha est diminuer dans manage_captcha
          max_count_submiting_captcha = manage_captcha(max_count_submiting_captcha)
          @@logger.an_event.info "visitor managed captcha, and go to browse results search page"

          retry

        end

        @@logger.an_event.error "visitor browsed results search page : #{e.message}"
        raise Errors::Error.new(VISITOR_NOT_READ_PAGE, :error => e)

      else
        #--------------------------------------------------------------------------------------------------------
        # Page Results displayed
        #--------------------------------------------------------------------------------------------------------
        @@logger.an_event.info "visitor browsed results search page"
        read(@current_page)


        @history.add(__method__, @browser.driver, @current_page)
        @@logger.an_event.debug "add current page to history"

      end
    end

    #-----------------------------------------------------------------------------------------------------------------
    # take_screenshot
    #-----------------------------------------------------------------------------------------------------------------
    # input : none
    # output : none
    # exception : none
    #-----------------------------------------------------------------------------------------------------------------
    #-----------------------------------------------------------------------------------------------------------------
    def take_screenshot(index, action)
      #-------------------------------------------------------------------------------------------------------------
      # save body au format text to fichier
      #-------------------------------------------------------------------------------------------------------------
      begin
        source_file = Flow.new(@home, index.to_s, action, Date.today, nil, ".txt")
        source_file.write(@browser.body)

      rescue Exception => e
        @@logger.an_event.debug "browser save body #{source_file.basename} : #{e.message}"

      else
        @@logger.an_event.debug "browser save body #{source_file.basename}"

      end

      #-------------------------------------------------------------------------------------------------------------
      # prise d'un screenshot au format image
      #-------------------------------------------------------------------------------------------------------------
      [source_file.absolute_path, @browser.take_screenshot(Flow.new(@home, index.to_s, action, Date.today, nil, ".png"))]

    end

    def wait(timeout)
      total = 0;
      interval = 0.2;

      if !block_given?
        sleep(timeout)
        return
      end

      while (total < timeout)
        sleep(interval);
        total += interval;
        begin
          return if yield
        rescue Exception => e
          @@logger.an_event.error e.message

        end
      end
    end
  end

  #-----------------------------------------------------------------------------------------------------------------
  # History
  #-----------------------------------------------------------------------------------------------------------------
  # contient la liste ordonnée de toutes les pages lues par le visitor parmi l'ensemble de driver utilisées lors de la visit
  #-----------------------------------------------------------------------------------------------------------------
  #-----------------------------------------------------------------------------------------------------------------

  class History < Array
    # array contenant un hash composé de
    # :driver : contient l'objet driver
    # :page : contient l'objet page

    attr_reader :cmds # hash des actions potentielles

    def initialize(commands)
      @cmds = commands
    end

    def add(method, driver, page)
      self << {:time => Time.now.strftime('%I:%M:%S %p'), :cmd => @cmds.key(method.to_s), :driver => driver, :page => page}
    end

    #retourn vrai ou faux si elt (= driver ou page) est before_last
    def is_before_last?(elt)
      self[self.size - 2][:page].url == elt.url or self[self.size - 2][:driver].popup_name == elt.popup_name
    end

    # retourn l'avant denriere page
    def before_last_page
      #@history[@history.size - 2][1].dup
      self[self.size - 2][:page].dup
    end

    # retourn l'avant denriere driver
    def before_last_driver
      #@history[@history.size - 2][1].dup
      self[self.size - 2][:driver].dup
    end

    def to_s
      end_col0 = 11
      end_col1 = 2
      end_col2 = 11
      end_col3 = 18
      end_col4 = 98
      res = "\n" + '|- BEGIN - HISTORY ---------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      res += '| Time         | Cmd | Driver       | Page                | Url                                                                                                 |' + "\n"
      res += '|---------------------------------------------------------------------------------------------------------------------------------------------------------------|' + "\n"
      self.each { |h|
        res += "| #{h[:time][0..end_col0].ljust(end_col0 + 2)}"
        res += "| #{h[:cmd][0..end_col1].ljust(end_col1 + 2)}"
        res += "| #{h[:driver].popup_name.to_s[0..end_col2].ljust(end_col2 + 2)}"
        res += "| #{h[:page].class.name[0..end_col3].ljust(end_col3 + 2)}"
        res += "| #{h[:page].url[0..end_col4].ljust(end_col4 + 2)}"
        res += "|\n"
      }
      res += "|- END - HISTORY------------------------------------------------------------------------------------------------------------------------------------------------|"
      res
    end
  end
end
