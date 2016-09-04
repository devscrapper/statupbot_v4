require_relative '../../lib/flow'
require_relative '../../lib/error'
require_relative '../../lib/proxy'
require_relative 'geolocation'
require 'eventmachine'


module Geolocations
  #----------------------------------------------------------------------------------------------------------------
  # include class
  #----------------------------------------------------------------------------------------------------------------
  include Errors
  #----------------------------------------------------------------------------------------------------------------
  # Message exception
  #----------------------------------------------------------------------------------------------------------------

  ARGUMENT_UNDEFINE = 1300
  NONE_GEOLOCATION = 1301
  GEO_BAD_PROPERTIES = 1302
  GEO_NOT_AVAILABLE = 1303
  GEO_FILE_NOT_FOUND = 1304
  GEO_NONE_COMPLIANT = 1305
  GEO_NOT_VALID = 1306
  GEO_NOT_RETRIEVE = 1307

  class GeolocationFactory
    include Errors

    @@logger = nil

    EOFLINE ="\n"
    attr :geolocations,
         :geolocations_file,
         :download_proxy

    DIR_TMP = [File.dirname(__FILE__), "..", "..", "tmp"]

    def self.logger=(logger)
      @@logger=logger
    end


    # si utilisation du service de recuperation de la liste de proxy alors geo_flow=nil (prod)
    # si utilisation d'un flow construit par visitor_factory alors geo_flow <> nil (test)
    def initialize(geo_flow=nil)
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
        delay_periodic_load_geolocations = parameters.delay_periodic_load_geolocations

        if delay_periodic_load_geolocations.nil? or
            $debugging.nil? or
            $staging.nil?
          $stderr << "some parameters not define\n" << "\n"
          exit(1)
        end
      end

      @geolocations_file = geo_flow

      begin
        @geolocations = []

        #premier chargement pour eviter d'avoir des erreur, car l'EM::periodic déclenche dans le delay et pas à zero
        download_proxies if geo_flow.nil?
        load

        EM.add_periodic_timer(delay_periodic_load_geolocations * 60) do
          download_proxies if geo_flow.nil?
          load
        end

      rescue Exception => e
        @@logger.an_event.error e.message
        retry

      else
        @@logger.an_event.debug "geolocations factory create"

      ensure


      end
    end

    def get(criteria={})

      geo_count = @geolocations.size
      i = 1

      begin

        geo = select_one
        raise Error.new(GEO_NOT_VALID, :values => {:country => criteria[:country], :protocol => criteria[:protocol]}) if (!criteria[:country].nil? and criteria[:country].downcase != geo.country.downcase) or
            (!criteria[:protocol].nil? and criteria[:protocol].downcase != geo.protocol.downcase)

      rescue Exception => e

        case e.code
          when NONE_GEOLOCATION
            @@logger.an_event.error e.message
            raise e
          when GEO_NOT_VALID
            if i < geo_count
              i += 1
              @@logger.an_event.warn e.message
              retry
            else
              @@logger.an_event.error e.message
              raise Error.new(GEO_NONE_COMPLIANT)
            end
        end
      else
        #on sort de la boucle :
        # soit on a trouve une geo qui repond aux criteres passés si il y en a
        # soit parce que on les a passé tous les geo et il n'y a aucun geolocation qui satisfont les critères => exception
        @@logger.an_event.debug "geolocation find : #{geo.to_s}"
        return geo
      ensure

      end
    end
    def to_s
      @geolocations.join("\n")

    end
    private

    def clear
      #@geolocations.each { |geo| @geolocations.delete(geo) }
      @geolocations = []
    end


    # retourne un objet geolocation ou
    # retourne une exception si plus aucun geolocation dans la factory
    # retourne une exception si plus aucun geolocation ne satisfait les criteres


    #recuperation de la liste de proxy du seveur saas
    # sauvergarde dans un flow horaire
    # si erreur utilisation du précédent
    # si pas erreur archivage du précédent
    def download_proxies
      now = Time.now
      vol = now.hour
      date = now.strftime("%Y-%m-%d")
      @geolocations_file = Flow.new(File.join($dir_tmp || DIR_TMP),
                                    "geolocations", 
                                    $staging, 
                                    date, 
                                    vol, 
                                    '.txt')

      begin
        proxy_list = Proxy.get

      rescue Exception => e
        raise Error.new(GEO_NOT_RETRIEVE, :error => e)

      else
        @geolocations_file.write(proxy_list)
        @geolocations_file.close
        @geolocations_file.archive_previous

      ensure
      end


    end

    def load
      clear

      @geolocations_file.foreach(EOFLINE) { |geo_line|

        begin

          @geolocations << Geolocation.new(geo_line)

        rescue Exception => e

          @@logger.an_event.warn e.message

        end
      }

      @geolocations_file.close

      @@logger.an_event.info "#{@geolocations.size} geolocation(s) loaded"

    end


    # retourne un objet geolocation ou
    # retourne une exception si plus aucun geolocation dans la factory
    def select_one
      geo = nil #ne pas supprmer sinon geo n'est pas connu, car initialiser dans le mutex

      begin


        raise Error.new(NONE_GEOLOCATION) if @geolocations.size == 0

        Mutex.new.synchronize {
          geo = @geolocations.shift
          # on range la gelocation pour conserver une file tournante.
          @geolocations << geo
          @@logger.an_event.debug "shift : #{geo}"
        }
        geo.available?

      rescue Error => e

        case e.code
          when NONE_GEOLOCATION
            @@logger.an_event.warn e.message
            raise e

          when GEO_NOT_AVAILABLE
            @@logger.an_event.warn e.message
            retry

          else
            @@logger.an_event.error e.message
        end
      rescue Exception => e
        @@logger.an_event.error e.message
      else

        @@logger.an_event.debug "geolocation #{geo.to_s} selected"
        return geo

      ensure


      end

    end


  end
end