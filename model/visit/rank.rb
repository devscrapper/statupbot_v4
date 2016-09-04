require 'uuid'
require 'uri'
require_relative '../../lib/error'
require_relative '../../lib/logging'
require_relative '../page/link'

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
  # rank    | OUI    | NON    | Search   | NON         | NON         | b1((Cc){2,5}A){f-1}(Cc){2,5}DE{i-1}
  #--------------------------------------------------------------------------------------------------------------------
  class Rank < Visit

    attr_reader :around, #perimètre de recherche des link (domain, sous domain) pour les policy qui surfent sur le website : traffic |rank,
                :landing_link, #Object Pages::Link
                :durations # liste des durations par page

    def has_landing_link
      true
    end

    def initialize (visit_details, website_details)
      begin
        super(visit_details[:id],
              visit_details[:start_date_time],
              visit_details[:referrer])

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "many_hostname"}) if website_details[:many_hostname].nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "many_account_ga"}) if website_details[:many_account_ga].nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "durations"}) if visit_details[:durations].nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "landing link fqdn"}) if visit_details[:landing][:fqdn].nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "landing link path"}) if visit_details[:landing][:path].nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "landing link scheme"}) if visit_details[:landing][:scheme].nil?

        @@logger.an_event.debug "many_hostname #{website_details[:many_hostname]}"
        @@logger.an_event.debug "many_account_ga #{website_details[:many_account_ga]}"
        @@logger.an_event.debug "durations #{visit_details[:durations]}"
        @@logger.an_event.debug "landing scheme #{visit_details[:landing][:scheme]}"
        @@logger.an_event.debug "landing fqdn #{visit_details[:landing][:fqdn]}"
        @@logger.an_event.debug "landing page path #{visit_details[:landing][:path]}"

        @durations = visit_details[:durations]
        @around = (website_details[:many_hostname] == :true and website_details[:many_account_ga] == :no) ? :inside_hostname : :inside_fqdn
        @@logger.an_event.debug "around #{@around}"

        @landing_link = Pages::Link.new("#{visit_details[:landing][:scheme]}://#{visit_details[:landing][:fqdn]}#{visit_details[:landing][:path]}")
        @@logger.an_event.debug "landing link #{@landing_link}"

        i = @durations.size
        f = @referrer.durations.size

        @regexp ="b1((Cc){#{2},#{5}}A){#{f-1}}(Cc){#{2},#{5}}DE{#{i-1}}"

        @@logger.an_event.debug "i #{i}"
        @@logger.an_event.debug "f #{f}"

        @@logger.an_event.debug "@regexp #{@regexp}"

        @actions = /#{@regexp}/.random_example
        @@logger.an_event.debug "@actions #{@actions}"

      rescue Exception => e

        @@logger.an_event.fatal e.message
        raise e

      else
        @@logger.an_event.info "visit rank #{@id} has #{@actions.size} actions : #{@actions}"

      ensure

      end
    end

    def to_s
      "id : #{@id} \n" +
          "landing link : #{@landing_link} \n" +
          "regexp : #{@regexp} \n" +
          "actions : #{@actions} \n" +
          "referrer : #{@referrer} \n" +
          "durations : #{@durations} \n" +
          "start date time : #{@start_date_time} \n" +
          "around : #{@around} \n"
    end
  end

end