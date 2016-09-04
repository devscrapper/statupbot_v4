require 'uuid'
require 'uri'
require_relative '../../lib/error'
require_relative '../../lib/logging'


module Visits
  #--------------------------------------------------------------------------------------------------------------------
  # Liste des expressions regulieres en fonction du type de visite (:traffic, :advert, :rank)
  # Type visit :
  # :adword : permet de générer du revenu adword à partir d’un site
  # :Traffic : permet de générer du traffic sur un site
  # :Rank : permet de diminuer la position d’un site dans les résultats de recherche google.
  #
  # Random  search : réalise une recherche aléatoire avec un ensemble de mots clé au moyen d’un moteur de recherche
  # Random  surf : réalise une navigation aléatoire sur un site non maitrisé.
  #--------------------------------------------------------------------------------------------------------------------
  # variables utilisées dans les expressions regulieres :
  # i : nombre de pages de la visite ; issu du fichier yaml de la visite
  # j : nombre de pages visitée lors du random surf chez l'advertiser ; issu du fichier yaml de la visite
  # k : cardinalité de l'ensemble des sous chaines du mot clé final (permet atterrissage sur landing page) ; le mot clé
  # final est issu du fichier yaml de la visite ; l'ensemble des sous-chaine est calculé ; la répartition entre k' et k''
  # est aléatoire.
  #     k = k'' + k'
  # p : nombre de pages visitées lors du random surf qui précède la visite ; calculé aléaoirement entre [1-3]
  # f : index de la page de resultats du MDR dans laquelle on trouve le lien de la landing page. ; issu du fichier yaml
  # de la visite
  # q : nombre de sites visités par page de resultats du MDR avant de passer à la visite ; calculé aléaoirement entre [2-5]
  #--------------------------------------------------------------------------------------------------------------------
  # type    | random | random | referrer | advertising | advertising | expression reguliere
  #         | search | surf   |          | on website  | on results  |
  #--------------------------------------------------------------------------------------------------------------------
  # adwords | OUI    | NON    | Search   | NON         | OUI         | b1((Cc){2,5}A){f-1}(Cc){2,5}FH{j-1}
  #--------------------------------------------------------------------------------------------------------------------
  class Seaattack < Visit

    attr_reader :advertising

    def has_landing_link
      false
    end

    def initialize (visit_details, website_details)
      begin
        super(visit_details[:id],
              visit_details[:start_date_time],
              visit_details[:referrer])

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "advert"}) if visit_details[:advert].nil?

        @@logger.an_event.debug "advert #{visit_details[:advert]}"

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "f"}) if @referrer.durations.size == 0

        @advertising = Advertising.build(visit_details[:advert])

       raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "j"}) if @advertising.advertiser.durations.size == 0


        f = @referrer.durations.size

        j = @advertising.advertiser.durations.size

        @regexp ="b1((Cc){#{2},#{5}}A){#{f-1}}(Cc){#{2},#{5}}"

        @regexp += "FH{#{j-1}}"

        @@logger.an_event.debug "f #{f}"
        @@logger.an_event.debug "j #{j}"
        @@logger.an_event.debug "@regexp #{@regexp}"

        @actions = /#{@regexp}/.random_example
        @@logger.an_event.debug "@actions #{@actions}"

      rescue Exception => e

        @@logger.an_event.fatal e.message
        raise e

      else
        @@logger.an_event.info "visit seaattack #{@id} has #{@actions.size} actions : #{@actions}"

      ensure

      end
    end
  end

end