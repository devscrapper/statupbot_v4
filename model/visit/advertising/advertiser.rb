require_relative '../../../lib/error'
module Visits
  module Advertisings
    class Advertiser
      #----------------------------------------------------------------------------------------------------------------
      # constant
      #----------------------------------------------------------------------------------------------------------------

      MAX_DURATION = 50
      MIN_DURATION = 10

      #----------------------------------------------------------------------------------------------------------------
      # include class
      #----------------------------------------------------------------------------------------------------------------

      include Errors
      #----------------------------------------------------------------------------------------------------------------
      # variable class
      #----------------------------------------------------------------------------------------------------------------
      @@logger = nil
      #----------------------------------------------------------------------------------------------------------------
      # attribut
      #----------------------------------------------------------------------------------------------------------------
      attr :durations,
           :arounds

      #----------------------------------------------------------------------------------------------------------------
      # instance methods
      #----------------------------------------------------------------------------------------------------------------
      #----------------------------------------------------------------------------------------------------------------
      # initialize
      #----------------------------------------------------------------------------------------------------------------
      #----------------------------------------------------------------------------------------------------------------
      # input :
      #----------------------------------------------------------------------------------------------------------------
      def initialize(advertiser_details, domain=nil)
        @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

        @@logger.an_event.debug "durations #{advertiser_details[:durations]}"
        @@logger.an_event.debug "arounds #{advertiser_details[:arounds]}"

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "durations"}) if advertiser_details[:durations].nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "arounds"}) if advertiser_details[:arounds].nil?

        @durations = advertiser_details[:durations]
        @arounds = advertiser_details[:arounds]
        @domain = domain
      end


      def next_duration
        # si il y a un go_back sur un advertiser alors il manque une duration alors
        # il faut en generer une autre aléatoirement
        # car le nombre de duration est calculé par engine bot (doit conserver cela) car il calcule le nombre de page
        # il faut peut être faire calculer le nombre de page mais pas le tableau des durations
        @durations.empty? ?  Array.new(MAX_DURATION) { |i| i + MIN_DURATION }.sample : @durations.shift
      end

      def next_around
        # Le tableau des arounds est calculé par engine bot en fonction du nombre de page.
        # comment détermine les nomùbre de page où on reste sur advertiser et à partir de quelle page on part de l'advertiser
        # si on le calcule dans staupbot et qu'il y a des go_back ?????
        @arounds.empty? ? :inside_fqdn : @arounds.first
      end

      def to_s
        "durations : #{@durations}\n" +
            "arounds : #{@arounds}\n"
      end
    end
  end
end