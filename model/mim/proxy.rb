require 'yaml'
require 'dot-properties'

require_relative '../../lib/parameter'
require_relative '../../lib/licence'

module Mim

  class Proxy
#----------------------------------------------------------------------------------------------------------------
# include class
#----------------------------------------------------------------------------------------------------------------
    include Errors


#----------------------------------------------------------------------------------------------------------------
# constants
#----------------------------------------------------------------------------------------------------------------
    ARGUMENT_NOT_DEFINE = 100
    PROXY_NOT_START = 101
    PROXY_NOT_STOP = 102
    PROXY_NOT_VALID = 103
#----------------------------------------------------------------------------------------------------------------
# attributs
#----------------------------------------------------------------------------------------------------------------

    @@logger = nil


    attr :pid,
         :listening_port_proxy, #port d'�coute de Sahi_proxy
         :listening_ip_proxy, #ip d'�coute de Sahi_proxy
         :user_home, # r�pertoire de config du visitor (user)
         :ip_geo_proxy,
         :port_geo_proxy,
         :user_geo_proxy,
         :pwd_geo_proxy,
         :visitor_dir,
         :install_sahi_dir,
         :java_runtime_dir,
         :java_key_tool_path,
         :start_page_server_ip,
         :license_server_enabled, :license_server_host, :license_server_port


#TODO supprimer listening_ip_proxy qui est l'ip du proxy sahi car cela ne fonctionne pas sur un serveur distant
    def initialize(visitor_dir,
                   listening_ip_proxy, listening_port_proxy,
                   ip_geo_proxy, port_geo_proxy, user_geo_proxy, pwd_geo_proxy)
      @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)
      raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "listening_port_proxy"}) if listening_port_proxy.nil?
      raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "listening_ip_proxy"}) if listening_ip_proxy.nil?
      raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_dir"}) if visitor_dir.nil? or visitor_dir == ""

      @listening_port_proxy = listening_port_proxy
      @listening_ip_proxy = listening_ip_proxy
      @visitor_dir = visitor_dir

      @@logger.an_event.debug "visitor_dir #{@visitor_dir}"
      @@logger.an_event.debug "listening_port_proxy #{@listening_port_proxy}"
      @@logger.an_event.debug "listening_ip_proxy #{@listening_ip_proxy}"

      @ip_geo_proxy = ip_geo_proxy
      @port_geo_proxy = port_geo_proxy
      @user_geo_proxy = user_geo_proxy
      @pwd_geo_proxy = pwd_geo_proxy

      @@logger.an_event.debug "ip_geo_proxy #{@ip_geo_proxy}"
      @@logger.an_event.debug "port_geo_proxy #{@port_geo_proxy}"
      @@logger.an_event.debug "user_geo_proxy #{@user_geo_proxy}"
      @@logger.an_event.debug "pwd_geo_proxy #{@pwd_geo_proxy}"

      @userdata = File.join(@visitor_dir, 'userdata')
      @@logger.an_event.debug "userdata #{@userdata}"

      #charge les paramétres
      parameters = load_parameters
      @install_sahi_dir = parameters.install_sahi_dir
      @java_runtime_dir = parameters.java_runtime_dir
      @java_key_tool_path = parameters.java_key_tool_path
      @start_page_server_ip = parameters.start_page_server_ip
      @license_server_enabled = parameters.license_server_enabled


      @@logger.an_event.debug "parameters loaded"
      @@logger.an_event.debug "install_sahi_dir #{@install_sahi_dir}"
      @@logger.an_event.debug "java_runtime_dir #{@java_runtime_dir}"
      @@logger.an_event.debug "java_key_tool_path #{@java_key_tool_path}"
      @@logger.an_event.debug "start_page_server_ip #{@start_page_server_ip}"
      @@logger.an_event.debug "license_server_enabled #{@license_server_enabled}"

      #-----------------------------------------------------------------------------------------------------------
      # copie le contenu du repertoire d'installation de sahi vers le repertoire d'execution du visitor :
      # /visitors/visitor_id
      #-----------------------------------------------------------------------------------------------------------
      FileUtils.mkdir_p(File.join(@visitor_dir))
      @@logger.an_event.debug "create visitor runtime dir <#{@visitor_dir}>"
      FileUtils.cp_r(File.join(@install_sahi_dir, "."), File.join(@visitor_dir))
      @@logger.an_event.debug "copy sahi runtime to visitor runtime dir."
      #-----------------------------------------------------------------------------------------------------------
      # copie user_extensions.js qui contient les fonctions sp�cifiques de recuperations des links dans
      # /visitors/visitor_id/userdata/config
      #-----------------------------------------------------------------------------------------------------------
      FileUtils.cp_r(File.join(File.dirname(__FILE__), 'user_extensions.js'), File.join(@userdata, 'config'))

      #-----------------------------------------------------------------------------------------------------------
      # copie 5xx.htm qui contient le message d'erreur 5xx http dans
      # /visitors/visitor_id/htdocs/spr
      #-----------------------------------------------------------------------------------------------------------
      FileUtils.cp_r(File.join(File.dirname(__FILE__), '5xx.htm'), File.join(@visitor_dir, 'htdocs', 'spr'))

      #-----------------------------------------------------------------------------------------------------------
      # copie html2canvas.js qui permet de gérer les screenshot
      # copie promise.min.js car internet explorer ne connait pas promise.js
      # /visitors/visitor_id/config
      #-----------------------------------------------------------------------------------------------------------
      FileUtils.cp_r(File.join(File.dirname(__FILE__), 'html2canvas.js'), File.join(@visitor_dir, 'htdocs', 'spr'))
      FileUtils.cp_r(File.join(File.dirname(__FILE__), 'promise.min.js'), File.join(@visitor_dir, 'htdocs', 'spr'))

      #-----------------------------------------------------------------------------------------------------------
      # copie inject_top_.txt qui permet injecter des fichiers javascript dans chaque page html
      # celui-ci est spécialisé par l'ajout de html2canvas et promise
      #-----------------------------------------------------------------------------------------------------------
      FileUtils.cp_r(File.join(File.dirname(__FILE__), 'inject_top.txt'), File.join(@visitor_dir, 'config'))

      #-----------------------------------------------------------------------------------------------------------
      # copie & maj dans /htdocs/spr/initialized.htm qui remplace la page de lancement de sahi. Cela permet
      # de ne pas afficher dan sl'history la page de lancement de sahi. Cette page sera remplacée par le
      # MDR par défaut du navigateur définit dans la visite
      #-----------------------------------------------------------------------------------------------------------
      FileUtils.cp_r(File.join(File.dirname(__FILE__), 'initialized.htm'), File.join(@visitor_dir, 'htdocs', 'spr'))

      #-----------------------------------------------------------------------------------------------------------
      # publie le repository des browsers (repository.csv) vers le fichier contenant les browser types
      #-----------------------------------------------------------------------------------------------------------
      bt = Mim::BrowserTypes::from_csv
      bt.publish_to_sahi([@userdata, "config"], [@listening_port_proxy], [@listening_ip_proxy]) #TODO � reviser pas besoin du port ni ip ppouir le profil
      @@logger.an_event.debug "repository browsers published to browser type file : #{@userdata + "config"}"

      #-----------------------------------------------------------------------------------------------------------
      # creation des profiles ff & chrome
      #-----------------------------------------------------------------------------------------------------------
      #$userDir\\browser\\chrome\\profiles\\sahi_#{port}
      #$userDir/browser/ff/profiles/sahi_#{port}
      ff_profiles = File.join(@visitor_dir, ["userdata", "browser", "ff", "profiles"])
      ch_profiles = File.join(@visitor_dir, ["userdata", "browser", "chrome", "profiles"])

      FileUtils.rm_r(ff_profiles, :force => true) if File.exist?(ff_profiles)
      FileUtils.rm_r(ch_profiles, :force => true) if File.exist?(ch_profiles)
      @@logger.an_event.debug "delete profile ff et ch"

      FileUtils.mkdir_p(ch_profiles)
      FileUtils.mkdir_p(ff_profiles)
      FileUtils.cp_r(File.join(@install_sahi_dir, "config", 'ff_profile_template', '.'), ff_profiles)
      @@logger.an_event.debug "create profile ff et ch"

      # userdata\proxy\config\ff_profile_template\prefs.js :
      # le port d'ecoute du proxy pour firefox
      prefs_js = File.join(ff_profiles, "prefs.js")
      FileUtils.cp_r(File.join(File.dirname(__FILE__), 'prefs.js'), prefs_js)
      file_custom = File.read(prefs_js)
      file_custom.gsub!(/listening_ip_proxy/, @listening_ip_proxy.to_s)
      file_custom.gsub!(/listening_port_proxy/, @listening_port_proxy.to_s)
      File.write(prefs_js, file_custom)
      @@logger.an_event.debug "update prefs.js for ff"

      #-----------------------------------------------------------------------------------------------------------
      # custom proxy system for ie, opera, edge
      #-----------------------------------------------------------------------------------------------------------
      # \tools\proxy.properties :
      proxy_properties = File.join(@visitor_dir, "tools", 'proxy.properties')
      FileUtils.cp_r(File.join([File.dirname(__FILE__), "proxy.properties"]), proxy_properties)

      file_custom = File.read(proxy_properties)
      file_custom.gsub!(/listening_ip_proxy/, @listening_ip_proxy.to_s)
      file_custom.gsub!(/listening_port_proxy/, @listening_port_proxy.to_s)
      File.write(proxy_properties, file_custom)
      @@logger.an_event.debug "proxy.properties for ie opera edge"

      #-----------------------------------------------------------------------------------------------------------
      # maj dans /visitors\visitor_id/userdata/config.userdata.properties
      #-----------------------------------------------------------------------------------------------------------
      userdata = DotProperties.load(File.join(@userdata, 'config', "userdata.properties"))

      userdata['ext.http.proxy.enable'] = @ip_geo_proxy.nil? ? false.to_s : true.to_s
      userdata['ext.http.proxy.host'] = @ip_geo_proxy.nil? ? "" : @ip_geo_proxy.to_s
      userdata['ext.http.proxy.port'] = @port_geo_proxy.nil? ? "" : @port_geo_proxy.to_s
      userdata['ext.http.proxy.auth.enable'] = @user_geo_proxy.nil? ? false.to_s : true.to_s
      userdata['ext.http.proxy.auth.name'] = @user_geo_proxy.nil? ? "" : @user_geo_proxy.to_s
      userdata['ext.http.proxy.auth.password'] = @pwd_geo_proxy.nil? ? "" : @pwd_geo_proxy.to_s

      userdata['ext.https.proxy.enable'] = @ip_geo_proxy.nil? ? false.to_s : true.to_s
      userdata['ext.https.proxy.host'] = @ip_geo_proxy.nil? ? "" : @ip_geo_proxy.to_s
      userdata['ext.https.proxy.port'] = @port_geo_proxy.nil? ? "" : @port_geo_proxy.to_s
      userdata['ext.https.proxy.auth.enable'] = @user_geo_proxy.nil? ? false.to_s : true.to_s
      userdata['ext.https.proxy.auth.name'] = @user_geo_proxy.nil? ? "" : @user_geo_proxy.to_s
      userdata['ext.https.proxy.auth.password'] = @pwd_geo_proxy.nil? ? "" : @pwd_geo_proxy.to_s

      userdata['ext.http.both.proxy.bypass_hosts'] += userdata['ext.http.both.proxy.bypass_hosts'].include?(@start_page_server_ip) ?
          "" :
          "|" + @start_page_server_ip

      userdata['browser_launch.delay_after_proxy_change'] = 1500.to_s

      File.open(File.join(@userdata, 'config', "userdata.properties"), 'w') { |out| out.write(userdata.to_s) }

      @@logger.an_event.debug "customized userdata.properties"

      #-----------------------------------------------------------------------------------------------------------
      # maj dans /config/sahi.properties :
      #-----------------------------------------------------------------------------------------------------------
      sahi = DotProperties.load(File.join(@visitor_dir, 'config', "sahi.properties"))

      sahi['proxy.port'] = @listening_port_proxy.to_s
      sahi['keytool.path'] = @java_key_tool_path.join('\\')

      File.open(File.join(@visitor_dir, 'config', "sahi.properties"), 'w') { |out| out.write(sahi.to_s) }

      @@logger.an_event.debug "customized sahi.properties"

      #-----------------------------------------------------------------------------------------------------------
      # controle de la validité de la license sahi
      #-----------------------------------------------------------------------------------------------------------
      check_license
    end

# controle que l'instance lanc�e est active.
# utilise le pid
    def running?
      require 'csv'
      #TODO remplacer tasklist par ps pour linux
      res = IO.popen('tasklist /V /FI "PID eq ' + @pid + '" /FO CSV /NH').read

      @@logger.an_event.debug "tasklist for java.exe : #{res}"

      CSV.parse(res) do |row|
        return true if row[1].include?(@pid.to_s)
      end

      false
    end

    def start
      begin

        #-----------------------------------------------------------------------------------------------------------
        #start proxy mim
        #-----------------------------------------------------------------------------------------------------------
        cmd = File.join(@visitor_dir, 'bin', "sahi.bat")

        @@logger.an_event.debug "cmd start proxy #{cmd}"

        var_env = {"SAHI_HOME" => File.join(@visitor_dir),
                   "SAHI_USERDATA_DIR" => File.join(@userdata),
                   "SAHI_EXT_CLASS_PATH" => File.join(@visitor_dir, "extlib", "*"),
                   "PATH" => File.join(@java_runtime_dir)}
        @@logger.an_event.debug "var_env start proxy #{var_env}"

        chdir = File.join([@visitor_dir, "bin"])
        @@logger.an_event.debug "chdir start proxy #{chdir}"

        @pid = 0
        @pid = Process.spawn(var_env,
                             cmd,
                             :chdir => chdir,
                             [:out, :err] => [File.join(@visitor_dir, "sahi_proxy_log.txt"), "w"])

        @@logger.an_event.debug "pid proxy #{@pid}"

      rescue Exception => e
        @@logger.an_event.error "proxy started on machine #{@listening_ip_proxy} on port #{@listening_port_proxy} : #{e.message}"
        raise Errors::Error.new(PROXY_NOT_START, :error => e)

      else
        @@logger.an_event.info "proxy started on machine #{@listening_ip_proxy} on port #{@listening_port_proxy}"

      end
    end


    def stop
      begin
        #-----------------------------------------------------------------------------------------------------------
        # stop proxy mim
        # mettre le pid � nil.
        #-----------------------------------------------------------------------------------------------------------
        # cmd = @pid.nil? ? "/IM java.exe" : "/PID #{@pid}" trop dangereux risque de peter toutes les visites en cours
        raise "pid proxy non define" if @pid.nil?
        cmd = "/PID #{@pid}"

        #TODO remplacer tasklist par ps pour linux
        res = IO.popen("taskkill #{cmd} /T /F").read
        @pid = nil
        @@logger.an_event.debug "taskkill for java.exe #{@pid}: <#{res}>"

      rescue Exception => e
        @@logger.an_event.error "proxy stopped on machine #{@listening_ip_proxy} on port #{@listening_port_proxy} : #{e.message}"
        raise Errors::Error.new(PROXY_NOT_STOP, :error => e)

      else
        @@logger.an_event.info "proxy stopped on machine #{@listening_ip_proxy} on port #{@listening_port_proxy}"

      end


    end

    private

    def check_license
      # TODO desinstanller le serveurde licence SAHI sur la machine 192.168.1.88
      # le serveur de licence SAHI n'est pas utilisé car il fonctionne avec des licences PRO achétées, les licences de 30j
      # ne fonctionnent pas avec le serveur de licence SAHI.
      # mise en place d'un server de licence proprietaire qui permet d'uploader des fichiers de licence et de le
      # downloader à la demande par statupbot

      if @license_server_enabled
        license = ""

        begin
          license = Licence.get

        rescue Exception => e
          @@logger.an_event.debug "le server de license non joignable"
          raise Errors::Error.new(PROXY_NOT_VALID, :error => e)

        else
          @@logger.an_event.debug "license recupere du serveur de licence"

          #TODO tester la validité de la license sahi telechargée du sereur de licence maison
          # @@logger.an_event.debug "check la date validite du fichier de license : license.data"
          # raise Errors::Error.new(PROXY_NOT_VALID, :error => "license out of date")
          @@logger.an_event.debug "validite de la licence confirmee"

          File.open(File.join(@visitor_dir, "userdata", "config", "license.data"), 'wb') do |file|
            file.write(license)
            file.close
          end
          @@logger.an_event.debug "license sauvegardee dans visitor_dir userdata config"
        end

      else
        #TODO tester la validité du fichier de licence sahi : \userdata\config\license.data
        # @@logger.an_event.debug "check la date validite du fichier de license : license.data"
        # raise Errors::Error.new(PROXY_NOT_VALID, :error => "license out of date")

      end

    end

    def load_parameters
      #--------------------------------------------------------------------------------------------------------------------
      # LOAD PARAMETER
      #--------------------------------------------------------------------------------------------------------------------
      begin
        parameters = Parameter.new("mim.rb")

      rescue Exception => e
        $stderr << e.message << "\n"

      else
        $staging = parameters.environment
        $debugging = parameters.debugging
        install_sahi_dir = parameters.install_sahi_dir
        java_runtime_dir = parameters.java_runtime_dir
        start_page_server_ip = parameters.start_page_server_ip
        start_page_server_port = parameters.start_page_server_port

        if install_sahi_dir.nil? or
            java_runtime_dir.nil? or
            start_page_server_ip.nil? or
            start_page_server_port.nil? or
            $debugging.nil? or
            $staging.nil?
          $stderr << "some parameters not define" << "\n"
        end
      end
      parameters

    end

# waits for specified time (in seconds).
# if a block is passed, it will wait till the block evaluates to true or till the specified timeout, which ever is earlier.
    def wait(timeout)
      total = 0;
      interval = 0.2;

      if !block_given?
        sleep(timeout)
        return
      end

      while (total < timeout)
        sleep(interval);
        total += interval;
        begin
          return if yield
        rescue Exception => e
          @@logger.an_event.warn e.message
        end
      end
    end

  end
end



