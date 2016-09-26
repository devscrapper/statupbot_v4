# encoding: utf-8
require_relative 'parameter'
require 'rest-client'


module Monitoring
  #--------------------------------------------------------------------------------------------------------------------
  # INIT
  #--------------------------------------------------------------------------------------------------------------------
  PARAMETERS = File.dirname(__FILE__) + "/../../parameter/monitoring_server.yml"
  ENVIRONMENT= File.dirname(__FILE__) + "/../../parameter/environment.yml"
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
      load_parameter()

      wait(60, true, 5) {
        response = RestClient.patch "http://#{@statupweb_server_ip}:#{@statupweb_server_port}/visits/#{visit_id}",
                                    JSON.generate(reason.nil? ? {:state => state} :
                                                      {:state => state, :reason => reason}),
                                    :content_type => :json,
                                    :accept => :json
        raise response.content unless [200,201,202,203,204,205,206].include?(response.code)
      }

    rescue Exception => e
      $stderr << "change state to #{state} of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else

    ensure

    end
  end

  def visit_started(visit_id, actions, ip_geo_proxy)
    begin
      load_parameter()

      wait(60, true, 5) {
        response = RestClient.patch "http://#{@statupweb_server_ip}:#{@statupweb_server_port}/visits/#{visit_id}/started",
                                    JSON.generate({:actions => actions,
                                                   :ip_geo_proxy => ip_geo_proxy}),
                                    :content_type => :json,
                                    :accept => :json
        raise response.content unless [200,201,202,203,204,205,206].include?(response.code)
      }
    rescue Exception => e
      $stderr << "change state to started state of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else

    ensure

    end
  end

  def page_browse(visit_id, actions, screenshot_path, count_finished_actions)

    # les actions sont optionnelles
    begin
      load_parameter()

      wait(60, true, 5) {
        response = RestClient.patch "http://#{@statupweb_server_ip}:#{@statupweb_server_port}/visits/#{visit_id}/browsed_page",
                                    JSON.generate({:actions => actions}),
                                    :content_type => :json,
                                    :accept => :json
        raise response.content unless [200,201,202,203,204,205,206].include?(response.code)
      }
    rescue Exception => e
      $stderr << "cannot change count browse page of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else

    ensure

    end

    begin
      resource = RestClient::Resource.new("http://#{@statupweb_server_ip}:#{@statupweb_server_port}/pages")

      wait(60, true, 5) {
        if File.exist?(screenshot_path)
          image = File.open(screenshot_path)

          response = resource.post(:image => image,
                                   :visit_id => visit_id,
                                   :index => count_finished_actions)
        else
          response = resource.post(:visit_id => visit_id,
                                   :index => count_finished_actions)
        end
        #   JSON.parse(response)
        raise response.content unless [200,201,202,203,204,205,206].include?(response.code)
      }
    rescue Exception => e
      $stderr << "cannot create browsed page of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else

    end
  end

  def captcha_browse(visit_id, captcha_path, index, text=nil)
    #text est la value du captcha
    begin
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
        #   JSON.parse(response)
        raise response.content unless [200,201,202,203,204,205,206].include?(response.code)
      }

    rescue Exception => e
      $stderr << "cannot create browsed captcha of visit #{visit_id} (#{@statupweb_server_ip}:#{@statupweb_server_port}) => #{e.message}"

    else

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

  # si pas de bloc passé => wait pour une duree passé en paramètre
  # si un bloc est passé => evalue le bloc tant que le bloc return false, leve une exception, ou que le timeout n'est pas atteind
  # qd le timeout est atteint, si exception == true alors propage l'exception hors du wait

  def wait(timeout, exception = false, interval=0.2)

    if !block_given?
      sleep(timeout)
      return
    end

    while (timeout > 0 and $staging != "development")
      sleep(interval)
      timeout -= interval
      begin
        return if yield
      rescue Exception => e
        p "try again : #{e.message}"
      else
        p "try again."
      end
    end

    if exception == true  and $staging != "development"

      raise e
    else

    end
  end

  module_function :visit_started
  module_function :change_state_visit
  module_function :page_browse
  module_function :captcha_browse
  module_function :load_parameter
  module_function :wait

end