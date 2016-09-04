require 'pathname'
require_relative '../../lib/os'
require_relative '../../lib/error'
module Browsers
  class Proxy
    #----------------------------------------------------------------------------------------------------------------
    # message exception
    #----------------------------------------------------------------------------------------------------------------
    ARGUMENT_UNDEFINE = 100
    PROXY_NOT_CREATE = 101 # à remonter en code retour de statupbot
    PROXY_NOT_START = 102 # à remonter en code retour de statupbot
    PROXY_NOT_STOP = 103 # à remonter en code retour de statupbot
    CLEAN_NOT_COMPLETE = 104 # à remonter en code retour de statupbot
    RUNTIME_OPENSSL_NOT_SELECT = 105
    PSKILL_NOT_FOUND = 106
    PSLIST_NOT_FOUND = 107

    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors

    #----------------------------------------------------------------------------------------------------------------
    # constant
    #----------------------------------------------------------------------------------------------------------------
    DIR_SAHI = File.join(File.dirname(__FILE__), '..', '..', 'lib', 'sahi.in.co')
    DIR_SAHI_TOOLS = File.join(File.dirname(__FILE__), '..', '..', 'lib', 'sahi.in.co', 'tools')
    #CLASSPATH PROXY OPEN SOURCE
    #CLASS_PATH = File.join(DIR_SAHI, 'lib', 'sahi.jar') + ';' +
    #    File.join(DIR_SAHI, 'extlib', 'rhino', 'js.jar') + ';' +
    #    File.join(DIR_SAHI, 'extlib', 'apc', 'commons-codec-1.3.jar')

    #CLASS PATH PROXY PRO
    CLASS_PATH = File.join(DIR_SAHI, 'lib', 'sahi.jar') + ';' +
        File.join(DIR_SAHI, 'extlib', 'rhino', 'js.jar') + ';' +
        File.join(DIR_SAHI, 'extlib', 'apc', 'commons-codec-1.3.jar' + ';' +
                              File.join(DIR_SAHI, 'extlib', 'db', 'h2.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'license', 'truelicense.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'license', 'truexml.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'poi', 'dom4j-1.6.1.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'poi', 'excelpoi.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'poi', 'poi-3.7-20101029.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'poi', 'poi-ooxml-3.7-20101029.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'poi', 'poi-ooxml-schemas-3.7-20101029.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'poi', 'xmlbeans-2.3.0.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'mail', 'mail.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'mail', 'activation.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'c3p0', 'c3p0-0.9.5-pre5.jar') + ';' +
                              File.join(DIR_SAHI, 'extlib', 'c3p0', 'mchange-commons-java-0.2.6.2'))

    #BIN_JAVA_PATH = "\"C:/Program Files (x86)/Java/jre6/bin/java\""
    #----------------------------------------------------------------------------------------------------------------
    # variable de class
    #----------------------------------------------------------------------------------------------------------------
    @@logger = nil
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------
    attr :pid, #pid du process java -classpath %class_path% net.sf.sahi.Proxy "%home%" "%user_home%"
         :listening_port_proxy, #port d'écoute de Sahi_proxy
         :home, # répertoire de config de Sahi_proxy
         :user_home, # répertoire de config du visitor (user)
         :port_geo_proxy,
         :user_geo_proxy,
         :pwd_geo_proxy,
         :visitor_dir

    attr_reader :ip_geo_proxy  # exposé pour remonté la geolocation vers statupweb
    #----------------------------------------------------------------------------------------------------------------
    # class methods
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # instance methods
    #----------------------------------------------------------------------------------------------------------------

    #----------------------------------------------------------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------------------------------------------------------
    # crée un proxy :
    # inputs
    # visitor_dir,
    # listening_port_proxy,
    # ip_geo_proxy,   (option)
    # port_geo_proxy, (option)
    # user_geo_proxy, (option)
    # pwd_geo_proxy   (option)
    # output
    # StandardError
    # StandardError
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def initialize(visitor_dir, listening_port_proxy, ip_geo_proxy, port_geo_proxy, user_geo_proxy, pwd_geo_proxy)
      @@logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      @@logger.an_event.debug "visitor_dir #{visitor_dir}"
      @@logger.an_event.debug "listening_port_proxy #{listening_port_proxy}"
      @@logger.an_event.debug "ip_geo_proxy #{ip_geo_proxy}"
      @@logger.an_event.debug "port_geo_proxy #{port_geo_proxy}"
      @@logger.an_event.debug "user_geo_proxy #{user_geo_proxy}"
      @@logger.an_event.debug "pwd_geo_proxy #{pwd_geo_proxy}"


      begin
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "listening_port_proxy"}) if listening_port_proxy.nil?
        raise Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "visitor_dir"}) if visitor_dir.nil? or visitor_dir == ""
        raise Error.new(PSLIST_NOT_FOUND, :values => {:runtime => File.join(DIR_SAHI_TOOLS, 'pslist.exe')}) unless File.exist?(File.join(DIR_SAHI_TOOLS, 'pslist.exe'))
        raise Error.new(PSKILL_NOT_FOUND, :values => {:runtime => File.join(DIR_SAHI_TOOLS, 'pslist.exe')}) unless File.exist?(File.join(DIR_SAHI_TOOLS, 'pslist.exe'))


        @ip_geo_proxy = ip_geo_proxy
        @port_geo_proxy = port_geo_proxy
        @user_geo_proxy = user_geo_proxy
        @pwd_geo_proxy = pwd_geo_proxy
        @listening_port_proxy = listening_port_proxy
        @visitor_dir = visitor_dir


        @home = File.join(@visitor_dir, 'proxy')
        @@logger.an_event.debug "home #{@home}"

        @user_home = File.join(@visitor_dir, 'proxy', 'userdata')
        @@logger.an_event.debug "user_home #{@user_home}"

        @log_properties = File.join(@user_home, 'config', 'log.properties')
        @@logger.an_event.debug "log_properties #{@log_properties}"


        # on fait du nettoyage pour eviter de perturber le proxy avec un paramètrage bancal
        if File.exist?(@home)
          FileUtils.rm_r(@home, :force => true) if File.exist?(@home)
          @@logger.an_event.debug "clean config files proxy sahi for visitor dir #{@visitor_dir}"
        end

        # statupbot\lib\sahi.in.co\userdata\config to #id_visitor\proxy\userdata\config\userdata\config
        # statupbot\lib\sahi.in.co\config to #id_visitor\proxy\config
        # statupbot\lib\sahi.in.co\htdocs to #id_visitor\proxy\htdocs
        # statupbot\lib\sahi.in.co\tools to #id_visitor\proxy\tools
        FileUtils.mkdir_p(File.join(@user_home, 'config'))
        FileUtils.cp_r(File.join(DIR_SAHI, 'userdata', 'config'), @user_home)
        FileUtils.cp_r(File.join(DIR_SAHI, 'userdata', 'certgen'), @user_home)
        FileUtils.cp_r(File.join(DIR_SAHI, 'userdata', 'logs'), @user_home)  #TODO pour la V4 ne pas faire copie mais creer le repertoire
        FileUtils.cp_r(File.join(DIR_SAHI, 'certgen'), @home)
        FileUtils.cp_r(File.join(DIR_SAHI, 'config'), @home)
        FileUtils.cp_r(File.join(DIR_SAHI, 'htdocs'), @home)
        FileUtils.cp_r(File.join(DIR_SAHI, 'tools'), @home)
        @@logger.an_event.debug "copy config files proxy sahi #{DIR_SAHI} to #{@home}"

        # id_visitor\proxy\config\sahi.properties   avec :
        # le port d'ecoute du proxy
        # ip:port@user:pwd du proxy de geolocation (ou NTLM) pour http & https ou pas
        file_name = File.join(@home, 'config', 'sahi.properties')
        file_custom = File.read(file_name)
        file_custom.gsub!(/is_proxy_enable/, "false") if @ip_geo_proxy.nil?
        file_custom.gsub!(/ip_geo_proxy/, "") if @ip_geo_proxy.nil?
        file_custom.gsub!(/port_geo_proxy/, "".to_s) if @port_geo_proxy.nil?
        file_custom.gsub!(/is_auth_enable/, "false") if @user_geo_proxy.nil?
        file_custom.gsub!(/user_geo_proxy/, "") if @user_geo_proxy.nil?
        file_custom.gsub!(/pwd_geo_proxy/, "") if @pwd_geo_proxy.nil?
        file_custom.gsub!(/is_proxy_enable/, "true") unless @ip_geo_proxy.nil?
        file_custom.gsub!(/ip_geo_proxy/, @ip_geo_proxy) unless @ip_geo_proxy.nil?
        file_custom.gsub!(/port_geo_proxy/, @port_geo_proxy.to_s) unless @port_geo_proxy.nil?
        file_custom.gsub!(/is_auth_enable/, "true") unless @user_geo_proxy.nil?
        file_custom.gsub!(/user_geo_proxy/, @user_geo_proxy) unless @user_geo_proxy.nil?
        file_custom.gsub!(/pwd_geo_proxy/, @pwd_geo_proxy) unless @pwd_geo_proxy.nil?
        file_custom.gsub!(/listening_port_proxy/, @listening_port_proxy.to_s)
        file_custom.gsub!(/java_key_tool_path/, $java_key_tool_path)
        file_custom.gsub!(/start_page_server_ip/, $start_page_server_ip)


        File.write(file_name, file_custom)
        @@logger.an_event.debug "customize properties in #{file_name} with #{file_custom}"

        # id_visitor\proxy\config\os.properties   avec :
        # le path de pslist
        # le path de pskill
        file_name = File.join(@home, 'config', 'os.properties')
        file_custom = File.read(file_name)
        file_custom.gsub!(/path_pslist/, File.join(@home, 'tools', 'pslist.exe'))
        file_custom.gsub!(/path_pskill/, File.join(@home, 'tools', 'pskill.exe'))
        File.write(file_name, file_custom)
        @@logger.an_event.debug "customize path of pskill and pslist in #{file_name} with #{file_custom}"


        select_openssl_runtime
      rescue Exception => e
        @@logger.an_event.fatal e.message
        raise Error.new(PROXY_NOT_CREATE, :error => e)

      else
        @@logger.an_event.debug "proxy sahi listening on port #{@listening_port_proxy}"

      ensure


      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # delete_config
    #----------------------------------------------------------------------------------------------------------------
    # delete les fichiers de configuration et d'exécution du proxy :
    # inputs
    # output
    # StandardError
    # StandardError
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def delete_config

      try_count = 0
      max_try_count = 10

      begin

        FileUtils.rm_r(@home) if File.exist?(@home)

      rescue Exception => e
        @@logger.an_event.debug "config files proxy Sahi is deleting, try #{try_count}"
        sleep (1)
        try_count += 1
        retry if try_count < max_try_count

        @@logger.an_event.error "config files proxy Sahi is deleting : #{e.message}"
        raise Error.new(CLEAN_NOT_COMPLETE, :values => {:variable => "visitor_dir"}, :error => e)
      else
        @@logger.an_event.debug "config files proxy Sahi are deleted"

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------------------------------------------------------
    # demarre un proxy :
    # inputs

    # output
    # StandardError
    # StandardError
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def start

      begin
        #@pid = spawn("java -classpath #{CLASS_PATH} net.sf.sahi.Proxy \"#{@home}\" \"#{@user_home}\" ") #lanceur proxy open source
        #cmd = "#{BIN_JAVA_PATH} -Djava.util.logging.config.file=#{@log_properties} -classpath #{CLASS_PATH} net.sf.sahi.Proxy \"#{@home}\" \"#{@user_home}\" "
        cmd = "#{$java_runtime_path} -Djava.util.logging.config.file=#{@log_properties} -classpath #{CLASS_PATH} net.sf.sahi.Proxy \"#{@home}\" \"#{@user_home}\" "
        @@logger.an_event.debug "command execution proxy Sahi : #{cmd}"

        sahi_proxy_log_file = File.join(@user_home, 'logs', 'sahi_proxy_log.txt')
        @@logger.an_event.debug "file path log file proxy Sahi #{sahi_proxy_log_file}"

        @pid = Process.spawn(cmd, [:out, :err] => [sahi_proxy_log_file, "w"])


      rescue Exception => e
        @@logger.an_event.fatal e.message
        raise Error.new(PROXY_NOT_START, :error => e)

      else
        @@logger.an_event.debug "proxy Sahi is started with pid #{@pid}"

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # select_openssl_runtime
    #----------------------------------------------------------------------------------------------------------------
    # stop un proxy :
    # inputs
    # output
    # StandardError
    # StandardError
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def select_openssl_runtime

      begin

        openssl_dir = ""
        if OS.windows?
          openssl_dir = "openssl.win32" if ENV["ProgramFiles(x86)"].nil?
          openssl_dir = "openssl.win64" unless ENV["ProgramFiles(x86)"].nil?
        end
        openssl_dir = "openssl.mac" if OS.mac?
        openssl_dir = "openssl.linux" if OS.linux?

        @@logger.an_event.debug "openssl dir #{File.join(@home, 'certgen', openssl_dir)}"

        FileUtils.cp_r(Dir.glob(File.join(@home, 'certgen', openssl_dir, '*.*')), File.join(@home, 'certgen'))

      rescue Exception => e
        @@logger.an_event.fatal e.message
        raise Error.new(RUNTIME_OPENSSL_NOT_SELECT, :values => {:openssl_dir => openssl_dir}, :error => e)

      else
        @@logger.an_event.debug "runtime openssl selected"

      ensure

      end
    end

    #----------------------------------------------------------------------------------------------------------------
    # stop
    #----------------------------------------------------------------------------------------------------------------
    # stop un proxy :
    # inputs
    # output
    # StandardError
    # StandardError
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------

    def stop

      begin
        Process.kill("KILL", @pid)
        Process.waitall

      rescue SignalException => e
        @@logger.an_event.error "proxy Sahi #{@pid} stop : #{e.message}"
        raise Error.new(PROXY_NOT_STOP, :error => e)

      else
        @@logger.an_event.debug "proxy Sahi #{@pid} stop"
      ensure

      end
    end
  end
end

