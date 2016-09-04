require 'uri'
require_relative '../../../lib/error'
module Visits
  #----------------------------------------------------------------------------------------------------------------
  # Calcul des fakes keyword
  # c'est une combinaison des mot du keyword.
  # en fonction du nombre de mots du keyword on sélectionne certaines combinaison
  # C(1,5) = 5, C(2,5) = 10, C(3,5) = 10, C(4,5) = 5, C(5,5) = 1
  # C(1,4) = 4, C(2,4) = 6, C(3,4) = 4, C(4,4) = 1
  # C(1,3) = 3, C(2,3) = 3, C(3,3) = 1
  # C(1,2) = 2, C(2,2) = 1
  # C(1,1) = 1
  # on supprime les combinaisons C(i,i) = 1 car le nombre de mot max est utilisé pour retrouver dans les resultats
  # le landing
  # pour eviter un trop grand nombre de recherche qd le nombre de mot dans keyword est grand (max 5) on sélectionne
  # les combinaisons comme suit en répartissant les keyword entre la recherche sans click sur un lien des resultats
  # et la recherche avec click sur un lien de résultat
  # si nb de mot de keyword = 1 alors pas de recherche sans click et une recherche avec click
  # si nb de mot de keyword = 2 alors pas de recherche sans click et 2 recherches avec click avec combinaison de 1 mot par keyword
  # si nb de mot de keyword = 3 alors
  #                                   Random(1,3) de recherche sans click avec combinaison de 1 mot par keyword
  #                                   Random(1,3) de recherche avec click avec combinaison de 2 mots par keyword
  # si nb de mot de keyword = 4 alors
  #                                   Random(1,6) de recherche sans click avec combinaison de 2 mots par keyword
  #                                   Random(1,4) de recherche avec click avec combinaison de 3 mots par keyword
  # si nb de mot de keyword = 5 alors
  #                                   Random(1,10) de recherche sans click avec combinaison de 3 mots par keyword
  #                                   Random(1,5) de recherche avec click avec combinaison de 4 mots par keyword
  #----------------------------------------------------------------------------------------------------------------
  module Referrers

    class Referral < Referrer

      attr :page_url, # Objet URI de la page referral contenant le landing_link
           :durations, # for keywords to find referral
           :duration, #for referral
           :keywords, # String : keyword dont la recherche aboutie forcément la présence d'une url pointant vers le site referral dans les results
           :fake_keywords,
           :referral_uri_search # string contenant une url pointant vers le site referral dans les results peut être egal à page_uri.to_s
            # si referral_uri_search == page_uri.to_s alors selectionne directement le landing link sur la page du referral.
            # si referral_uri_search != page_uri.to_s alors surf qq page sur le site referral avant de se debrancher vers la page du referral qui contient le landing link(page_url)

      include Errors

      def initialize(referer_details)


        begin

          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "referral_path"}) if referer_details[:referral_path].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "duration"}) if referer_details[:duration].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "referral_hostname"}) if referer_details[:referral_hostname].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "keyword"}) if referer_details[:keyword].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_search.min"}) if referer_details[:random_search][:min].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_search.max"}) if referer_details[:random_search][:max].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_surf.max"}) if referer_details[:random_surf][:max].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_surf.min"}) if referer_details[:random_surf][:min].nil?


          @keywords = referer_details[:keyword]

          arr = @keywords.split (" ")

          @fake_keywords = []
          (@keywords.size - 1).times { |i|
            @fake_keywords += arr.combination(i + 1).to_a
          }

          @random_search_min = referer_details[:random_search][:min]
          @random_search_max =referer_details[:random_search][:max]
          @random_surf_min =referer_details[:random_surf][:min]
          @random_surf_max = referer_details[:random_surf][:max]
          @page_url = referer_details[:referral_hostname].start_with?("http:") ?
              URI.join(referer_details[:referral_hostname], referer_details[:referral_path]) :
              URI.join("http://#{referer_details[:referral_hostname]}", referer_details[:referral_path])

          @duration = referer_details[:duration]
          @durations = referer_details[:durations]
          @referral_uri_search =  Pages::Link.new(referer_details[:referral_uri_search])

        rescue Exception => e
          @@logger.an_event.error e.message
          raise Error.new(REFERRER_NOT_CREATE, :error => e)

        else
          @@logger.an_event.debug "referral create"

        ensure

        end
      end

      #retourne tj une string contenant les mots cl?, m?me si engine bot a fourni un tableau de mot cl?
      def keywords
        #TODO ? supprimer qd on sera sur qu'il n'ya plus de tableau
        @keywords.is_a?(Array) ? @keywords.sample : @keywords
      end

      def next_keyword
        @fake_keywords.sample.join(" ")
      end


      def search_duration
        Random.new.rand(@random_search_min .. @random_search_max)
      end

      def surf_duration
        Random.new.rand(@random_surf_min .. @random_surf_max)
      end

      def to_s
        super.to_s +
            "page url : #{@page_url} \n" +
            "durations : #{@durations} \n" +
            "duration : #{@duration} \n" +
            "referral_uri_search : #{@referral_uri_search} \n" +
            "keywords : #{@keywords} \n" +
            "fake_keywords : #{@fake_keywords} \n" +
            "random_search_min : #{@random_search_min} \n" +
            "random_search_max : #{@random_search_max} \n" +
            "random_surf_min : #{@random_surf_min} \n" +
            "random_surf_max : #{@random_surf_max} \n"


      end
    end
  end
end
