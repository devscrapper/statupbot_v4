#!/usr/bin/env ruby -w

require 'yaml'
require 'trollop'
require 'pathname'
require 'eventmachine'
require 'rufus-scheduler'
require_relative '../lib/logging'
require_relative '../lib/os'
require_relative '../lib/parameter'
require_relative '../lib/error'
require_relative '../model/browser/browser'
require_relative '../model/visitor_factory/visitor_factory'
require_relative '../model/geolocation/geolocation_factory'
require_relative '../lib/monitoring'
require_relative '../lib/supervisor'

# factory which execute visitor_bot with a visit
#
# Usage:
#        visitor_factory_server [options]
# where [options] are:
#   -p, --proxy-type=<s>                             Type of geolocation proxy
#                                                    use (none|factory|http)
#                                                    (default: none)
#   -r, --proxy-ip=<s>                               @ip of geolocation proxy
#   -o, --proxy-port=<i>                             Port of geolocation proxy
#   -x, --proxy-user=<s>                             Identified user of
#                                                    geolocation proxy
#   -y, --proxy-pwd=<s>                              Authentified pwd of
#                                                    geolocation proxy
#   -[, --[[:depends, [:proxy-user, :proxy-pwd]]]
#   -v, --version                                    Print version and exit
#   -h, --help                                       Show this message

DIR_TMP = [File.dirname(__FILE__), "..", "tmp"]

opts = Trollop::options do
  version "visitor factory server 0.4 (c) 2014 Dave Scrapper"
  banner <<-EOS
factory which execute visitor_bot with a visit

Usage:
       visitor_factory_server [options]
where [options] are:
  EOS
  opt :proxy_type, "Type of geolocation proxy use (none|factory|http)", :type => :string, :default => "none"
  opt :proxy_ip, "@ip of geolocation proxy", :type => :string
  opt :proxy_port, "Port of geolocation proxy", :type => :integer
  opt :proxy_user, "Identified user of geolocation proxy", :type => :string
  opt :proxy_pwd, "Authentified pwd of geolocation proxy", :type => :string
  opt depends(:proxy_user, :proxy_pwd)
end

Trollop::die :proxy_type, "is not in (none|factory|http)" if !["none", "factory", "http"].include?(opts[:proxy_type])
Trollop::die :proxy_ip, "is require with proxy" if ["http"].include?(opts[:proxy_type]) and opts[:proxy_ip].nil?
Trollop::die :proxy_port, "is require with proxy" if ["http"].include?(opts[:proxy_type]) and opts[:proxy_port].nil?

#--------------------------------------------------------------------------------------------------------------------
# LOAD PARAMETER
#--------------------------------------------------------------------------------------------------------------------
begin
  parameters = Parameter.new(__FILE__)

rescue Exception => e
  $stderr << e.message << "\n"

else
  $staging = parameters.environment
  $debugging = parameters.debugging
  runtime_ruby = parameters.runtime_ruby.join(File::SEPARATOR)
  delay_periodic_scan = parameters.delay_periodic_scan
  delay_out_of_time = parameters.delay_out_of_time
  delay_periodic_pool_size_monitor = parameters.delay_periodic_pool_size_monitor
  delay_periodic_load_geolocations = parameters.delay_periodic_load_geolocations
  periodicity_supervision = parameters.periodicity_supervision
  max_count_current_visit = parameters.max_count_current_visit
  max_time_to_live_visit = parameters.max_time_to_live_visit
  proxy_ip_list = parameters.proxy_ip_list
  $dir_archive = parameters.archive
  $dir_log = parameters.log
  $dir_tmp = parameters.tmp
  $dir_visitors = parameters.visitors

  if runtime_ruby.nil? or
      delay_periodic_scan.nil? or
      delay_out_of_time.nil? or
      delay_periodic_pool_size_monitor.nil? or
      delay_periodic_load_geolocations.nil? or
      periodicity_supervision.nil? or
      max_count_current_visit.nil? or
      max_time_to_live_visit.nil? or
      proxy_ip_list.nil? or
      $debugging.nil? or
      $staging.nil?
    $stderr << "some parameters not define\n" << "\n"
    exit(1)

  end
end
logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

logger.a_log.info "parameters of visitor factory server :"
logger.a_log.info "geolocation is : #{opts[:proxy_type]}"
logger.a_log.info "runtime ruby : #{runtime_ruby}"
logger.a_log.info "delay_periodic_scan (second) : #{delay_periodic_scan}"
logger.a_log.info "delay_periodic_pool_size_monitor (minute) : #{delay_periodic_pool_size_monitor}"
logger.a_log.info "delay_periodic_load_geolocations (minute) : #{delay_periodic_load_geolocations}"
logger.a_log.info "delay_out_of_time (minute): #{delay_out_of_time}"
logger.a_log.info "periodicity supervision : #{periodicity_supervision}"
logger.a_log.info "max count current visit : #{max_count_current_visit}"
logger.a_log.info "max time to live visit : #{max_time_to_live_visit}"
logger.a_log.info "proxy ip list : #{proxy_ip_list}"
logger.a_log.info "debugging : #{$debugging}"
logger.a_log.info "staging : #{$staging}"
logger.a_log.info "specify dir archive : #{$dir_archive}"
logger.a_log.info "specific dir log : #{$dir_log}"
logger.a_log.info "specific dir tmp : #{$dir_tmp}"
logger.a_log.info "specific dir visitors : #{$dir_visitors}"
#--------------------------------------------------------------------------------------------------------------------
# INCLUDE
#--------------------------------------------------------------------------------------------------------------------
include Errors

#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
begin

  EM.run do

    logger.a_log.info "visitor factory server is starting"

    Signal.trap("INT") { EventMachine.stop; }
    Signal.trap("TERM") { EventMachine.stop; }

    # supervision
    Supervisor.send_online(File.basename(__FILE__, '.rb'))
    Rufus::Scheduler.start_new.every periodicity_supervision do
      Supervisor.send_online(File.basename(__FILE__, '.rb'))
    end

    # association d'une geolocation factory à chaque visitor_factory pour eviter les contentions car chaque visitorFactory
    # s'execute dans un thread car c'est un EM::ThreadedResource
    # remarque  : mettre un Mutex sur @gelocations_factory genere l'erreur :  "deadlock; recursive locking"
    geolocation_factory = nil
    case opts[:proxy_type]
      when "none"

        logger.a_log.info "none geolocation"

      when "factory"

        logger.a_log.info "factory geolocation"
        Geolocations::GeolocationFactory.logger =logger
        geolocation_factory = Geolocations::GeolocationFactory.new

      when "http"

        logger.a_log.info "default geolocation : #{opts[:proxy_ip]}:#{opts[:proxy_port]}"
        geo_flow = Flow.new(File.join($dir_tmp || DIR_TMP),
                            "geolocations", 
                            $staging,
                            Date.today)
        geo_flow.write(["fr", opts[:proxy_type],
                        opts[:proxy_ip],
                        opts[:proxy_port], 
                        opts[:proxy_user], 
                        opts[:proxy_pwd]].join(Geolocations::Geolocation::SEPARATOR))
        geo_flow.close
        Geolocations::GeolocationFactory.logger =logger
        geolocation_factory = Geolocations::GeolocationFactory.new(geo_flow)

    end

    # si le nombre max d'occurence de visit concurrent est 1 alors toutes les visites qq soient les navugateurs
    # s'exécuteront dans VisitorFactoryMonoInstance pour assurer une execution à la fois
    case max_count_current_visit
      when 0
        raise Error.new(VisitorFactory::NONE_FACTORY)

      when 1

        VisitorFactory.runtime_ruby = runtime_ruby
        VisitorFactory.delay_out_of_time = delay_out_of_time
        VisitorFactory.delay_periodic_scan = delay_periodic_scan
        VisitorFactory.max_time_to_live_visit = max_time_to_live_visit
        VisitorFactory.geolocation_factory = geolocation_factory.nil? ? geolocation_factory : geolocation_factory.dup
        VisitorFactory.logger = logger

        vf_mono = VisitorFactoryMonoInstanceExecution.new(proxy_ip_list)

        bt = Mim::BrowserTypes.from_csv

        bt.browser.each { |name|
          bt.browser_version(name).each { |version|
            vf_mono.scan_visit_file(name,
                                    version,
                                    bt.proxy_system?(name, version) == true ? "yes" : "no") # use proxy_system

          }
        }


        EM.add_periodic_timer(delay_periodic_pool_size_monitor * 60) do vf_mono.pool_size end

      else

        #ces variables sontdes variable de classe de VisitorFactory
        VisitorFactory.runtime_ruby = runtime_ruby
        VisitorFactory.delay_out_of_time = delay_out_of_time
        VisitorFactory.delay_periodic_scan = delay_periodic_scan
        VisitorFactory.max_time_to_live_visit = max_time_to_live_visit
        VisitorFactory.geolocation_factory = geolocation_factory.nil? ? geolocation_factory : geolocation_factory.dup
        VisitorFactory.logger = logger

        vf_multi = VisitorFactoryMultiInstanceExecution.new(proxy_ip_list, max_count_current_visit - 1) # -1 car une occurence pour VisitorFactoryMonoInstanceExecution

        bt = Mim::BrowserTypes.from_csv

        vf_mono = VisitorFactoryMonoInstanceExecution.new(proxy_ip_list)

        bt.browser.each { |name|
          bt.browser_version(name).each { |version|
            if bt.proxy_system?(name, version) == true
              vf_mono.scan_visit_file(name,
                                      version,
                                       "yes") # use proxy_system

            else
              vf_multi.scan_visit_file(name,
                                      version,
                                      "no") # use proxy_system
            end
          }
        }
        EM.add_periodic_timer(delay_periodic_pool_size_monitor * 60) do vf_mono.pool_size end
        EM.add_periodic_timer(delay_periodic_pool_size_monitor * 60) do vf_multi.pool_size end
    end

  end

rescue Error => e
  Supervisor.send_failure(File.basename(__FILE__, '.rb'), e)

  case e.code
    when Browsers::Browser::BROWSER_LAUNCHER_FAILED,
        VisitorFactory::RUNTIME_BROWSER_PATH_NOT_FOUND,
        Geolocations::GEO_FILE_NOT_FOUND
      logger.a_log.fatal e
    else
      logger.a_log.error e
      logger.a_log.warn "visitor factory server restart"
      retry
  end

rescue Exception => e
  Supervisor.send_failure(File.basename(__FILE__, '.rb'), e)
  logger.a_log.error e
  logger.a_log.warn "visitor factory server restart"
  retry
end


logger.a_log.info "visitor factory server stopped"


