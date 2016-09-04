require_relative '../lib/parameter'
require 'rest-client'
require 'socket'
require 'json'
require 'rufus-scheduler'

module Captchas


  #-----------------------------------------------------------------------------------------------------------------
  # convert_to_text : permet de extraire la chaine de caractre d'un captcha
  # s'appuie sur le service saas d'extraction d'une chaine d'une image. Il y a 2 methodes :
  # méthode auto : s'appuie sur le serive internet de-captcher
  # méthode manual : s'appuie sur l'envoie d'un mail contenant le screenshot de l'ecran à un utilisateur. Ce derniere
  # saisie le texte de l'image dans un formulaire dont l'adresse est porté par le mail.
  # la valeur du texte est récupéré par interrogation reguliere du service
  #-----------------------------------------------------------------------------------------------------------------
  # input :
  # soit adr du captcha et du screenshot sur le disque => utilise la méthode auto pour convertir.
  # Si elle échoue alors utilise la méthode manuelle
  # soit adr du captcha sur le disque => utilise la méthode auto pour convertir
  # soit adr du screenshot sur le disque => utilise la méthode manuelle pour convertir
  # id_visitor
  # output :
  # une chaine représentant l'image
  # exception : none
  #-----------------------------------------------------------------------------------------------------------------
  #
  #-----------------------------------------------------------------------------------------------------------------


  def convert_to_text(params)
    #--------------------------------------------------------------------------------------------------------------------
    # LOAD PARAMETER
    #--------------------------------------------------------------------------------------------------------------------
    begin
      parameters = Parameter.new(__FILE__)

    rescue Exception => e
      $stderr << e.message << "\n"

    else
      $staging = parameters.environment
      $debugging = parameters.debugging
      saas_host = parameters.saas_host
      saas_port = parameters.saas_port
      time_out_saas_captcha = parameters.time_out_saas_captcha
      if saas_host.nil? or
          saas_port.nil? or
          time_out_saas_captcha.nil? or
          $debugging.nil? or
          $staging.nil?
        $stderr << "some parameters not define" << "\n"
      end
    end


    begin
      screenshot_file = params[:screenshot]
      captcha_file = params[:captcha]
      visitor_id = params[:visitor_id]
      captcha_value = nil

      if !screenshot_file.nil? and !captcha_file.nil?
        raise "screenshot file not found #{screenshot_file}" unless File.exist?(screenshot_file)
        raise "captcha file not found #{captcha_file}" unless File.exist?(captcha_file)

        begin
          # si le calcul automatique du text du captcha a fonctionné alors captcha_value contient le text
          captcha_value = auto_convert_to_text(captcha_file, visitor_id, saas_host, saas_port)

        rescue Exception => e
          # sinon alors la résolution est realisé manuellement au moyen d'un evoie de mail
          # dans ce cas, regulierement saas_rails/captcha est interrogé pour recuperer le text
          captcha_value = manual_convert_to_text_manual(screenshot_file, visitor_id, saas_host, saas_port)

        else

        end
      elsif !screenshot_file.nil?
        raise "screenshot file not found #{screenshot_file}" unless File.exist?(screenshot_file)
        begin
          captcha_value = manual_convert_to_text_manual(screenshot_file, visitor_id, saas_host, saas_port)

        rescue Exception => e

        end

      elsif !captcha_file.nil?
        raise "captcha file not found #{captcha_file}" unless File.exist?(captcha_file)
        begin
          captcha_value = auto_convert_to_text(captcha_file, visitor_id, saas_host, saas_port)

        rescue Exception => e

        end

      else
        raise "none input image file"

      end


      raise "captcha text is nil" if captcha_value.nil?

    rescue Exception => e
      raise "convert image captcha to text #{saas_host}:#{saas_port} => #{e}"

    else
      $stdout << "convert image captcha to text #{saas_host}:#{saas_port} : #{captcha_value}" << "\n" if $staging == "development"

    ensure


    end
    captcha_value

  end


  def auto_convert_to_text(captcha_file, visitor_id, saas_host, saas_port)
    image = File.open(captcha_file)

    captcha = send_image(image, visitor_id, saas_host, saas_port, :auto)

    response = RestClient.delete "http://#{saas_host}:#{saas_port}/captchas/#{captcha['id']}",
                                 :content_type => :json,
                                 :accept => :json

    captcha['value']
  end

  def manual_convert_to_text_manual(screenshot_file, visitor_id, saas_host, saas_port)
    image = File.open(screenshot_file)

    captcha = send_image(image, visitor_id, saas_host, saas_port, :manual)

    captcha_value = nil

    scheduler = Rufus::Scheduler.new
    scheduler.every '60s' do
      response = RestClient.get "http://#{saas_host}:#{saas_port}/captchas/#{captcha['id']}",
                                :content_type => :json,
                                :accept => :json

      captcha_value = JSON.parse(response)['value']

      scheduler.stop(:terminate => true) unless captcha_value == "unknown" #la valeur du captcha a été saisie

    end
    scheduler.join


    response = RestClient.delete "http://#{saas_host}:#{saas_port}/captchas/#{captcha['id']}",
                                 :content_type => :json,
                                 :accept => :json

    captcha_value
  end


  def send_image(image, visitor_id, saas_host, saas_port, mode)
    resource = RestClient::Resource.new("http://#{saas_host}:#{saas_port}/captchas")
    response = resource.post(:image => image, :visitor_id => visitor_id, :mode => mode)

    JSON.parse(response)
  end

  module_function :convert_to_text
  module_function :auto_convert_to_text
  module_function :manual_convert_to_text_manual
  module_function :send_image
end