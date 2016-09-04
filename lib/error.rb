require_relative 'message'
module Errors
  #-----------------------------------------------------------------------------------------------------------------
  # error range
  #-----------------------------------------------------------------------------------------------------------------
  # proxy.rb          | 100 - ...
  # driver.rb         | 200 - ...
  # browser.rb        | 300 - ...
  # link.rb           | 400 - ...
  # page.rb           | 500 - ...
  # visitor.rb        | 600 - ...
  # visit.rb          | 700 - ...
  # referrer.rb       | 800 - ...
  # engine_search.rb  | 900 - ...
  # visitor_factory   | 1000 - ...
  # browser_type.rb   | 1100 - ...
  #-------------------------------------------------------------------------------------------------------------------

  class Error < StandardError
    attr_accessor :code,
                  :origin_code,
                  :lib,
                  :origin_lib,
                  :history

    def initialize(code, args={})
      values = args.fetch(:values, nil)
      error = args.fetch(:error, nil)

      @code = code
      @lib = Messages.instance[@code, values] unless values.nil?
      @lib = Messages.instance[@code] if values.nil?


      unless error.nil?
        if  error.is_a?(Error)
          @origin_code = error.origin_code ? error.origin_code : error.code
          @origin_lib =error.origin_lib ? error.origin_lib : error.lib
          @history = Array.new(error.history)
        else
          @origin_code = -1
          @origin_lib = error.message
        end
      end

      @history = @history.nil? ? [code] : @history << code
    end

    def to_s
      if @origin_code.nil?
        to_s = "exception #{self.class} code #{@code} : #{@lib}"
      else
        to_s = "exception #{self.class} code #{@code} : #{@lib}, origin_code #{@origin_lib}, history #{@history}"
      end
      to_s
    end


  end
end