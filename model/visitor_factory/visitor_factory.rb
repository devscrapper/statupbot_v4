require 'trollop'
require 'eventmachine'
require 'yaml'
require 'em/threaded_resource'
require 'em/pool'
require 'timeout'
require_relative '../../lib/flow'
require_relative '../../lib/logging'
require_relative '../../lib/error'
require_relative '../../lib/monitoring'
require_relative '../geolocation/geolocation_factory'

class VisitorFactory
  #----------------------------------------------------------------------------------------------------------------
  # include class
  #----------------------------------------------------------------------------------------------------------------
  include EM::Deferrable
  include Errors
  include Geolocations
  #----------------------------------------------------------------------------------------------------------------
  # Exception message
  #----------------------------------------------------------------------------------------------------------------

  ARGUMENT_UNDEFINE = 1000
  NONE_FACTORY = 1001
  #----------------------------------------------------------------------------------------------------------------
  # constant
  #----------------------------------------------------------------------------------------------------------------
  VISITOR_BOT = Pathname(File.join(File.dirname(__FILE__), "..", "..", "run", "visitor_bot.rb")).realpath
  DIR_TMP = [File.dirname(__FILE__), "..", "..", "tmp"]

  OK = 0
  KO = 1
  ERR_VISIT_DEFINITION = 2
  ERR_VISIT_LOADING = 3
  ERR_VISIT_CREATION = 4
  ERR_VISIT_OVER_TTL = 5
  ERR_VISITOR_DEFINITON = 6
  ERR_VISITOR_CREATION = 7
  ERR_VISITOR_BIRTH = 8
  ERR_VISITOR_DEATH = 9
  ERR_VISITOR_INHUMATION = 10
  ERR_BROWSER_OPENING = 11
  ERR_BROWSER_CLOSING = 12
  ERR_LINK_TRACKING = 13
  ERR_ADVERT_TRACKING = 14
  ERR_CAPTCHA_SUBMITTING = 15
  ERR_VISIT_EXECUTION = 16
  #----------------------------------------------------------------------------------------------------------------
  # attribut
  #----------------------------------------------------------------------------------------------------------------
  attr :pool,
       :booked_port, #list des port d'écoute pour le proxy utilisés
       :patterns_managed # liste des browsers/version pris en charge par le VisitorFactory


  #----------------------------------------------------------------------------------------------------------------
  # class methods
  #----------------------------------------------------------------------------------------------------------------
  @@runtime_ruby = nil
  @@delay_out_of_time = nil
  @@geolocation_factory = nil
  @@delay_periodic_scan = nil
  @@max_time_to_live_visit = nil
  @@logger = nil

  def self.runtime_ruby=(runtime_ruby)
    @@runtime_ruby = runtime_ruby
  end

  def self.delay_out_of_time=(delay_out_of_time)
    @@delay_out_of_time = delay_out_of_time
  end

  def self.geolocation_factory=(geolocation_factory)
    @@geolocation_factory = geolocation_factory
  end

  def self.delay_periodic_scan=(delay_periodic_scan)
    @@delay_periodic_scan = delay_periodic_scan
  end

  def self.max_time_to_live_visit=(max_time_to_live_visit)
    @@max_time_to_live_visit = max_time_to_live_visit
  end

  def self.logger=(logger)
    @@logger = logger
  end

  #----------------------------------------------------------------------------------------------------------------
  # instance methods
  #----------------------------------------------------------------------------------------------------------------

  #-----------------------------------------------------------------------------------------------------------------
  # initialize
  #-----------------------------------------------------------------------------------------------------------------
  # input :
  # output :
  # exception :
  #-----------------------------------------------------------------------------------------------------------------
  #
  #-----------------------------------------------------------------------------------------------------------------
  def initialize(count_instance, start_port_proxy_sahi, proxy_ip_list)
    @pool = EM::Pool.new

    @booked_port = []

    @patterns_managed = []

    @@logger.an_event.debug "count_instance : #{count_instance}"
    @@logger.an_event.debug "start_port_proxy_sahi : #{start_port_proxy_sahi}"
    @@logger.an_event.debug "proxy_ip_list : #{proxy_ip_list}"

    (count_instance.divmod(proxy_ip_list.size)[1] == 0 ?
        count_instance.divmod(proxy_ip_list.size)[0].to_i # si reste == 0
    :
        count_instance.divmod(proxy_ip_list.size)[0].to_i + 1).times { |i| # commence à zero
      @booked_port << start_port_proxy_sahi - i # est utilisé pour creer les fichier de paramtrage browser type pour chrome et ff
      proxy_ip_list.each { |ip|
        visitor_instance = EM::ThreadedResource.new do
          {
              :port_proxy_sahi => start_port_proxy_sahi - i,
              :ip_proxy_sahi => ip
          }
        end
        @pool.add visitor_instance
        @@logger.an_event.debug "add one visitor instance : #{visitor_instance.inspect}"
      }
    }

  end

  #-----------------------------------------------------------------------------------------------------------------
  # scan_visit_file
  #-----------------------------------------------------------------------------------------------------------------
  # input :
  # browser, version, port_proxy_sahi, use_proxy_system
  # output :
  # exception :
  # StandardError :
  #-----------------------------------------------------------------------------------------------------------------
  #
  #-----------------------------------------------------------------------------------------------------------------
  def scan_visit_file (browser, version, use_proxy_system)
    begin

      pattern = "#{browser} #{version}" # ne pas supprimer le blanc
      @patterns_managed << pattern
      EM::PeriodicTimer.new(@@delay_periodic_scan) do
        tmp_flow_visits = Flow.list(File.join($dir_tmp || DIR_TMP),
                                    {:type_flow => pattern, :ext => "yml"},
                                    @@logger)

        if !tmp_flow_visits.empty?
          tmp_flow_visits.each { |tmp_flow_visit|
            @@logger.an_event.info "visit flow #{tmp_flow_visit.basename} selected"
            # si la date de planificiation de la visite portée par le nom du fichier est dépassée de 15mn alors la visit est out of time et ne sera jamais executé
            # ceci afin de ne pas dénaturer la planification calculer par enginebot.
            # pour pallier à cet engorgement, il faut augmenter le nombre d'instance concurrente de navigateur dans le fichier browser_type.csv
            # un jour peut être ce fonctionnement sera revu pour adapter automatiquement le nombre d'instance concurrente d'un nivagteur (cela nécessite de prévoir un pool de numero de port pour sahi proxy)
            # ajout 18/05/2016 : si delay_out_of_time == 0 alors les visits ne sont jamais hors delais comme developpement
            # qq soient la policy (seaattack, traffic, rank).
            # Demain cela pourrait être conditionné en fonction du type de visit qui nécessite absoluement de suivre
            # la planifiication comme Traffic pour ne pas dénaturé les statisitique GA du website
            start_time_visit = tmp_flow_visit.date.split(/-/)

            if $staging == "development" or # en developpement => pas de visit hors delais
                @@delay_out_of_time == 0 or # si delay_out_of_time == 0 => pas de visit hors délais
                ($staging != "development" and Time.now - Time.local(start_time_visit[0],
                                                                     start_time_visit[1],
                                                                     start_time_visit[2],
                                                                     start_time_visit[3],
                                                                     start_time_visit[4],
                                                                     start_time_visit[5]) <= @@delay_out_of_time * 60) # heure de déclenchement de la visit doit être dans le délaus imparti par @delay_out_of_time
              tmp_flow_visit.archive

              @@logger.an_event.debug "visit flow #{tmp_flow_visit.basename} archived"

              @pool.perform do |dispatcher|
                dispatcher.dispatch do |details|
                  @@logger.an_event.debug "port_proxy_sahi : #{details[:port_proxy_sahi]}"
                  @@logger.an_event.debug "ip_proxy_sahi : #{details[:ip_proxy_sahi]}"
                  start_visitor_bot({:pattern => pattern,
                                     :visit_file => tmp_flow_visit.absolute_path,
                                     :ip_proxy_sahi => details[:ip_proxy_sahi],
                                     :port_proxy_sahi => details[:port_proxy_sahi],
                                     :use_proxy_system => use_proxy_system})

                end
              end

            else
              # la date de planification de la visit est dépassée
              tmp_flow_visit.archive
              @@logger.an_event.info "visit flow #{tmp_flow_visit.basename} archived"

              visit = YAML::load(tmp_flow_visit.read)[:visit]
              tmp_flow_visit.close
              #envoie de l'etat out fo time à statupweb
              begin
                Monitoring.change_state_visit(visit[:id], Monitoring::OUTOFTIME)

              rescue Exception => e
                @@logger.an_event.warn e.message

              end
              @@logger.an_event.warn "visit #{tmp_flow_visit.basename} for #{pattern} is out of time."

            end
          }
        else
          #   @@logger.an_event.debug "none input visit for #{pattern}."

        end

      end
    rescue Exception => e
      @@logger.an_event.error "scan visit file for #{pattern} catch exception : #{e.message} => restarting"
      retry

    end
  end


  private
  #-----------------------------------------------------------------------------------------------------------------
  # start_visitor_bot
  #-----------------------------------------------------------------------------------------------------------------
  #-----------------------------------------------------------------------------------------------------------------
  # pour sandboxer l'execution d'un visitor_bot :
  # @runtime_start_sandbox = "C:\Program Files\Sandboxie\Start.exe"
  # @sand_box_id = n(3)
  # /nosbiectrl  ne lance pas le panneau de controle de sanbox
  # /silent  bloque l'affichage des messages
  # /elevate augmente les droits d'execution au niveau administrateur
  # /wait attend que le programme soit terminé
  # sandbox = "#{@runtime_start_sandbox} /box:#{@sand_box_id}  /nosbiectrl  /silent  /elevate /env:VariableName=VariableValueWithoutSpace /wait"
  # cmd = "#{sandbox} #{@runtime_ruby} -e $stdout.sync=true;$stderr.sync=true;load($0=ARGV.shift)  #{VISITOR_BOT} -v #{details[:visit_file]} -t #{details[:port_proxy_sahi]} -p #{@use_proxy_system} #{geolocation}"
  #-----------------------------------------------------------------------------------------------------------------
  def start_visitor_bot(details)
    begin

      @@logger.an_event.info "start visitor_bot with browser #{details[:pattern]} and visit file #{details[:visit_file]}"

      # si pas d'avert alors :  [:advert][:advertising] = "none"
      # sinon le nom de l'advertising, exemple adsense

      visit_details = YAML::load(File.open(details[:visit_file], "r:BOM|UTF-8:-").read)
      visit = visit_details[:visit]
      visitor = visit_details[:visitor]

      with_advertising = visit[:advert][:advertising] != :none
      with_google_engine = visitor[:browser][:engine_search] == :google && visit[:referrer][:medium] == :organic

      cmd = "#{@@runtime_ruby} -e $stdout.sync=true;$stderr.sync=true;load($0=ARGV.shift)  \
      #{VISITOR_BOT} \
      -v #{details[:visit_file]} \
      -l #{details[:ip_proxy_sahi]} \
      -i #{details[:port_proxy_sahi].to_i} \
      -p #{details[:use_proxy_system]} \
      -m #{@@max_time_to_live_visit}                   \
      #{geolocation(with_advertising, with_google_engine)}"

      @@logger.an_event.debug "cmd start visitor_bot #{cmd}"

      visitor_bot_pid = 0

      visitor_bot_pid = Timeout::timeout((@@max_time_to_live_visit + 2) * 60) {
        visitor_bot_pid = Process.spawn(cmd)
        visitor_bot_pid, status = Process.wait2(visitor_bot_pid, 0)
        visitor_bot_pid
      }
    rescue Timeout::Error => e
      #TODO remplacer taskkill par kill pour linux
      # kill du process qui contient ruby.exe, parfois il n'est pas tuer par windows qd visitor_bot s'arrete, prkoi ????
      # par sécurité => nettoyage.
      res = IO.popen("taskkill /PID #{visitor_bot_pid} /T /F").read
      @@logger.an_event.debug ("ruby.exe(#{visitor_bot_pid}) for visitor #{visitor} was killed : #{res}") unless res == ""

    rescue Exception => e
      @@logger.an_event.error "lauching visitor_bot with browser #{details[:pattern]} and visit file #{details[:visit_file]} : #{e.message}"
      change_visit_state(visit[:id], Monitoring::NEVERSTARTED)

    else
      @@logger.an_event.info "visitor_bot with browser #{details[:pattern]} and visit file #{details[:visit_file]} over : exit status #{status.exitstatus}"

      if status.exitstatus == OK
        delete_log_file(visitor[:id])

      elsif status.exitstatus == ERR_BROWSER_CLOSING

      end

    ensure
      @@logger.an_event.info "stop visitor_bot with browser #{details[:pattern]} and visit file #{details[:visit_file]}"
      #TODO remplacer taskkill par kill pour linux
      #TODO tester que le pid existe
      # kill du process qui contient ruby.exe, parfois il n'est pas tuer par windows qd visitor_bot s'arrete, prkoi ????
      # par sécurité => nettoyage.
      res = IO.popen("taskkill /PID #{visitor_bot_pid} /T /F").read
      @@logger.an_event.debug ("ruby.exe(#{visitor_bot_pid}) for visitor #{visitor} was killed : #{res}") unless res == ""

    end
  end

  #-----------------------------------------------------------------------------------------------------------------
  # initialize
  #-----------------------------------------------------------------------------------------------------------------
  # input :
  # output : parametre de lacement de visitor_bot pour la geolocation
  # exception :   RAS
  #-----------------------------------------------------------------------------------------------------------------
  #
  #-----------------------------------------------------------------------------------------------------------------
  def geolocation(with_advertising, with_google_engine)
    # si exception pour le get : NONE_GEOLOCATION => pas de geolocalisation
    # si exception pour le get_french : GEO_NONE_FRENCH => pas de geolocation francaise
    # sinon retour d'une geolocation qui est  :
    # soit issu d'une liste de proxy
    # soit le proxy par defaut de l'entreprise  passé en paramètre de visitorfactory_server : geolocation = "-r http -o muz11-wbsswsg.ca-technologies.fr -x 8080 -y ET00752 -w Bremb@15"
    # si la visit contient un advert alors on essaie de recuperer un geolocation francais.
    # si le moteur de recherche est google alors on essaie de recuperer une geolocation qui s'appuie sur https
    # sinon un geolocation.

    begin
      #TODO attention aton besoin de cette fonctionnalité sur la geolocation
      # geo = @@geolocation_factory.get(:country => with_advertising ? "fr" : nil,
      #                                :protocol => with_google_engine ? "https" : nil) unless @geolocation_factory.nil?
      geo = @@geolocation_factory.get(:country => nil,
                                      :protocol => nil) unless @@geolocation_factory.nil?
    rescue Exception => e
      @@logger.an_event.warn e.message
      geo_to_s = ""

    else

      geo_to_s = "-r #{geo.protocol} -o #{geo.ip} -x #{geo.port}"
      geo_to_s += " -y #{geo.user}" unless geo.user.nil?
      geo_to_s += " -w #{geo.password}" unless geo.password.nil?

    ensure
      @@logger.an_event.debug "geolocation is <#{geo_to_s}>"

      return geo_to_s

    end
  end


  def change_visit_state(visit_id, state)
    begin
      Monitoring.change_state_visit(visit_id, state)

    rescue Exception => e
      @@logger.an_event.warn ("change state #{state} of visit #{visit_id} : #{e.message}")

    else
      @@logger.an_event.info("change state #{state} of visit #{visit_id}")
    end
  end

  def delete_log_file(visitor_id)
    begin
      dir = Pathname(File.join(File.dirname(__FILE__), "..", '..', "log")).realpath
      files = File.join(dir, "visitor_bot_#{visitor_id}.{*}")
      FileUtils.rm_r(Dir.glob(files))

    rescue Exception => e
      @@logger.an_event.error "log file of visitor_bot #{visitor_id} not delete : #{e.message}"

    else
      @@logger.an_event.info "log file of visitor_bot #{visitor_id} delete"

    end
  end


end


class VisitorFactoryMultiInstanceExecution < VisitorFactory

  START_PORT_PROXY_SAHI = 9997

  def initialize(proxy_ip_list, count_instance)
    super(count_instance, START_PORT_PROXY_SAHI, proxy_ip_list)
    @@logger.an_event.info "Visitor Factory multi instance is on"

  end

  def pool_size

    @@logger.an_event.info "pool size visitor factory multi instance [#{@patterns_managed.join(",")}] : #{@pool.num_waiting}"

  end
end
class VisitorFactoryMonoInstanceExecution < VisitorFactory

  START_PORT_PROXY_SAHI = 9998

  def initialize(proxy_ip_list)
    super(1, START_PORT_PROXY_SAHI, proxy_ip_list)
    @@logger.an_event.info "Visitor Factory mono instance is on"
  end


  def pool_size
    @@logger.an_event.info "pool size visitor factory mono instance [#{@patterns_managed.join(",")}] : #{@pool.num_waiting}"

  end
end
