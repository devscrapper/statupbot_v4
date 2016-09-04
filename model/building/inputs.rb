#!/usr/bin/env ruby -w
# encoding: UTF-8
require_relative '../../lib/flow'

module Flowing
  class Inputs
    attr :logger

    DIR_TMP = [File.dirname(__FILE__), "..","..", "tmp"]

    def initialize
      @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)
    end

    def send_to_visitor_factory(inputflow)
      raise "inputflow not define" if inputflow.nil?

      @logger.an_event.debug inputflow.to_s

      raise "inputflow #{inputflow.absolute_path} not found" unless inputflow.exist?

      begin
        visit = inputflow.read
        @logger.an_event.debug "visit #{inputflow.basename} from engine bot #{visit}"

        inputflow.close
        visit_details = YAML::load(visit)
        browser = visit_details[:visitor][:browser][:name]
        browser_version = visit_details[:visitor][:browser][:version]
        @logger.an_event.debug "browser #{browser}"
        @logger.an_event.debug "browser_version #{browser_version}"

        tmp_visit = Flow.new(File.join($dir_tmp || DIR_TMP),
                             "#{browser}-#{browser_version}",
                             inputflow.label,
                             inputflow.date,
                             inputflow.vol,
                             inputflow.ext)
        tmp_visit.write(visit)
        tmp_visit.close
        @logger.an_event.info "copy input flow #{inputflow.basename} to #{tmp_visit.basename}"

        inputflow.delete
        @logger.an_event.info "delete input flow #{inputflow.basename}"
      rescue Exception => e

        @logger.an_event.error "visit #{inputflow.basename} not send to visitor factory : #{e.message}"
        raise   "visit #{inputflow.basename} not send to visitor factory"
      end
    end
  end
end
