require_relative '../../../lib/error'
require_relative '../../engine_search/engine_search'
module Visits
  #----------------------------------------------------------------------------------------------------------------
  # Calcul des fakes keyword
  # c'est une combinaison des mot du keyword.
  # en fonction du nombre de mots du keyword on s�lectionne certaines combinaison
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

    class Search < Referrer

      #----------------------------------------------------------------------------------------------------------------
      # include class
      #----------------------------------------------------------------------------------------------------------------
      include EngineSearches
      include Errors

      #----------------------------------------------------------------------------------------------------------------
      # attribut
      #----------------------------------------------------------------------------------------------------------------
      attr :keywords, # String : keyword dont la recherche aboutie forc�ment � la pr�sence d'un landing link dans les results
           :fake_keywords,
           # calculer par une combinaison des mots contenus dans @keywords
           :durations,
           :random_search_min,
           :random_search_max,
           :random_surf_min,
           :random_surf_max

      #----------------------------------------------------------------------------------------------------------------
      # class methods
      #----------------------------------------------------------------------------------------------------------------
      def initialize(referer_details)
        begin
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "keyword"}) if referer_details[:keyword].size == 0
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "durations"}) if referer_details[:durations].size == 0
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_search.min"}) if referer_details[:random_search][:min].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_search.max"}) if referer_details[:random_search][:max].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_surf.max"}) if referer_details[:random_surf][:max].nil?
          raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "random_surf.min"}) if referer_details[:random_surf][:min].nil?

          @keywords = referer_details[:keyword]

          arr = @keywords.split (" ")
          @fake_keywords = []
          (@keywords.size - 1).times { |i| @fake_keywords += arr.combination(i + 1).to_a }


          @durations = referer_details[:durations]
          @random_search_min = referer_details[:random_search][:min]
          @random_search_max =referer_details[:random_search][:max]
          @random_surf_min =referer_details[:random_surf][:min]
          @random_surf_max = referer_details[:random_surf][:max]

        rescue Exception => e
          @@logger.an_event.error e.message
          raise Error.new(REFERRER_NOT_CREATE, :error => e)

        else
          @@logger.an_event.debug "referrer #{self.class} create"

        ensure

        end
      end

      #retourne tj une string contenant les mots cl�, m�me si engine bot a fourni un tableau de mot cl�
      def keywords
        #TODO � supprimer qd on sera sur qu'il n'ya plus de tableau
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
            "keywords : #{@keywords} \n" +
            "fake_keywords : #{@fake_keywords} \n" +
            "durations : #{@durations} \n" +
            "random_search_min : #{@random_search_min} \n" +
            "random_search_max : #{@random_search_max} \n" +
            "random_surf_min : #{@random_surf_min} \n" +
            "random_surf_max : #{@random_surf_max} \n"

      end

    end
  end
end