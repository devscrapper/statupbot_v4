#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'yaml'
require 'rufus-scheduler'
require 'eventmachine'
require_relative '../lib/logging'
require_relative '../lib/parameter'
require_relative '../model/input_flow/connection'
require_relative '../lib/supervisor'


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
  listening_port = parameters.listening_port
  periodicity_supervision = parameters.periodicity_supervision
  $dir_archive = parameters.archive
  $dir_log = parameters.log
  $dir_tmp = parameters.tmp

  if listening_port.nil? or
      $debugging.nil? or
      $staging.nil? or
      periodicity_supervision.nil?
    $stderr << "some parameters not define" << "\n"
    exit(1)
  end
end

logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

logger.a_log.info "parameters of input flows server :"
logger.a_log.info "listening port : #{listening_port}"
logger.a_log.info "periodicity supervision : #{periodicity_supervision}"
logger.a_log.info "debugging : #{$debugging}"
logger.a_log.info "staging : #{$staging}"
logger.a_log.info "specific dir archive : #{$dir_archive}"
logger.a_log.info "specific dir log : #{$dir_log}"
logger.a_log.info "specific dir tmp : #{$dir_tmp}"

include Input_flows

#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------

begin
  EM.run {
    Signal.trap("INT") { EventMachine.stop }
    Signal.trap("TERM") { EventMachine.stop }

    # supervision
    Rufus::Scheduler.start_new.every periodicity_supervision do
      Supervisor.send_online(File.basename(__FILE__, '.rb'))
    end

    logger.a_log.info "input flows server is running"
    Supervisor.send_online(File.basename(__FILE__, '.rb'))
    EventMachine.start_server "0.0.0.0", listening_port, Connection, logger
  }
rescue Exception => e
  logger.a_log.fatal e
  Supervisor.send_failure(File.basename(__FILE__, '.rb'), e)
  logger.a_log.warn "input flow server restart"
  retry
end
logger.a_log.info "input flows server stopped"

