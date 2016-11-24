# encoding: utf-8
require_relative 'parameter'
require_relative 'logging'
require 'rest-client'


module Monitoring
  #--------------------------------------------------------------------------------------------------------------------
  # INIT
  #--------------------------------------------------------------------------------------------------------------------
  PARAMETERS = File.dirname(__FILE__) + "/../../parameter/monitoring_server.yml"
  ENVIRONMENT= File.dirname(__FILE__) + "/../../parameter/environment.yml"
  ADVERTNOTFOUND = :advertnotfound #identifie les visits pour lesquelles on a chercher un adword ou un adsens que lon a pas trouvé
  START = :started
  PUBLISHED = :published
  SUCCESS = :success
  FAIL = :fail
  OUTOFTIME = :outoftime
  NEVERSTARTED = :neverstarted
  OVERTTL = :overttl

  $staging = "production"
  $debugging = false
  attr_reader :statupweb_server_ip,
              :statupweb_server_port


  #--------------------------------------------------------------------------------------------------------------------
  # MODULE FUNCTION
  #--------------------------------------------------------------------------------------------------------------------
  def change_state_visit(visit_id, state, reason=nil)


    begin
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
      load_parameter()

      wait(60, true, 5) {
        response = RestClient.patch "http://#{@statupweb_server_ip}:#{@statupweb_server_port}/visits/#{visit_id}",
                                    JSON.generate(reason.nil? ? {:state => state} :
                                                      {:state => state, :reason => reason}),
                                    :content_type => :json,
                                    :accept => :json

      }

    rescue Exception => e
      @@logger.an_event.error "change state to #{state} of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else

      @@logger.an_event.debug "change state to #{state} of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port})"

    end
  end

  def visit_failed(visit_id, reason, log_path)
    change_state_visit(visit_id, FAIL, reason)
    send_log(visit_id, log_path)
  end

  def advert_not_found(visit_id, reason, log_path)
    change_state_visit(visit_id, ADVERTNOTFOUND, reason)
    send_log(visit_id, log_path)
  end

  def visit_started(visit_id, actions, ip_geo_proxy)
    begin
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
      load_parameter()

      wait(60, true, 5) {
        RestClient.patch "http://#{@statupweb_server_ip}:#{@statupweb_server_port}/visits/#{visit_id}/started",
                         JSON.generate({:actions => actions,
                                        :ip_geo_proxy => ip_geo_proxy}),
                         :content_type => :json,
                         :accept => :json

      }
    rescue Exception => e
      @@logger.an_event.error "change state to started state of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else
      @@logger.an_event.debug "change state to started state of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port})"

    ensure

    end
  end

  def page_browse(visit_id, actions, source_path, screenshot_path, count_finished_actions)

    # les actions sont optionnelles
    begin
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
      load_parameter()

      wait(60, true, 5) {
        response = RestClient.patch "http://#{@statupweb_server_ip}:#{@statupweb_server_port}/visits/#{visit_id}/browsed_page",
                                    JSON.generate({:actions => actions}),
                                    :content_type => :json,
                                    :accept => :json

      }
    rescue Exception => e
      @@logger.an_event.error "change count browse page of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else
      @@logger.an_event.debug "change count browse page of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port})"

    ensure

    end

    begin
      resource = RestClient::Resource.new("http://#{@statupweb_server_ip}:#{@statupweb_server_port}/pages")

      wait(60, true, 5) {
        if File.exist?(screenshot_path) and File.exist?(source_path)

          response = resource.post(:image => File.open(screenshot_path),
                                   :source => File.open(source_path),
                                   :visit_id => visit_id,
                                   :index => count_finished_actions)

        elsif File.exist?(screenshot_path)
          response = resource.post(:image => File.open(screenshot_path),
                                   :visit_id => visit_id,
                                   :index => count_finished_actions)

        elsif File.exist?(source_path)
          response = resource.post( :source => File.open(source_path),
                                   :visit_id => visit_id,
                                   :index => count_finished_actions)

        else
          response = resource.post(:visit_id => visit_id,
                                   :index => count_finished_actions)
        end


      }
    rescue Exception => e
      @@logger.an_event.error "send screenshot of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else
      @@logger.an_event.debug "send screenshot of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port})"
    end
  end

  def captcha_browse(visit_id, captcha_path, index, text=nil)
    #text est la value du captcha
    begin
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      resource = RestClient::Resource.new("http://#{@statupweb_server_ip}:#{@statupweb_server_port}/captchas")

      wait(60, true, 5) {
        if File.exist?(captcha_path)

          response = resource.post(:image => File.open(captcha_path),
                                   :visit_id => visit_id,
                                   :index => index,
                                   :text => text)
        else
          response = resource.post(:visit_id => visit_id,
                                   :index => index,
                                   :text => text)
        end


      }

    rescue Exception => e
      @@logger.an_event.error "send captcha of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else
      @@logger.an_event.debug "send captcha of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port})"

    end
  end

  private


  def load_parameter
    begin
      parameters = Parameter.new(__FILE__)
    rescue Exception => e
      raise "cannot load parameter #{e.message}"
    else
      $staging = parameters.environment
      $debugging = parameters.debugging
      @statupweb_server_ip = parameters.statupweb_server_ip
      @statupweb_server_port = parameters.statupweb_server_port
    end

  end

  def send_log(visit_id, log_path)
    begin
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
      load_parameter()

      resource = RestClient::Resource.new("http://#{@statupweb_server_ip}:#{@statupweb_server_port}/logs")

      wait(60, true, 5) {
        if File.exist?(log_path)
          resource.post(:file => File.open(log_path),
                        :visit_id => visit_id)
        else
          resource.post(:visit_id => visit_id)

        end
      }
    rescue Exception => e
      @@logger.an_event.error "send log file of visit #{visit_id} to (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else
      @@logger.an_event.debug "send log file of visit #{visit_id} to (#{@statupweb_server_ip}:#{@statupweb_server_port})"

    ensure

    end
  end

  # si pas de bloc passé => wait pour une duree passé en paramètre
  # si un bloc est passé => evalue le bloc tant que le bloc return false, leve une exception, ou que le timeout n'est pas atteind
  # qd le timeout est atteint, si exception == true alors propage l'exception hors du wait

  def wait(timeout, exception = false, interval=0.2)
    @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
    if !block_given?
      sleep(timeout)
      return
    end

    timeout = interval if $staging == "development" # on execute une fois

    while (timeout > 0)
      sleep(interval)
      timeout -= interval
      begin
        return if yield
      rescue Exception => e
        @@logger.an_event.debug "try again : #{e.message}"
      else
        @@logger.an_event.debug "try again."
      end
    end

    raise e if !e.nil? and exception == true

  end

  module_function :advert_not_found
  module_function :visit_started
  module_function :visit_failed
  module_function :change_state_visit
  module_function :page_browse
  module_function :captcha_browse
  module_function :load_parameter
  module_function :send_log
  module_function :wait

end