module Visits
  module Referrers

    class Referrer
      #----------------------------------------------------------------------------------------------------------
      # Source : chaque site référent a une origine ou source. Les sources possibles sont les suivantes :
      #    "Google" (nom d'un moteur de recherche),
      #    "facebook.com" (nom d'un site référent),
      #    "spring_newsletter" (nom de l'une de vos newsletters) et
      #    "directe" (visites réalisées par des internautes ayant saisi votre URL directement dans leur navigateur ou ayant ajouté votre site à leurs favoris).
      #----------------------------------------------------------------------------------------------------------
      # Support : chaque site référent est également associé à un support. Les supports possibles sont les suivants :
      #      "naturel" (recherche gratuite),
      #      "cpc" (coût par clic, donc les liens commerciaux),
      #      "site référent" (site référent),
      #      "e-mail" (nom d'un support personnalisé créé par vos soins),
      #      "aucun" (le support correspondant aux visites directes).
      #----------------------------------------------------------------------------------------------------------
      # Mot clé : les mots clés que recherchent les visiteurs sont généralement enregistrés dans le cas des sites référents de moteur de recherche.
      #  Il en est ainsi pour les recherches naturelles comme les liens commerciaux.
      #  Sachez, toutefois, qu'en cas d'utilisation d'une recherche SSL (par exemple,
      #  si l'utilisateur s'est connecté à un compte Google ou en cas d'utilisation de la barre de recherche Firefox), le mot clé prend la valeur (non fournie).
      #----------------------------------------------------------------------------------------------------------
      # Campagne désigne la campagne AdWords référente ou une campagne personnalisée dont vous êtes l'auteur.
      #----------------------------------------------------------------------------------------------------------
      # Contenu identifie un lien spécifique ou un élément de contenu au sein d'une campagne personnalisée.
      #   Par exemple, si vous disposez de deux liens d'incitation à l'action au sein d'un même e-mail,
      #   vous pouvez utiliser différentes valeurs de contenu pour les différencier, de façon à pouvoir identifier la version la plus efficace.
      #   Vous pouvez tirer parti des campagnes personnalisées pour inclure des balises dans les liens.
      # Vous pourrez ainsi utiliser vos propres valeurs personnalisées pour les paramètres "Campagne", "Support", "Source" et "Mot clé".
      #----------------------------------------------------------------------------------------------------------
      #             Referal         Campaign    Source                Medium      Keyword
      # NoReferer  (not set)        (not set)   (direct)              (none)      (not set)
      # Search     (not set)        (not set)    google*              organic     {key words}
      # Referral   {referal path}   (not set)   {referral hostname}   referral    (not set)
      #------------------------------------------------------------------------------------------------------------
      #             UTMCCT            UTMCCN    UTMCSR                UTMCMD      UTMCTR
      #------------------------------------------------------------------------------------------------------------
      #  * dans un premier temps on ne realise des recherches que par le portail google.
      # Pour cela la sélection est réalisé lors de la recuperation des données de GA
      #
      #------------------------------------------------------------------------------------------------------------
      #----------------------------------------------------------------------------------------------------------------
      # include class
      #----------------------------------------------------------------------------------------------------------------
      include Errors

      #----------------------------------------------------------------------------------------------------------------
      # Message exception
      #----------------------------------------------------------------------------------------------------------------

      ARGUMENT_UNDEFINE = 800
      REFERRER_NOT_CREATE = 801
      MEDIUM_UNKNOWN = 802
      #----------------------------------------------------------------------------------------------------------------
      # variable de class
      #----------------------------------------------------------------------------------------------------------------
      @@logger = nil
      #----------------------------------------------------------------------------------------------------------------
      # attribut
      #----------------------------------------------------------------------------------------------------------------


      #----------------------------------------------------------------------------------------------------------------
      # class methods
      #----------------------------------------------------------------------------------------------------------------

      #----------------------------------------------------------------------------------------------------------------
      # instance methods
      #----------------------------------------------------------------------------------------------------------------
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
      #["source", "(direct)"]
      #["medium", "(none)"]
      #["keyword", "(not set)"]
      def self.build(referer_details)
        @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

        begin
          case referer_details[:medium]
            when :none
              return Direct.new

            when :organic
              return Search.new(referer_details)

            when :referral
              return Referral.new(referer_details)

            else
              raise Error.new(MEDIUM_UNKNOWN, :values => {:medium => referer_details[:medium]})
          end

        rescue Exception => e
          @@logger.an_event.error e.message
          raise Error.new(REFERRER_NOT_CREATE, :error => e)


        else
          @@logger.an_event.debug "referrer build"

        ensure


        end
      end
      def to_s
        "#{self.class.name}\n"
      end
    end
  end
end

require_relative 'direct'
require_relative 'referral'
require_relative 'search'

