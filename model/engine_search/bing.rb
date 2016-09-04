require_relative '../../lib/error'
module EngineSearches
  class Bing < EngineSearch

    include Errors
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------


    def initialize
      @fqdn_search = "http://www.bing.com"
      @path_search = "/"
      @id_search = 'q'
      @type_search = "searchbox"
      @label_button_search = "go"

      @fqdn_captcha ="" #TODO à definir
      @id_captcha ='' # TODO id de l'objet javascript qui contient le captcha à saisir
      @type_captcha = '' #TODO le type de l'objet jaavscript qui contient le captcha à saisir
      @label_button_captcha = "" #TODO à definir label button captcha
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
      body.css('li.b_algo > h2 > a').each { |l|
        links << {:href => l["href"], :text => l.text}
      }
      links
    end

    def next(body)
      if body.css('a.sb_pagN').empty?
        {}
      else
        {:href => "#{@fqdn}#{body.css('a.sb_pagN').first["href"]}", :text => body.css('a.sb_pagN').text}
      end
    end


    def prev(body)
      if body.css('a.sb_pagP').empty?
        {}
      else
        {:href => body.css('a.sb_pagP').first["href"], :text => body.css('a.sb_pagP').first.text}
      end
    end

    private
    def input(driver)
      driver.searchbox(@id_search)
    end

  end
end
