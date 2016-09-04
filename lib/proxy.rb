# encoding: utf-8
require_relative 'parameter'
require 'rest-client'


module Proxy
  #--------------------------------------------------------------------------------------------------------------------
  # INIT
  #--------------------------------------------------------------------------------------------------------------------
  PARAMETERS = File.dirname(__FILE__) + "/../../parameter/geolocation.yml"
  ENVIRONMENT= File.dirname(__FILE__) + "/../../parameter/environment.yml"

  $staging = "production"
  $debugging = false
  attr_reader :saas_host,
              :saas_port


  #--------------------------------------------------------------------------------------------------------------------
  # MODULE FUNCTION
  #--------------------------------------------------------------------------------------------------------------------
  def get
    begin
      load_parameter()

      response = RestClient.get "http://#{@saas_host}:#{@saas_port}/?action=scrape"

    rescue Exception => e
      raise "download proxy list from saas #{@saas_host}:#{@saas_port}=> #{e.message}"

    else
      response.to_s # transforme l'object RestResponse en string pour enregistre dans un flow
    ensure


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
      @saas_host = parameters.saas_host
      @saas_port = parameters.saas_port
    end

  end

  module_function :get
  module_function :load_parameter


end