#encoding:UTF-8
require 'json'
require 'yaml'
require_relative '../../lib/error'
require 'em-http-server'
require 'em/deferrable'
require_relative '../../lib/flow'
require_relative '../../lib/monitoring'

module Input_flows
  class Connection < EM::HttpServer::Server
    include Errors
    ARGUMENT_NOT_DEFINE = 1800
    ACTION_UNKNOWN = 1801
    ACTION_NOT_EXECUTE = 1802
    RESSOURCE_NOT_MANAGE = 1803
    VERBE_HTTP_NOT_MANAGE = 1804
    DIR_TMP = [File.dirname(__FILE__), "..", "..", "tmp"]


    attr :logger


    def initialize(logger)
      super
      @logger = logger
    end

    def process_http_request
      #------------------------------------------------------------------------------------------------------------------
      # REST : uri disponibles
      # GET
      # http://localhost:9201/input_flows/online
      # http://localhost:9201/visits/all
      # http://localhost:9201/geolocations/all
      # POST
      # http://localhost:9201/visit/new  payload = { ... }
      # http://localhost:9201/geolocations/'filename'  payload = { ... }
      # PATCH
      #
      # DELETE
      #------------------------------------------------------------------------------------------------------------------


      #------------------------------------------------------------------------------------------------------------------
      # Check input data
      #------------------------------------------------------------------------------------------------------------------
      action = proc {
        begin
          nul, ress_type, ress_id = @http_request_uri.split("/")

          raise Errors::Error.new(ARGUMENT_NOT_DEFINE, :values => {:variable => "ress_type"}) if ress_type.nil? or ress_type.empty?
          raise Errors::Error.new(ARGUMENT_NOT_DEFINE, :values => {:variable => "ress_id"}) if ress_id.nil? or ress_id.empty?

          @logger.an_event.debug "@http_request_method : #{@http_request_method}"

          @logger.an_event.debug "ress_type : #{ress_type}"
          @logger.an_event.debug "ress_id : #{ress_id}"
          case @http_request_method
            #--------------------------------------------------------------------------------------------------------------
            # GET
            #--------------------------------------------------------------------------------------------------------------
            when "GET"

            #--------------------------------------------------------------------------------------------------------------
            # POST
            #--------------------------------------------------------------------------------------------------------------
            when "POST"
              #@http_content = JSON.parse(@http_content, {:symbolize_names => true})
              @logger.an_event.debug "@http_content : #{@http_content}"

              case ress_type
                when "visits"
                  visit_flow = send_to_visitor_factory(@http_content)
                  @logger.an_event.info "save visit flow #{visit_flow.basename}"
                else
                  raise Errors::Error.new(RESSOURCE_NOT_MANAGE, :values => {:ressource => ress_type})

              end

            else
              raise Errors::Error.new(VERBE_HTTP_NOT_MANAGE, :values => {:verb => @http_request_method})
          end

        rescue Error, Exception => e
          @logger.an_event.fatal e.message
          results = e

        else
          results = visit_flow.basename # as usual, the last expression evaluated in the block will be the return value.

        ensure

        end
      }

      callback = proc { |results|
        # do something with result here, such as send it back to a network client.

        response = EM::DelegatedHttpResponse.new(self)

        if results.is_a?(Error)
          case results.code

            when ARGUMENT_NOT_DEFINE
              response.status = 400

            when RESSOURCE_NOT_MANAGE
              response.status = 404

            when VERBE_HTTP_NOT_MANAGE
              response.status = 405

            else
              response.status = 501

          end

        elsif results.is_a?(Exception)
          response.status = 500

        else
          response.status = 200
        end

        if @http[:accept].include?("text/html") and response.status == 200
          # formatage des données en html si aucune erreur et si accès avec un navigateur
          response.content_type 'text/html'
          response.content = results
        else
          response.content_type 'application/json'
          response.content = results.to_json

        end

        response.send_response
        close_connection_after_writing
      }

      if $staging == "development" #en dev tout ext exécuté hors thread pour pouvoir debugger
        begin
          results = action.call

        rescue Exception => e
          @logger.an_event.error e.message
          callback.call(e)
        else
          callback.call(results)

        end
      else # en test & production tout est executé dans un thread
        EM.defer(action, callback)

      end
    end

    def http_request_errback e
      # printing the whole exception
      puts e.inspect
    end


    private

    def send_to_visitor_factory(visit_details)

      visit_details = YAML::load(visit_details)
      date = [visit_details[:visit][:start_date_time].year,
          visit_details[:visit][:start_date_time].month,
          visit_details[:visit][:start_date_time].day,
          visit_details[:visit][:start_date_time].hour,
          visit_details[:visit][:start_date_time].min,
          visit_details[:visit][:start_date_time].sec].join('-')

      @logger.an_event.debug "browser #{visit_details[:visitor][:browser][:name]}"
      @logger.an_event.debug "browser_version #{visit_details[:visitor][:browser][:version]}"
      @logger.an_event.debug "website_label #{visit_details[:website][:label]}"
      @logger.an_event.debug "date #{visit_details[:visit][:start_date_time]}"
      tmp_visit = Flow.new(File.join($dir_tmp || DIR_TMP),
                           "#{visit_details[:visitor][:browser][:name]}-#{visit_details[:visitor][:browser][:version]}",
                           visit_details[:website][:label],
                           date,
                           1, ".yml")
      tmp_visit.write(visit_details.to_yaml)
      tmp_visit.close

      begin
         Monitoring.change_state_visit(visit_details[:visit][:id], Monitoring::PUBLISHED)

       rescue Exception => e
         @logger.an_event.warn e.message

      end

      tmp_visit
    end


  end


end