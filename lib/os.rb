require 'singleton'
require 'yaml'
class OS

  #--------------------------------------------------------------------------------------------------------------------
  # INIT
  #--------------------------------------------------------------------------------------------------------------------
  ENVIRONMENT= File.join(File.dirname(__FILE__), '..', 'parameter', 'environment.yml')

  attr :name, :version
  #----------------------------------------------------------------------------------------------------------------
  # class methods
  #----------------------------------------------------------------------------------------------------------------
  def self.detect
    begin
      environment = YAML::load(File.open(ENVIRONMENT), "r:UTF-8")
      @name = environment["os"] unless environment["os"].nil?
      @version = environment["os_version"] unless environment["os_version"].nil?
    rescue Exception => e
      $stderr << "loading parameter file #{ENVIRONMENT} failed : #{e.message}" << "\n"
    end
  end
  def self.dump
    Marshal.dump(self)
  #  Marshal.dump(@version, depth)
  end

  def self.load(str)
    Marshal.load(str)
  end

  #----------------------------------------------------------------------------------------------------------------
  # instance methods
  #----------------------------------------------------------------------------------------------------------------


  def self.name
    detect if @name.nil?
    @name
  end

  def self.version
    detect if @version.nil?
    @version
  end

  def self.windows?
    detect if @name.nil?
    @name == :windows
  end

  def self.linux?
    detect if @name.nil?
    @name == :linux
  end

  def self.mac?
    detect if @name.nil?
    @name == :mac
  end

  def self.xp?
    detect if @version.nil?
    @version == :xp
  end

  def self.vista?
    detect if @version.nil?
    @version == :vista
  end

  def self.seven?
    detect if @version.nil?
    @version == :seven
  end

  def self.height?
    detect if @version.nil?
    @version == :height
  end

end