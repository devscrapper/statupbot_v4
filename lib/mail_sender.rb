#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'yaml'
require 'pony'
require_relative 'parameter'

class MailSender


  attr :address,
       :port,
       :user_name,
       :password,
       :from,
       :to,
       :subject,
       :body,
       :domain,
       :authentification

  def initialize(from = "mail@localhost.fr", to, subject, body)
    raise ArgumentError, "to is undefine" if  to.nil?
    raise ArgumentError, "subject is undefine" if  subject.nil?
    raise ArgumentError, "body is undefine" if  body.nil?
    @from = from
    @to = to
    @subject = subject
    @body = body

    begin
      parameters = Parameter.new(__FILE__)
    rescue Exception => e
      $stderr << e.message << "\n"
    else
      @address = parameters.address
      @port = parameters.port
      @user_name = parameters.user_name
      @password = parameters.password
      @domain = parameters.domain
      @authentification = parameters.authentification
      raise ArgumentError, "parameter <address> is undefine" if  @address.nil?
      raise ArgumentError, "parameter <user_name> is undefine" if  @user_name.nil?
      raise ArgumentError, "parameter <password> is undefine" if  @password.nil?
      raise ArgumentError, "parameter <port> is undefine" if  @port.nil?
      raise ArgumentError, "parameter <domain> is undefine" if  @domain.nil?
      raise ArgumentError, "parameter <authentification> is undefine" if  @authentification.nil?
    end
  end

  def send_html
    send_mail({:html_body => @body})
  end

  def send
    send_mail({:body => @body})
  end

  private

  def send_mail(options)
    begin
      Pony.mail({:to => @to,
                 :via => :smtp,
                 :from => @from,
                 :subject => @subject,
                 :via_options => {
                     :address => @address,
                     :port => @port,
                     :user_name => @user_name,
                     :password => @password,
                     :authentication => @authentification, # :plain, :login, :cram_md5, no auth by default
                     :domain => @domain # the HELO domain provided by the client to the server
                 }
                }.merge!(options))
    rescue Exception => e
      $stderr << "mail to #{@to} about #{@subject} not send : #{e.message}"  << "\n"
    else
      $stdout << "mail to #{@to} about #{@subject} send"  << "\n"
    ensure

    end
  end

  def to_s
    "from <#{@from}>\n" +
        "to <#{@to}>\n" +
        "subject <#{@subject}>\n" +
        "body <#{@body}>\n" +
        "smtp <#{@address}>\n" +
        "port <#{@port}>\n"
  end
end