require 'randexp'

class Randgen
  SEPARATOR = ";"
  GO_TO_START_PAGE = "go_to_start_page#{SEPARATOR}"
  GO_TO_LANDING= "go_to_landing#{SEPARATOR}"
  CL_ON_LINK = "cl_on_link#{SEPARATOR}"

  def self.go_to_start_page(options = {})
    GO_TO_START_PAGE
  end

  def self.go_to_landing(options = {})
    GO_TO_LANDING
  end

  def self.cl_on_link(options = {})
    CL_ON_LINK
  end

  def self.E(options = {})
    "E"
  end
end

module Visitors
  #--------------------------------------------------------------------------------------------------------------------
  # Script transforme une expression regulière en actions Visitor
  #
  # Liste des actions Visitor disponibles
  #--------------------------------------------------------------------------------------------------------------------
  # id | action                   | description
  #----|---------------------------------------------------------------------------------------------------------------
  # a  | go_to_page               | Accès à une url
  # b  | go_to_start_page         | Accès à la page de démarrage du scénario
  # c  | go_back                  | Accès à la page précédente.
  # d  | go_to_landing            | Accès à la page d’atterrissage du site (referrer = direct)
  # e  | go_to_referral           | Accès à la page du referral (referrer = referral)
  # f  | go_to_search_engine      | Accès à la page d’accueil du MDR (referrer = organic)
  # A  | cl_on_next               | click sur la page suivante des résultats de recherche
  # B  | cl_on_previous           | click sur la page précédente des résultats de recherche
  # C  | cl_on_result             | click sur un résultat de recherche choisi au hasard qui n’est pas la page d’arrivée
  #                                 du site recherché.
  # D  | cl_on_landing            | click sur un résultat de recherche qui est la page d’arrivée du site recherché
  # E  | cl_on_link               | click sur un lien d’une page d’un site, choisit au hasard
  # F  | cl_on_advert             | click sur un advert présent dans la page du site
  # 0  | sb_search                | saisie des mots clés et soumission de la recherche vers le MDR. Les mots clé
  #                                 n’offrent qu’une liste des résultats dans laquelle n’apparait pas la landing_page.
  # 1  | sb_final_search          | saisie des mots clés et soumission de la recherche vers le MDR. Le mot clé permet
  #                                 d’offrir une liste des résultats dans laquelle apparait la landing_page
  # 2  | sb_search                | saisie des mots clés et soumission de la recherche vers le MDR. Contrairement à
  #                                 0 & 1 pas de surf sur les resultats obtenus.
  # 3  | sb_captcha               | saisie du mot affiché dans le captcha présenter par le MDR
  #--------------------------------------------------------------------------------------------------------------------

  SEPARATOR = ";"



  class Script

    #--------------------------------------------------------------------------------------------------------------------
    # actions
    #--------------------------------------------------------------------------------------------------------------------
    # input : un expression reguliere
    # output : un array contenant des actions d'un visitor (voir tableau ci-dessus) ; ces actions sont dispo dans la
    # classe Visitor
    #--------------------------------------------------------------------------------------------------------------------
    # exemple de regexp : bdEi-1
    #--------------------------------------------------------------------------------------------------------------------
    def self.actions(regexp)
      #regexp.gsub!("b", "[:go_to_start_page:]")
      #regexp.gsub!("d", "[:go_to_landing:]")
      #regexp.gsub!("E", "[:cl_on_link:]")
      p Regexp.new(regexp )
      p Regexp.new(regexp ).gen
      p /[:cl_on_link:]{2}/.gen
      /[:cl_on_link:]{4}/.gen.split /#{SEPARATOR}/
    end

  end


end