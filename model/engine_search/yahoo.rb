require_relative '../../lib/error'
module EngineSearches
  class Yahoo < EngineSearch

    include Errors
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------


    def initialize
      @fqdn_search = "https://fr.search.yahoo.com"
      @path_search = "/"
      @id_search = 'p'
      @type_search = "textbox"
      @label_button_search = "Rechercher"

      @fqdn_captcha ="" #TODO à definir
      @id_capcha ='' , # TODO id de l'objet javascript qui contient le captcha à saisir
      @type_captcha = '', #TODO le type de l'objet jaavscript qui contient le captcha à saisir
      @label_button_captcha = ""  #TODO à definir label button captcha
      @id_image_captcha  =""    # TODO defnir id_image_captacha
      @coord_captcha = [] #TODO definir coordonate image captcha
    end

    def adverts(body)
      []
    end

    def is_captcha_page?(url)
      #determine si la page courant affiche un captcha bot Search
      sleep 5
      false #TODO par defaut
    end

    def links(body)
      links = []
      body.css('h3.title > a.td-u').each { |link|
        begin
          uri = URI.parse(link.attributes["href"].value)
        rescue Exception => e
        else
          links << {:href => /\/RU=(?<href>.+)\/RK=/.match(URI.decode(uri.path))[:href], :text => link.text}
        end
      }
      links
    end

    def next(body)
      if body.css('a.next').empty?
        {}
      else
        {:href => body.css('a.next').first.attributes["href"].value, :text => body.css('a.next').first.text}
      end
    end


    def prev(body)
      if body.css('a.prev').empty?
        {}
      else
        {:href => body.css('a.prev').first.attributes["href"].value, :text => body.css('a.prev').first.text}
      end
    end


    private
    def input(driver)
      driver.textbox(@id_search)
    end
  end
end
