require_relative '../../lib/error'
require_relative '../../lib/os'
require 'yaml'

module Mim
  class BrowserTypes
#----------------------------------------------------------------------------------------------------------------
# include class
#----------------------------------------------------------------------------------------------------------------
    include Errors

#----------------------------------------------------------------------------------------------------------------
# Message exception
#----------------------------------------------------------------------------------------------------------------
    ARGUMENT_NOT_DEFINE = 1100
    BROWSER_TYPE_NOT_DEFINE = 1101
    BROWSER_VERSION_NOT_DEFINE = 1102
    BROWSER_TYPE_EMPTY = 1103
    OS_VERSION_UNKNOWN = 1104
    OS_UNKNOWN = 1105
    BROWSER_TYPE_NOT_PUBLISH = 1106
    BROWSER_TYPE_NOT_CREATE = 1107
    RUNTIME_BROWSER_PATH_NOT_FOUND = 1108
#----------------------------------------------------------------------------------------------------------------
# constants
#----------------------------------------------------------------------------------------------------------------

    BROWSER_TYPE_FILE = [File.dirname(__FILE__), '..', '..', 'repository', 'browser_type.csv']
# plus utilisé
    WIN32_XML = ['config', 'browser_types', 'win32.xml']
    WIN64_XML = ['config', 'browser_types', 'win64.xml']
    LINUX_XML = ['config', 'browser_types', 'linux.xml']
    MAC_XML = ['config', 'browser_types', 'mac.xml']
# remplace les 4 précédents pour statupbot V4
    BROWSER_TYPE_FILE_XML = ['browser_types.xml']

    STAGING = 0
    OPERATING_SYSTEM = 1
    OPERATING_SYSTEM_VERSION = 2
    BROWSER = 3
    BROWSER_VERSION = 4
    RUNTIME_PATH = 5
    PROXY_SYSTEM = 6
    START_LISTENING_PORT_PROXY = 7
    COUNT_PROXY = 8

#----------------------------------------------------------------------------------------------------------------
# attributs
#----------------------------------------------------------------------------------------------------------------
    @@logger = nil
    attr :browsers


#----------------------------------------------------------------------------------------------------------------
# class methods
#----------------------------------------------------------------------------------------------------------------
    def <<(array)
      browser, browser_version, data = array
      @browsers = {browser => {browser_version => data}} if @browsers.nil?
      @browsers[browser] = {browser_version => data} if @browsers[browser].nil?
      @browsers[browser][browser_version] = data if @browsers[browser][browser_version].nil?
    end

    def browser
      browser_arr = []
      @browsers.each_key { |browser| browser_arr << browser }
      browser_arr
    end

    def browser_version(browser)
      browser_version_arr = []
      @browsers[browser].each_key { |browser_version| browser_version_arr << browser_version }
      browser_version_arr
    end


# si trouvé RAS
# si pas trouvé lève une exception : BROWSER_VERSION_NOT_DEFINE
    def self.exist?(browser_types_dir, browser_type)

      raise Error.new(BROWSER_TYPE_NOT_DEFINE,
                      :values => {:path => browser_types_dir + BROWSER_TYPE_FILE_XML}) unless File.exist?(File.join(browser_types_dir, BROWSER_TYPE_FILE_XML))

      @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      found = false
      Nokogiri::XML(File.new(File.join(browser_types_dir + BROWSER_TYPE_FILE_XML)).read).search("//browserTypes/browserType").each { |n|
        if found = browser_type == n.elements[0].inner_text
          break
        end
      }

      unless found
        @@logger.an_event.error "browser types #{browser_type} not exist"
        browser, browser_version, ip, port = browser_type.split(/_/)
        raise Error.new(BROWSER_VERSION_NOT_DEFINE, :values => {:browser => browser, :vrs => browser_version})
      end

      @@logger.an_event.debug "browser types #{browser_type} exist"

    end

    def self.from_csv
      begin
        raise Error.new(BROWSER_TYPE_NOT_DEFINE, :values => {:path => BROWSER_TYPE_FILE}) unless File.exist?(File.join(BROWSER_TYPE_FILE))

        @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

        @@logger.an_event.debug $staging
        @@logger.an_event.debug OS.name
        @@logger.an_event.debug OS.version

        bt = BrowserTypes.new
        #TODO à tester
        rows = CSV.read(File.join(BROWSER_TYPE_FILE))
        rows.each { |row|
          unless row.empty?
            elt_arr = row[0].split(/;/)

            if elt_arr[STAGING] == $staging and
                elt_arr[OPERATING_SYSTEM].to_sym == OS.name and
                elt_arr[OPERATING_SYSTEM_VERSION].to_sym == OS.version

              bt << [elt_arr[BROWSER], elt_arr[BROWSER_VERSION], {
                                         "runtime_path" => elt_arr[RUNTIME_PATH],
                                         "proxy_system" => elt_arr[PROXY_SYSTEM]
                                     }]
            end
          end

        }
      rescue Exception => e
        @@logger.an_event.error "repository file loaded : #{e.message}"
        raise Error.new(BROWSER_TYPE_NOT_CREATE, :error => e)

      else
        @@logger.an_event.debug "repository file loaded"
        bt
      end
    end

    def self.from_xml(browser_types_dir)
      # pas encore utiliser
      begin
        raise Error.new(BROWSER_TYPE_NOT_DEFINE,
                        :values => {:path => BROWSER_TYPE_FILE}) unless File.exist?(File.join(browser_types_dir + BROWSER_TYPE_FILE_XML))

        @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

        bt = BrowserTypes.new
        #TODO à terminer
        Nokogiri::XML(File.new(File.join(browser_types_dir + BROWSER_TYPE_FILE_XML)).read).search("//browserTypes/browserType").each { |n|
          browser_type = n.elements[0].inner_text
          browser, version, ip, port = browser_type.split(/_/)
          bt << [browser,
                 version,
                 {
                     "runtime_path" => n.elements[5].inner_text,
                     "proxy_system" => n.elements[5].inner_text
                 }]
        }

      rescue Exception => e
        @@logger.an_event.error "browsertypes  file loaded : #{e.message}"
        raise Error.new(BROWSER_TYPE_NOT_CREATE, :error => e)

      else
        @@logger.an_event.debug "browsertypes file loaded"
        bt
      end
    end


    def initialize(logger=nil)
      #--------------------------------------------------------------------------------------------------------------
      #--------------------------------------------------------------------------------------------------------------
      # ATTENTION
      #----------
      # la variable Listening port proxy sahi du repository browser_type.csv n'est pas utilisé pour paraméter le
      # browser. Le browser est paramétrer lors du patch du custom_properties du navigateur
      #--------------------------------------------------------------------------------------------------------------
      #--------------------------------------------------------------------------------------------------------------
      @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      @browsers = {}

    end

    def self.process_name(browser_types_dir, browser_type)
      raise Error.new(BROWSER_TYPE_NOT_DEFINE,
                      :values => {:path => browser_types_dir + BROWSER_TYPE_FILE_XML}) unless File.exist?(File.join(browser_types_dir + BROWSER_TYPE_FILE_XML))

      @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      found = false
      process_name = ""
      Nokogiri::XML(File.new(File.join(browser_types_dir + BROWSER_TYPE_FILE_XML)).read).search("//browserTypes/browserType").each { |n|
        if found = browser_type == n.elements[0].inner_text
          process_name = n.elements[5].inner_text
          break
        end
      }

      unless found
        @@logger.an_event.error "browser types #{browser_type} not exist"
        browser, browser_version, ip, port = browser_type.split(/_/)
        raise Error.new(BROWSER_VERSION_NOT_DEFINE, :values => {:browser => browser, :vrs => browser_version})
      end

      @@logger.an_event.debug "browser types #{browser_type} exist"
      process_name
    end

    def proxy_system?(browser, browser_version)
      begin
        @browsers[browser][browser_version]["proxy_system"]=="true"
      rescue Exception => e
        raise Error.new(BROWSER_VERSION_NOT_DEFINE, :values => {:browser => browser, :vrs => browser_version})
      ensure
      end
    end

    def publish_to_sahi(browser_types_dir, booked_port, proxy_ip_list)
      begin
        raise Error.new(BROWSER_TYPE_EMPTY) if @browsers.nil?

        data = <<-_end_of_xml_
<browserTypes>
   #{publish_browsers(booked_port, proxy_ip_list)}
</browserTypes>
        _end_of_xml_
        data

        f = File.new(File.join(browser_types_dir + BROWSER_TYPE_FILE_XML), "w+")
        f.write(data)
        f.close

      rescue Exception => e
        raise Error.new(BROWSER_TYPE_NOT_PUBLISH, :error => e)
      else
      ensure
      end
    end


    def runtime_path(browser, browser_version)
      begin
        @browsers[browser][browser_version]["runtime_path"]
      rescue Exception => e
        raise Error.new(BROWSER_VERSION_NOT_DEFINE, :values => {:browser => browser, :vrs => browser_version})
      ensure
      end
    end

    def to_yaml
      @browsers.to_yaml
    end

#----------------------------------------------------------------------------------------------------------------
# instance methods  private
#----------------------------------------------------------------------------------------------------------------
    private
    def browser_type(name, display_name, icon, path, options, process_name, use_system_proxy)
=begin
            <browserType>
              <name>Internet_Explorer_8.0</name>
              <displayName>IE 8</displayName>
              <icon>ie.png</icon>
              <path>C:\Program Files (x86)\Internet Explorer\iexplore.exe</path>
              <options>-noframemerging</options>
              <processName>iexplore.exe</processName>
              <useSystemProxy>false</useSystemProxy>
              <capacity>1</capacity>
     	        <force>true</force>
            </browserType>

=end
      a = <<-_end_of_xml_
  <browserType>
      <name>#{name}</name>
      <displayName>#{display_name}</displayName>
      <icon>#{icon}</icon>
      <path>#{path}</path>
      <options>#{options}</options>
      <processName>#{process_name}</processName>
      <useSystemProxy>#{use_system_proxy}</useSystemProxy>
      <capacity>1</capacity>
  </browserType>
      _end_of_xml_
      a
    end

    def Internet_Explorer(browser_versions)
      res = ""
      browser_versions.each_pair { |version, details|
        name = "Internet_Explorer_#{version}"
        display_name = "IE #{version}"
        icon = "ie.png"
        unless File.exist?(details["runtime_path"])
          @@logger.an_event.error "runtime browser internet explorer #{version} path <#{details["runtime_path"]}> not found"
          raise Error.new(VisitorFactory::RUNTIME_BROWSER_PATH_NOT_FOUND, :values => {:path => details["runtime_path"]})
        end
        path = details["runtime_path"]
        options = "-noframemerging"
        process_name = "iexplore.exe"
        use_system_proxy = "true"
        res += browser_type(name, display_name, icon, path, options, process_name, use_system_proxy)

      }
      res
    end

    def Firefox(browser_versions, booked_port, proxy_ip_list)
      res = ""
      browser_versions.each_pair { |version, details|
        proxy_ip_list.each { |ip|
          booked_port.each { |port|
            name ="Firefox_#{version}_#{ip}_#{port}"
            use_system_proxy = "false"
            display_name = "Firefox #{version}"
            icon = "firefox.png"
            unless File.exist?(details["runtime_path"])
              @@logger.an_event.error "runtime browser firefox #{version} path <#{details["runtime_path"]}> not found"
              raise Error.new(VisitorFactory::RUNTIME_BROWSER_PATH_NOT_FOUND, :values => {:path => details["runtime_path"]})
            end
            path = details["runtime_path"]
            options = "-profile \"$userDir/browser/ff/profiles\" -no-remote "
            process_name = "firefox.exe"

            res += browser_type(name, display_name, icon, path, options, process_name, use_system_proxy)
          }
        }
      }
      res
    end

    def Chrome(browser_versions, booked_port, proxy_ip_list)
      res = ""
      browser_versions.each_pair { |version, details|
        proxy_ip_list.each { |ip|
          booked_port.each { |port|
            name ="Chrome_#{version}_#{ip}_#{port}"
            use_system_proxy = "false"
            display_name = "Chrome #{version}"
            icon = "chrome.png"
            unless File.exist?(details["runtime_path"])
              @@logger.an_event.error "runtime browser chrome #{version} path <#{details["runtime_path"]}> not found"
              raise Error.new(VisitorFactory::RUNTIME_BROWSER_PATH_NOT_FOUND, :values => {:path => details["runtime_path"]})
            end
            path = details["runtime_path"]
            options = "--user-data-dir=$userDir\\browser\\chrome\\profiles
                --proxy-server=#{ip}:#{port} --disable-popup-blocking --always-authorize-plugins --allow-outdated-plugins --incognito"
            process_name = "chrome.exe"

            res += browser_type(name, display_name, icon, path, options, process_name, use_system_proxy)
          }
        }
      }
      res
    end

    def Safari(browser_versions)
      #appliquer la methode internet explorer
    end

    def Opera(browser_versions)
      # verifier que l'on peut appliquer la methode firefox, sinon sandboxing comme IE
      # <browserType>
      # 	<name>opera</name>
      # 	<displayName>Opera</displayName>
      # 	<icon>opera.png</icon>
      # 	<path>$ProgramFiles\Opera\opera.exe</path>
      # 	<options> </options>
      # 	<processName>opera.exe</processName>
      # 	<useSystemProxy>true</useSystemProxy>
      # 	<capacity>1</capacity>
      # </browserType>
      res = ""
      browser_versions.each_pair { |version, details|
        name ="Opera_#{version}"
        use_system_proxy = "true"
        display_name = "Opera #{version}"
        icon = "opera.png"
        unless File.exist?(details["runtime_path"])
          @@logger.an_event.error "runtime browser opera #{version} path <#{details["runtime_path"]}> not found"
          raise Error.new(VisitorFactory::RUNTIME_BROWSER_PATH_NOT_FOUND, :values => {:path => details["runtime_path"]})
        end
        path = details["runtime_path"]
        options = ""
        process_name = "opera.exe"

        res += browser_type(name, display_name, icon, path, options, process_name, use_system_proxy)
      }
      res
    end

    def Edge(browser_versions)
=begin
      <browserType>
      <name>edge</name>
             <displayName>MS Edge</ displayName>
      <icon>edge.png</icon>
             <path>$userDir\bin\launch_edge.bat</ path>
      <options></options>
            	<processName>MicrosoftEdge.exe</ processName>
      <useSystemProxy>true</useSystemProxy>
            	<capacity>1</ capacity>
      <force>true</force>
         </ browserType>
=end

      a = <<-_end_of_xml_
  <browserType>
      <name>Edge</name>
      <displayName>MS Edge</displayName>
      <icon>edge.png</icon>
      <path>$userDir\\bin\\launch_edge.bat</path>
      <options></options>
      <processName>MicrosoftEdge.exe</processName>
      <useSystemProxy>true</useSystemProxy>
      <capacity>1</capacity>
      <force>true</force>
  </browserType>
      _end_of_xml_
      a
    end

    def publish_browsers(booked_port, proxy_ip_list)
      res = ""
      @browsers.each { |browser|
        case browser[0]
          when "Internet Explorer"
            res += Internet_Explorer(browser[1])
          when "Firefox"
            res += Firefox(browser[1], booked_port, proxy_ip_list)
          when "Chrome"
            res += Chrome(browser[1], booked_port, proxy_ip_list)
          when "Opera"
            res += Opera(browser[1])
          when "Edge"
            res += Edge(browser[1])
        end
      } unless @browsers.nil?
      res
    end

  end
end

