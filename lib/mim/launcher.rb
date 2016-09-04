require 'yaml'
require 'dot-properties'

require_relative "browser_type"
require_relative '../../lib/parameter'

module Mim

  class Launcher
#----------------------------------------------------------------------------------------------------------------
# include class
#----------------------------------------------------------------------------------------------------------------
    include Errors


#----------------------------------------------------------------------------------------------------------------
# constants
#----------------------------------------------------------------------------------------------------------------
    BROWSER_TYPE_FILE_DIR = ['userdata', 'config']
    PROFILES_FF_DIR = ['userdata', 'browser', 'ff', 'profiles']
    TOOLS_DIR = ['tools']
#----------------------------------------------------------------------------------------------------------------
# attributs
#----------------------------------------------------------------------------------------------------------------
    @@pid = nil
    attr :logger

# controle qu'une instance n'est pas d�j� en train de tourner.
#  � utiliser quand on a pas le pid du process : qd on ne l'a pas lanc�
    def self.exist?
      require 'csv'
      #TODO remplacer tasklist par ps pour linux
      res = IO.popen('tasklist /V /FI "IMAGENAME eq java.exe" /FO CSV /NH').read

      @@logger.an_event.debug "tasklist for java.exe : #{res}"

      CSV.parse(res) do |row|
        return true if row[0].include?("java.exe")
      end

      false

    end


    def self.known?(browser_type)
      #-----------------------------------------------------------------------------------------------------------
      #charge les param�tres
      #-----------------------------------------------------------------------------------------------------------
      parameters = load_parameters
      launcher_runtime_dir = parameters.launcher_runtime_dir

      BrowserTypes.exist?(launcher_runtime_dir + BROWSER_TYPE_FILE_DIR, browser_type)

    end

    def self.load_parameters
      begin
        parameters = Parameter.new("mim.rb")

      rescue Exception => e
        $stderr << e.message << "\n"

      else
        $staging = parameters.environment
        $debugging = parameters.debugging

        if parameters.install_sahi_dir.nil? or
            parameters.java_runtime_dir.nil? or
            parameters.launcher_runtime_dir.nil? or
            $debugging.nil? or
            $staging.nil?
          $stderr << "some parameters not define" << "\n"
        end
      end
      parameters

    end


    def self.process_name(browser_type)
      #-----------------------------------------------------------------------------------------------------------
      #charge les param�tres
      #-----------------------------------------------------------------------------------------------------------
      parameters = load_parameters
      launcher_runtime_dir = parameters.launcher_runtime_dir

      BrowserTypes.process_name(launcher_runtime_dir + BROWSER_TYPE_FILE_DIR, browser_type)
    end

    def self.profiles_ff
      #-----------------------------------------------------------------------------------------------------------
      #charge les param�tres
      #-----------------------------------------------------------------------------------------------------------
      parameters = load_parameters
      launcher_runtime_dir = parameters.launcher_runtime_dir
      launcher_runtime_dir + PROFILES_FF_DIR
    end

# controle que l'instance lanc�e est active.
# utilise le pid
    def self.running?
      require 'csv'
      #TODO remplacer tasklist par ps pour linux
      res = IO.popen('tasklist /V /FI "PID eq ' + @@pid + '" /FO CSV /NH').read

      @@logger.an_event.debug "tasklist for java.exe : #{res}"

      CSV.parse(res) do |row|
        return true if row[1].include?(@@pid.to_s)
      end

      false
    end

# avant de la lancer controler qu'il n'est pas d�j� lancer en charchant son pid dans le tasklist car si
# visitor_factory redemarre alors la nouvelle instance de sahi va planter car le port 9999 est d�j�utiliser
# et on va perdre le pid du premier lancement
    def self.start(booked_port, proxy_ip_list)
      @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      #-----------------------------------------------------------------------------------------------------------
      # stoppe une execution ant�rieure
      #-----------------------------------------------------------------------------------------------------------
      stop if exist?

      #-----------------------------------------------------------------------------------------------------------
      #charge les param�tres
      #-----------------------------------------------------------------------------------------------------------
      parameters = load_parameters
      install_sahi_dir = parameters.install_sahi_dir
      java_runtime_dir = parameters.java_runtime_dir
      launcher_runtime_dir = parameters.launcher_runtime_dir

      @@logger.an_event.debug "parameter loaded"

      #-----------------------------------------------------------------------------------------------------------
      # copie le contenu du repertoire d'installation de sahi vers le repertoire d'execution du launcher
      #-----------------------------------------------------------------------------------------------------------
      FileUtils.rm_r(File.join(launcher_runtime_dir)) if File.exist?(File.join(launcher_runtime_dir))
      @@logger.an_event.debug "delete launcher runtime dir <#{launcher_runtime_dir}>"
      FileUtils.mkdir_p(File.join(launcher_runtime_dir))
      @@logger.an_event.debug "create launcher runtime dir <#{launcher_runtime_dir}>"
      FileUtils.cp_r(File.join(install_sahi_dir, "."), File.join(launcher_runtime_dir))
      @@logger.an_event.debug "copy sahi runtime to launcher runtime dir."
      #-----------------------------------------------------------------------------------------------------------
      # publie le repository des browsers (repository.csv) vers le fichier contenant les browser types
      #-----------------------------------------------------------------------------------------------------------
      bt = Mim::BrowserTypes::from_csv
      bt.publish_to_sahi(launcher_runtime_dir + BROWSER_TYPE_FILE_DIR, booked_port, proxy_ip_list)
      @@logger.an_event.debug "repository browsers published to browser type file : #{launcher_runtime_dir + BROWSER_TYPE_FILE_DIR}"

      #-----------------------------------------------------------------------------------------------------------
      # maj dans /config/sahi.properties :
      # proxy.port=9999
      # car le port sera chang� par le proxy � chaque lancement
      #-----------------------------------------------------------------------------------------------------------
      sahi = DotProperties.load(File.join(launcher_runtime_dir, 'config', "sahi.properties"))
      sahi['proxy.port'] = 9999.to_s
      File.open(File.join(launcher_runtime_dir, 'config', "sahi.properties"), 'w') { |out| out.write(sahi.to_s) }

      @@logger.an_event.debug "update listening port sahi with 9999"

      #-----------------------------------------------------------------------------------------------------------
      # suppresion des profiles existant ff & chrome
      # creation des profiles ff & chrome
      #-----------------------------------------------------------------------------------------------------------
      #$userDir\\browser\\chrome\\profiles\\sahi_#{port}
      #$userDir/browser/ff/profiles/sahi_#{port}
      ff_profiles = launcher_runtime_dir + ["userdata", "browser", "ff", "profiles"]
      ch_profiles = launcher_runtime_dir + ["userdata", "browser", "chrome", "profiles"]

      FileUtils.rm_r(File.join(ff_profiles), :force => true) if File.exist?(File.join(ff_profiles))
      FileUtils.rm_r(File.join(ch_profiles), :force => true) if File.exist?(File.join(ch_profiles))


      booked_port.each { |port|
        FileUtils.mkdir_p(File.join(ch_profiles + ["sahi_#{port}"]))
        proxy_ip_list.each { |ip|
          FileUtils.mkdir_p(File.join(ff_profiles + ["sahi_#{ip}_#{port}"]))
          FileUtils.cp_r(File.join(launcher_runtime_dir, "config", 'ff_profile_template', '.'), File.join(ff_profiles + ["sahi_#{ip}_#{port}"]))
        }
      }

      #-----------------------------------------------------------------------------------------------------------
      # execution du proxy local
      #-----------------------------------------------------------------------------------------------------------
      cmd = File.join(launcher_runtime_dir, 'bin', "sahi.bat")

      @@logger.an_event.debug "cmd start launcher #{cmd}"

      @@pid = 0
      @@pid = Process.spawn({"PATH" => File.join(java_runtime_dir)},
                            cmd,
                            :chdir => File.join([launcher_runtime_dir, "bin"]),
                            [:out, :err] => [File.join(launcher_runtime_dir, "userdata", "logs", "sahi_proxy_log.txt"), "w"])

      @@logger.an_event.debug "pid launcher #{@@pid}"

      bt # return des browser type pour visitor_factory pour creer les pool de scan de visi file
    end


    def self.stop
      # mettre le pid à nil.
      # on a pas le pid car il existe une instance qui tourne lancee par un visitor_factory precedent. (il y a eu un pb)
      # on kill alors tous les process java.exe qui tournent car le prmeiere instance de process java.exe doit etre
      # celle lancée par visitor_bot
      cmd = @@pid.nil? ? "/IM java.exe" : "/PID #{@@pid}"

      #TODO remplacer tasklist par ps pour linux
      res = IO.popen("taskkill #{cmd} /T /F").read
      @@pid = nil
      @@logger.an_event.debug "taskkill for java.exe : <#{res}>"

    end

    def self.tools
      #-----------------------------------------------------------------------------------------------------------
      #charge les param�tres
      #-----------------------------------------------------------------------------------------------------------
      parameters = load_parameters
      launcher_runtime_dir = parameters.launcher_runtime_dir
      launcher_runtime_dir + TOOLS_DIR
    end


  end
end



