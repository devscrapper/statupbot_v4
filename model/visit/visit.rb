# encoding: utf-8
require 'uuid'
require 'uri'
require_relative '../../lib/error'
require_relative '../../lib/logging'
require_relative 'advertising/advertising'
require_relative 'referrer/referrer'

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
  # traffic | NON    | NON    | Direct   | NON         | NON         | aE{i-1}
  # traffic | OUI    | OUI    | Referral | NON         | NON         | b((2+0A{1,q-1}CG{1,p-1})f){k}1A{f-1}I(G{1,p}e){x}DE{i-1}
  # traffic | OUI    | OUI    | Search   | NON         | NON         | b((2+0A{1,q-1}CG{1,p-1})f){k}1A{f-1}DE{i-1}
  #--------------------------------------------------------------------------------------------------------------------
  # rank    | OUI    | NON    | Search   | NON         | NON         | b1((Cc){2,5}A){f-1}(Cc){2,5}DE{i-1}
  #--------------------------------------------------------------------------------------------------------------------
  # adwords | OUI    | NON    | Search   | NON         | OUI         | b1((Cc){2,5}A){f-1}(Cc){2,5}FH{j-1}
  #--------------------------------------------------------------------------------------------------------------------
  # Transitions go to url     | id | Description
  #--------------------------------------------------------------------------------------------------------------------
  # go_to_start_landing       | a  | Accès à la page de démarrage du scénario qui est le landing page
  # go_to_start_search_engine | b  | Accès à la page de démarrage du scénario qui est un MDR
  # go_back 	                | c  | Accès à la page précédente.
  # go_to_landing	            | d  | Accès à la page d’atterrissage du site (referrer = direct)
  # go_to_referral	          | e  | Accès à la page du referral (referrer = referral)
  # go_to_search_engine 	    | f  | Accès à la page d’accueil du MDR (referrer = organic)
  #--------------------------------------------------------------------------------------------------------------------
  # Transitions submit form   | id | Description
  #--------------------------------------------------------------------------------------------------------------------
  # sb_search 	              | 0  | saisie des mots clés et soumission de la recherche vers le MDR.
  #                           |    | Les mots clé n’offrent qu’une liste des résultats dans laquelle n’apparait pas la
  #                           |    | landing_page.
  # sb_final_search 	        | 1  | saisie des mots clés et soumission de la recherche vers le MDR.
  #                           |    | Le mot clé permets d’offrir une liste des résultats dans laquelle apparait la
  #                           |    | landing_page.
  # sb_search 	              | 2  | saisie des mots clés et soumission de la recherche vers le MDR.
  #                           |    | Affichage des résultats et retour vers la saisie des mots clés
  # sb_captcha                | 3  | affichage du captcha et de la zone de saisie de la chaine calculée à partir
  #                           |    | du captcha.
  #--------------------------------------------------------------------------------------------------------------------
  # Transitions click link    | id | Description
  #--------------------------------------------------------------------------------------------------------------------
  # cl_on_next 	              | A  | click sur la page suivante des résultats de recherche
  # cl_on_previous 	          | B  | click sur la page précédente  des résultats de recherche
  # cl_on_result 	            | C  | click sur un résultat de recherche choisi au hasard qui n’est pas la page d’arrivée
  #                           |    | du site recherché.
  # cl_on_landing 	          | D  | click sur un résultat de recherche qui est la page d’arrivée du site recherché
  # cl_on_link_on_website 	  | E  | click sur un lien d’une page du site ciblé, choisit au hasard
  # cl_on_advert	            | F  | click sur un advert présent dans la page du site
  # cl_on_link_on_unknown	    | G  | click sur un lien d’une page d’un site inconnu, choisit au hasard
  # cl_on_link_on_advertiser  |	H  | click sur un lien d’une page d’un site inconnu, choisit au hasard
  # cl_on_referral            | I  | click sur un resultat de recherche qui est la page d’arrivée du site referral
  #--------------------------------------------------------------------------------------------------------------------

  class Visit
    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors
    include Advertisings
    include Referrers

    #----------------------------------------------------------------------------------------------------------------
    # Message exception
    #----------------------------------------------------------------------------------------------------------------

    ARGUMENT_UNDEFINE = 700
    VISIT_NOT_CREATE = 701
    VISIT_NOT_FOUND = 702
    VISIT_NOT_LOAD = 703

    #----------------------------------------------------------------------------------------------------------------
    # constant
    #----------------------------------------------------------------------------------------------------------------

    #----------------------------------------------------------------------------------------------------------------
    # variable de classe
    #----------------------------------------------------------------------------------------------------------------
    @@logger = nil
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------
    attr_reader :regexp #expression reguliere définissant le scénario d'exécution de la visit

    attr :actions, # liste des actions de la visite : construit à partir de la regexp
         :id, # id de la visit
         :referrer, # (none) | referral | organic
         :start_date_time # date et heure de demarrage de la visit



    #----------------------------------------------------------------------------------------------------------------
    # class methods
    #----------------------------------------------------------------------------------------------------------------
    def self.from_json(json_visit)
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      begin
        @@logger.an_event.debug "file_path #{file_path}"
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "json_visit"}) if json_visit.nil?

        @@logger.an_event.debug "visit_details #{json_visit}"

      rescue Exception => e


      else
        @@logger.an_event.info "visit file #{file_path} loaded"

      ensure

      end
    end

    def self.load(file_path)
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      begin
        @@logger.an_event.debug "file_path #{file_path}"
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "file_path"}) if file_path.nil?
        raise Error.new(VISIT_NOT_FOUND, :values => {:path => file_path}) unless File.exist?(file_path)

        visit_file = File.open(file_path, "r:BOM|UTF-8:-")
        details = YAML::load(visit_file.read)
        visit_file.close

        @@logger.an_event.debug "visit_details #{details}"

      rescue Exception => e
        @@logger.an_event.error e.message
        raise Error.new(VISIT_NOT_LOAD, :values => {:file => file_path}, :error => e)

      else
        @@logger.an_event.info "visit file #{file_path} loaded"
        [details[:visit], details[:website], details[:visitor]]

      ensure

      end
    end

    def self.build(visit_details, website_details)

      raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visit_details"}) if visit_details.nil? or visit_details.empty?
      raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "website_details"}) if website_details.nil? or website_details.empty?

      begin

        case visit_details[:type]
          when :traffic
            case visit_details[:advert][:advertising]
              when :none
                visit = Traffic.new(visit_details, website_details)

              else
                visit = Advert.new(visit_details, website_details)

            end

          when :rank
            visit = Rank.new(visit_details, website_details)

          when :seaattack
            visit = Seaattack.new(visit_details, website_details)

          else

        end

      rescue Exception => e
        @@logger.an_event.error e.message
        raise Error.new(VISIT_NOT_CREATE, :values => {:id => visit_details[:id]}, :error => e)

      else
        @@logger.an_event.info "visit #{visit.id} has #{visit.actions.size} actions : #{visit.actions}"
        @@logger.an_event.debug "visit #{visit.to_s}"
        visit

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # instance methods
    #----------------------------------------------------------------------------------------------------------------
    def script
      @actions.split("")
    end

    #----------------------------------------------------------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------------------------------------------------------
    # crée une visite :
    # - crée le visitor, le referer, les pages
    #----------------------------------------------------------------------------------------------------------------
    # input :
    # une visite qui est une ligne du flow : published-visits_label_date_hour.json
    # {"id_visit":"1321","start_date_time":"2013-04-21 00:13:00 +0200","account_ga":"pppppppppppppp","return_visitor":"true","browser":"Internet Explorer","browser_version":"8.0","operating_system":"Windows","operating_system_version":"XP","flash_version":"11.6 r602","java_enabled":"Yes","screens_colors":"32-bit","screen_resolution":"1024x768","referral_path":"(not set)","source":"google","medium":"organic","keyword":"(not provided)","pages":[{"id_uri":"856","delay_from_start":"33","hostname":"centre-aude.epilation-laser-definitive.info","page_path":"/ville-11-castelnaudary.htm","title":"Centre d'épilation laser CASTELNAUDARY centres de remise en forme CASTELNAUDARY"}]}
    #----------------------------------------------------------------------------------------------------------------
    def initialize(id_visit, start_date_time, referrer)
      begin

        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "id"}) if id_visit.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "start_date_time"}) if start_date_time.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "referrer"}) if referrer.nil?

        @@logger.an_event.debug "id_visit #{id_visit}"
        @@logger.an_event.debug "start_date_time #{start_date_time}"
        @@logger.an_event.debug "referrer #{referrer}"

        @id = id_visit
        @start_date_time = start_date_time

        @referrer = Referrer.build(referrer)

      rescue Exception => e
        @@logger.an_event.fatal e.message
        raise e.message

      else
        @@logger.an_event.debug "visit #{@id} initialize"

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # next_duration
    #----------------------------------------------------------------------------------------------------------------
    # input : RAS
    # output : la duration suivante de la liste
    #----------------------------------------------------------------------------------------------------------------
    def next_duration
      @durations.shift
    end


  end
end


require_relative 'traffic'
require_relative 'advert'
require_relative 'rank'
require_relative 'sea_attack'