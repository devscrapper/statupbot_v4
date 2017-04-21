require 'uri'
require_relative '../../lib/error'

module Pages
  class Link
    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    include Errors

    #----------------------------------------------------------------------------------------------------------------
    # message exception
    #----------------------------------------------------------------------------------------------------------------
    ARGUMENT_UNDEFINE = 400
    LINK_NOT_FIRE = 401
    LINK_NOT_EXIST = 402
    LINK_NOT_CREATE = 403
    #----------------------------------------------------------------------------------------------------------------
    # include class
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    # constant
    #----------------------------------------------------------------------------------------------------------------
    EMPTY = "EMPTY"
    #----------------------------------------------------------------------------------------------------------------
    # variable de class
    #----------------------------------------------------------------------------------------------------------------
    @@logger = nil
    #----------------------------------------------------------------------------------------------------------------
    # attribut
    #----------------------------------------------------------------------------------------------------------------
    attr :uri, #URI object
         :uri_escape, #URI object
         :window_tab,
         :x, :y, # left/top du link
         :width, :height #dimension du link
    attr_accessor :text # le texte du lien
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
    # url,
    # referrer,
    # title,
    # window_tab,
    # links,
    # cookies,
    # duration_search_link=0
    # output
    # LinkError.new(ARGUMENT_UNDEFINE)
    # LinkError.new(ARGUMENT_UNDEFINE)
    #----------------------------------------------------------------------------------------------------------------
    #----------------------------------------------------------------------------------------------------------------
    #
    #----------------------------------------------------------------------------------------------------------------
    def initialize(url, window_tab=EMPTY, text=EMPTY, coords={x: -1, y: -1}, sizes= {height: -1, width: -1})
      @@logger ||= Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

      raise Errors::Error.new(ARGUMENT_UNDEFINE, :values => {:variable => "url"}) if url.nil?

      @window_tab = window_tab
      @text = text
      @x = coords["x"].to_i
      @y = coords["y"].to_i
      @height = sizes["height"].to_i
      @width = sizes["width"].to_i

      begin
        @uri = URI.parse(url)
      rescue Exception => e
        @@logger.an_event.debug "url : #{e.message}"
        @uri = nil
      end

      begin
        @uri_escape = URI.parse(URI.escape(url))

      rescue Exception => e
        @@logger.an_event.debug "url : #{e.message}"
        raise Errors::Error.new(LINK_NOT_CREATE, :values => {:link => url})
      else

      ensure

      end
    end

    def exists?
      count_try = 1
      max_count_try = 10
      found = @element.exists?
      while count_try < max_count_try and !found
        @@logger.an_event.warn "link #{@url} not found, try #{count_try}"
        count_try += 1
        sleep 1
        #TODO controler qu'il ne faut pas utiliser @element.displayed? and @element.enabled?
        found = @element.exists?
      end
      #@element.displayed? and @element.enabled?
      raise Errors::Error.new(LINK_NOT_EXIST, :values => {:link => @text}) unless found
    end

    def url
      @uri == EMPTY ? URI.unescape(@uri_escape.to_s) : @uri.to_s
    end

    def uri
      @uri.nil? ? @uri_escape : @uri
    end

    def url_escape
      @uri_escape.to_s
    end

    #TODO ajouter les coordonnées et le size à lobjet link
    def to_s
      end_col1 = 24
      end_col2 = 39
      end_col3 = 85
      res = ""
      res += "| #{@window_tab[0..end_col1].ljust(end_col1 + 2)}"
      res += "| #{@text.gsub(/[\n\r\t]/, ' ')[0..end_col2].ljust(end_col2 + 2)}"
      res += "| #{url[0..end_col3].ljust(end_col3 + 2)}"
      res += "|\n"
      res
    end
  end
end
