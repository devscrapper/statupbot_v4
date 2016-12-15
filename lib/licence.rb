# encoding: utf-8
require_relative 'parameter'
require 'rest-client'


module Licence
  #--------------------------------------------------------------------------------------------------------------------
  # INIT
  #--------------------------------------------------------------------------------------------------------------------
  ENVIRONMENT= File.dirname(__FILE__) + "/../../parameter/environment.yml"

  $staging = "production"
  $debugging = false
  attr_reader :license_server_host,
              :license_server_port


  #--------------------------------------------------------------------------------------------------------------------
  # MODULE FUNCTION
  #--------------------------------------------------------------------------------------------------------------------
  def get
    begin
      load_parameter()

      response = RestClient.get "http://#{@license_server_host}:#{@license_server_port}/licenses/d"

    rescue Exception => e
      raise "download licence from saas rails #{@license_server_host}:#{@license_server_port}=> #{e.message}"

    else
      response

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
      @license_server_host = parameters.license_server_host
      @license_server_port = parameters.license_server_port
    end

  end

  module_function :get
  module_function :load_parameter


end