require 'addressable/uri'

require_relative '../../lib/error'
module EngineSearches
  class Google < EngineSearch

    include Errors
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------

    def initialize #https://www.google.fr/webhp?gws_rd=ssl&ei=ihspV9mfFYm5abK7oZAH&emsg=NCSR&noj=1
      @fqdn_search = "https://www.google.fr"
      @path_search = "/" #webhp?gws_rd=ssl&emsg=NCSR&noj=1"
      @id_search = 'q'
      @type_search = "textbox"
      @label_button_search = "Recherche Google"

      @fqdn_captcha ="ipv4.google.com"
      @id_captcha = "captcha"  # id de l'objet javascript qui contient le captcha à saisir
      @type_captcha = "textbox" # le type de l'objet jaavscript qui contient le captcha à saisir
      @label_button_captcha = "Envoyer"  # label button captcha
      @id_image_captcha  ="Activez l'affichage des images"    # id_image_captacha
      @coord_captcha = [0,180,300,330]
    end

    def adverts(body)
      adverts = []
      body.css('ol > li.ads-ad > h3 > a:nth-child(2)').each { |l|
        adverts << {:href => l["href"], :text => l.text}
      }
      adverts
    end

    def captcha(body)
      # retourne l'image captcha ou bien l'adresse de l'image sur le disk
      # si captcha pas trouvé retourn nil

      begin

      rescue exception => e
        captcha = nil

      else

      ensure
        captcha

      end
    end

    def is_captcha_page?(url)
      #determine si la page courant affiche un captcha bot Search
      sleep 5 # attend que la page se raffraichisse et la zone de l'url du browser aussi.

      begin

        uri = Addressable::URI.parse(url)
        found = uri.host == @fqdn_captcha

      rescue Exception => e
        found = false

      end

      found
    end

    def links(body)
      links = []
      body.css('h3.r > a').each { |l|
        links << {:href => l["href"], :text => l.text}
      }
      links
    end

    def next(body)
      if body.css('a#pnnext.pn').empty?
        {}
      else
        {:href => "#{@fqdn_search}#{body.css('a#pnnext.pn')[0]["href"]}", :text => body.css('a#pnnext.pn > span').text}
      end
    end


    def prev(body)
      if body.css('a#pnprev.pn').empty?
        {}
      else
        {:href => "#{@fqdn_search}#{body.css('a#pnprev.pn')[0]["href"]}", :text => body.css('a#pnprev.pn > span').text}
      end
    end

    private


    def input(driver)
      driver.textbox(@id_search)
    end


  end

end

