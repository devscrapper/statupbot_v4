require 'uuid'
require 'uri'
require_relative '../../lib/error'
require_relative '../../lib/logging'
require_relative 'advertising/advertising'


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
  # q : nombre de sites visités par page de resultats du MDR avant de passer à la visite ; calculé aléaoirement entre [2-3]
  #--------------------------------------------------------------------------------------------------------------------
  # type    | random | random | referrer | advertising | advertising | expression reguliere
  #         | search | surf   |          | on website  | on results  |
  #--------------------------------------------------------------------------------------------------------------------
  # advert  | NON    | NON    | Direct   | OUI         | NON         | bdE{i-1}FH{j-1}
  # advert  | OUI    | OUI    | Referral | OUI         | NON         | bf(00{k’’}(c+f+G{p}f)){k’}1A{f-1}eDE{i-1}FH{j-1}
  # advert  | OUI    | OUI    | Search   | OUI         | NON         | bf(00{k’’}(c+f+G{p}f)){k’}1A{f-1}DE{i-1}FH{j-1}
  #--------------------------------------------------------------------------------------------------------------------

  class Advert < Traffic

    attr_reader :advertising

    def initialize(visit_details, website_details)

      begin
        super(visit_details[:id],
              visit_details[:start_date_time],
              visit_details[:referrer])
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "advert"}) if visit_details[:advert].nil?

        @@logger.an_event.debug "advert #{visit_details[:advert]}"

        @advertising = Advertising.build(visit_details[:advert])
        j = @advertising.advertiser.durations.size
        @@logger.an_event.debug "count page advertiser (j) : #{j}"

        @regexp += "FH{#{j-1}}"
        @actions = /#{@regexp}/.random_example

        @@logger.an_event.debug "@actions #{@actions}"

      rescue Exception => e

        @@logger.an_event.fatal e.message
        raise e

      else
        @@logger.an_event.debug "visit advert #{@id} initialize"

      ensure

      end
    end


    def to_s
      super.to_s +
          "advertising : #{@advertising}\n"

    end

  end
end