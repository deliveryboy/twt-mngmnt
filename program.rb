#!/usr/bin/ruby 

# Description: Managing mails @ TwwoIT
# Author: Markus Kwaśnicki
# Date: 2011-02-23

require 'rubygems'
gem 'soap4r'
require 'faker'
require 'optparse'
require 'pp'
require 'soap/rpc/driver'
require 'yaml'
require 'net/https'
require 'nokogiri'

class CookieAuthError < StandardError
  def initialize
    super('Cookie has expired')
  end
end

# Class implementing SOAP methods to be used for mails @ TwooIT
# https://ssl.twooit.com/helpdesk/index.php?title=SOAP-API_zum_Webinterface
#
# Keys for eMail
# * email: die E-Mail-Adresse
# * type: der Typ der E-Mail-Adresse
#   o MB: Postfach
#   o MBFWD: Postfach mit Weiterleitung
#   o FWD: Weiterleitung 
# * passwd: das Passwort
# * targets: E-Mail-Adressen, an die weitergeleitet wird, durch Leerzeichen getrennt
# * active: 1 um die E-Mail-Adresse zu aktivieren, 0 um sie zu deaktivieren 
#
# Keys for domain
# * name: Name der Domain
# * registrarStatus: Status der Domain beim Registrar (1000 = OK)
# * registratAuthCode: der AuthCode der Domain
# * regType: transfer um eine Domain zu registrieren, Standard ist register
# * refIdContact*: Kontakt-Ids der Domain, Contacts in der API
# * webIp: IP-Adresse des Webservers
# * mailIp: IP-Adresse des Mailservers 
#
# The following exceptions may occurr:
# * SOAP-Fehler 9900: Die Authentifizierung ist fehlgeschlagen
# * SOAP-Fehler 9901: Beim übergebenen data Array ist eine Prüfung fehlgeschlagen: Es wurde z.B. ein falscher Wert übermittelt
# * SOAP-Fehler 9902: Der Datensatz konnte nicht bearbeitet werden: Der Benutzer besitzt z.B. zu wenig Rechte
# * SOAP-Fehler 9903: Fehler innerhalb der Funktion, z.B. bei Domainregistrierung fehlerhafte Rückmeldung des Registrars 
class TwtMail
  public
    # Action constants
    TWT_NONE                        = 0
    TWT_GETEMAILADDRESS             = 1
    TWT_INSTALLEMAILADDRESS         = 2
    TWT_UPDATEEMAILADDRESS          = 4
    TWT_DELETEEMAILADDRESS          = 8
    TWT_TESTEMAILADDRESS            = 16
    TWT_GETDOMAIN                   = 32
    TWT_UPDATEDOMAIN                = 64
    TWT_REGISTERDOMAIN              = 128
    TWT_GETEMAILADDRESSESFROMDOMAIN = 256
    TWT_GETDOMAINLIST               = 512
    
    # Which action was fired last?
    @@last_action = TWT_NONE
    
    def self.last_action 
      @@last_action
    end
  
    def self.last_action= action
      @@last_action = action
    end
    # --

    # Requires YAML document with TwooIT SAOP data
    def initialize data
      uri = data['TwooIT']['SOAP']['uri']
      namespace = data['TwooIT']['SOAP']['namespace']
      soapaction = data['TwooIT']['SOAP']['soapaction']
      username = data['TwooIT']['SOAP']['username']
      password = data['TwooIT']['SOAP']['password']
    
      @driver = SOAP::RPC::Driver.new(uri, namespace, soapaction)
    
      # 1st SOAP parameter
      @auth = {
        'username' => username, 
        'passwd' => password
      }
    end
  
    # Retrieve information about the give eMail address
    def get_email_address email
      # 2nd SOAP parameter
      data = {
        'email' => email
      }

      # Preparing SOAP method to be fired
      @driver.add_method(
        'twtGetEmailAddress', 
        'auth',
        'data'       
      )
    
      # Fire!!1
      result = @driver.twtGetEmailAddress(@auth, data)
    end
    
    # @param type One of the following as string: MB => Mailbox, MBFWD => Mailbox and Forwarding, FWD => Forwarding
    # @param status One of the following as integer: 0 => inactive, 1 => active
    # @param targets Whitespace separated list of email addresses to be forwarded to automatically
    # Known bug: Newly installed email address always has status 1
    def install_email_address email, type, password, status, targets
      data = {
        'email' => email,
        'type' => type, # enum:MB,MBFWD,FWD
        'passwd' => password,
        'targets' => targets,  
        'active' => status
      }
      
      @driver.add_method(
        'twtInstallEmailAddress', 
        'auth',
        'data'       
      )
    
      result = @driver.twtInstallEmailAddress(@auth, data)
    end

    def update_email_address email, type, password, status, targets
      data = {
        'email' => email,
        'type' => type, 
        'passwd' => password,
        'targets' => targets,  
        'active' => status
      }

      @driver.add_method(
        'twtUpdateEmailAddress', 
        'auth',
        'data'       
      )
    
      result = @driver.twtUpdateEmailAddress(@auth, data)
    end

    # @return Returns 1 on success
    def delete_email_address email
      data = {
        'email' => email,
      }

      @driver.add_method(
        'twtDeleteEmailAddress', 
        'auth',
        'data'       
      )
    
      result = @driver.twtDeleteEmailAddress(@auth, data)
    end

    # Tests will be ran to test the following functionality
    # 1. Install new email address
    # 2. Update installed email address
    # 3. Delete installed email address
    def test_email_address
      # Initial values
      email = "#{Faker::Name.first_name.downcase}.#{Faker::Name.last_name.downcase}@clubrauscher.com"
      type = 'MB'
      password = Faker::PhoneNumber.phone_number  # Using phone number for password because it contains special characters also
      status = 0

      pp install_email_address email, type, password, status

      # Updated values
      password = Faker::PhoneNumber.phone_number
      status = 0

      pp update_email_address email, type, password, status

      # Delete email address
      pp delete_email_address email
    end

    def get_domain name
      data = {
        'name' => name
      }
      
      @driver.add_method(
        'twtGetDomain', 
        'auth',
        'data'       
      )
    
      result = @driver.twtGetDomain(@auth, data)
    end
    
    def update_domain 
      data = {
      }
      
      @driver.add_method(
        'twtUpdateDomain', 
        'auth',
        'data'       
      )
    
      result = @driver.twtUpdateDomain(@auth, data)
    end
    
    def register_domain name, ref_id_contact_owner, ref_id_contact_admin, web_ip, mail_ip
      data = {
        'name' => name, 
        'refIdContactOwner' => ref_id_contact_owner, 
        'refIdContactAdmin' => ref_id_contact_admin, 
        'webIp' => web_ip, 
        'mailIp' => mail_ip
      }
      
      @driver.add_method(
        'twtRegisterDomain', 
        'auth',
        'data'       
      )
    
      result = @driver.twtRegisterDomain(@auth, data)
    end
    
    def get_email_addresses_from_domain wanted_domain
      STDERR.print "Looking for domain #{wanted_domain}..."
      domain_id = get_domain_id wanted_domain
      domain_id.nil? ? (STDERR.puts('not found!'); return) : STDERR.puts('found!')
      
      begin
        first_page = Nokogiri::HTML(fetch_twt_content(URI.parse("https://ssl.twooit.com/interface/loggedSts.php?c=twtEmailAddress&refIdDomain=#{domain_id}&p=0")))
        pages = first_page.css('div.pagination ul li a')
        tmp = Array.new
        pages.map {|p| tmp << p if p.css('span').count == 0}
        pages = tmp # From Nokogiri::XML::NodeSet to Array
        raise Exception, 'Could not load domain pages' if pages.count == 0
      
        get_email first_page
        for i in 1..pages.count-1 do
          page = Nokogiri::HTML(fetch_twt_content(URI.parse("https://ssl.twooit.com/interface/loggedSts.php?c=twtEmailAddress&refIdDomain=#{domain_id}&p=#{i}")))
          get_email page
        end
      rescue Exception => exception
        raise exception
      end
    end
    
    def get_email page
      page.css('tbody[data-provides="rowlink"] tr.rowlink').each do |row|
        tds = row.css('td')
        email_address = tds[0].content.strip
        email_address_id = tds.css('li a').first.attr('href').strip.split(/=/).last rescue nil
        puts "#{email_address_id}\t#{email_address}"
      end
    end
    
    def get_domain_list
      begin
        cookie_auth
        
        document = Nokogiri::HTML(fetch_twt_content(URI.parse('https://ssl.twooit.com/interface/loggedSts.php?c=twtDomain&p=0&sc=&s=')))
        pages = document.css('div#pagetext').first.content.strip.split(/\s/).last.to_i  # Assuming there is only one element returned
        raise CookieAuthError unless pages
        
        print_domain_list document
        for i in 1..pages do
          document = Nokogiri::HTML(fetch_twt_content(URI.parse("https://ssl.twooit.com/interface/loggedSts.php?c=twtDomain&p=#{i}&sc=&s=")))
          print_domain_list document
        end
      rescue CookieAuthError => error
        remove_expired_cookie
        get_domain_list
      rescue Exception => exception
        raise exception
      end
    end
  private
    @auth = nil
    @driver = nil
    
    def cookie_auth
      begin
        # Read stored cookie
        @auth[:cookie] = File.read(File.join(ENV['TMPDIR'], 'twt_cookie.txt'))
      rescue 
        # Request login and retrieve cookie
        uri = URI.parse 'https://ssl.twooit.com/login.php'  # Old URI: https://ssl.twooit.com/interface/loginNew.php
        data = "username=#{@auth['username']}&passwd=#{@auth['passwd']}"
        header = {
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
        
        request = Net::HTTP.new uri.host, uri.port
        request.use_ssl = true
        request.verify_mode =  OpenSSL::SSL::VERIFY_NONE
        
        response = request.post uri.path, data, header
        cookie = response['set-cookie']
        @auth[:cookie] = cookie
        
        tmp = File.new(File.join(ENV['TMPDIR'], 'twt_cookie.txt'), 'w')
        tmp.write cookie
        tmp.close
      end
    end
    
    def remove_expired_cookie
      cookie = File.new(File.join(ENV['TMPDIR'], 'twt_cookie.txt'))
      File.unlink(cookie.path)
    end
    
    def print_email_list document
      document.css('div.dojoxGridRow').each do |row|
        domain_id = row.css('td')[4].css('a').attr('href').content.strip.split(/=/).last rescue nil
        domain = row.css('td').first.content.strip
        puts "#{domain_id}\t#{domain}"
      end
    end

    def fetch_twt_content uri
      # Request logged in data and send authentication cookie
      header = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Cookie' => @auth[:cookie]
      }
    
      request = Net::HTTP.new uri.host, uri.port
      request.use_ssl = true
      request.verify_mode =  OpenSSL::SSL::VERIFY_NONE
    
      response = request.post "#{uri.path}?#{uri.query}", nil, header
      return response.body
    end
    
    def print_domain_list document
      document.css('div.dojoxGridRow').each do |row|
        domain_id = row.css('td')[4].css('a').attr('href').content.strip.split(/=/).last rescue nil
        domain = row.css('td').first.content.strip
        puts "#{domain_id}\t#{domain}"
      end
    end
    
    def get_domain_id wanted_domain
      begin
        cookie_auth
        
        first_page = Nokogiri::HTML(fetch_twt_content(URI.parse('https://ssl.twooit.com/interface/loggedSts?c=twtDomain&p=0')))
        pages = first_page.css('div.pagination ul li a')
        tmp = Array.new
        pages.map {|p| tmp << p if p.css('span').count == 0}
        pages = tmp # From Nokogiri::XML::NodeSet to Array
        raise Exception, 'Could not load domain pages' if pages.count == 0
        
        domain_id = find_domain_id(first_page, wanted_domain)
        return domain_id unless domain_id.nil?
        
        for i in 1..pages.count-1 do  # Skip first page as it was evaluated before
          page = Nokogiri::HTML(fetch_twt_content(URI.parse("https://ssl.twooit.com/interface/loggedSts.php?c=twtDomain&p=#{i}")))
          
          domain_id = find_domain_id(page, wanted_domain)
          return domain_id unless domain_id.nil?
        end
      rescue CookieAuthError => error
        remove_expired_cookie
        get_domain_id wanted_domain
      rescue Exception => exception
        raise exception
      end
      
      return nil
    end
    
    def find_domain_id page, wanted_domain
      page.css('tbody[data-provides="rowlink"] tr.rowlink').each do |row|
        tds = row.css('td')
        domain = tds[1].content.strip
        domain_id = tds.css('li a').first.attr('href').strip.split(/=/).last rescue nil
        
        if wanted_domain == domain
          return domain_id
        else
          STDERR.print '.'
          STDERR.flush
          sleep 0.0625
        end          
      end
      return nil
    end
end
# End of Class


# Here we go
if __FILE__ == $0 then
  # Parsing command line arguments to options
  options = OptionParser.new do |options|
		options.banner = "Usage: #{File.basename $0} [options] [arguments]"
		options.on('-e', '--mails', '<domain>', 'List existing mails of domain') do
		  TwtMail.last_action = TwtMail::TWT_GETEMAILADDRESSESFROMDOMAIN
		end
		options.on('-l', '--list', '<mail address>', 'List information about existing mail address') do
		  TwtMail.last_action = TwtMail::TWT_GETEMAILADDRESS
		end
		options.on('-i', '--install', '<mail address> <type> <password> <status> <targets>', 'Create new mail address') do
		  TwtMail.last_action = TwtMail::TWT_INSTALLEMAILADDRESS
		end
		options.on('-u', '--update', '<mail address> <type> <password> <status> <targets>', 'Update mail address') do
		  TwtMail.last_action = TwtMail::TWT_UPDATEEMAILADDRESS
		end
		options.on('-d', '--delete', '<mail address>', 'Delete mail address') do
		  TwtMail.last_action = TwtMail::TWT_DELETEEMAILADDRESS
		end
    # options.on('-t', '--test', 'Run test to check functionality') do
    #   TwtMail.last_action = TwtMail::TWT_TESTEMAILADDRESS
    # end
    options.on('--list-domains', 'List all registered domains with its ID') do
		  TwtMail.last_action = TwtMail::TWT_GETDOMAINLIST
		end
		options.on('--list-domain', '<domain>', 'List information about existing domain') do
		  TwtMail.last_action = TwtMail::TWT_GETDOMAIN
		end
		options.on_tail('-h', '--help', 'Print this message and exit') do
		  TwtMail.last_action = TwtMail::TWT_NONE
		  raise OptionParser::InvalidOption
		end
	end

	begin
		options.parse!(ARGV)
	rescue OptionParser::InvalidOption
		puts options
		exit 1
	end
	# --

  # Exception handling for SOAP actions
  begin
    twt_mail = TwtMail.new(data = YAML.load(DATA))
    
    case TwtMail.last_action
      when TwtMail::TWT_GETDOMAINLIST
        twt_mail.get_domain_list
      when TwtMail::TWT_GETEMAILADDRESSESFROMDOMAIN
        raise ArgumentError if  ARGV[0].nil?
        twt_mail.get_email_addresses_from_domain ARGV[0]
      when TwtMail::TWT_GETEMAILADDRESS
        raise ArgumentError if  ARGV[0].nil?
        pp twt_mail.get_email_address ARGV[0]
      when TwtMail::TWT_INSTALLEMAILADDRESS
        raise ArgumentError if  ARGV[0].nil? or ARGV[1].nil? or ARGV[2].nil? or ARGV[3].nil? or ARGV[4].nil?
        pp twt_mail.install_email_address ARGV[0], ARGV[1], ARGV[2], ARGV[3], ARGV[4]
      when TwtMail::TWT_UPDATEEMAILADDRESS
        raise ArgumentError if  ARGV[0].nil? or ARGV[1].nil? or ARGV[2].nil? or ARGV[3].nil? or ARGV[4].nil?
        pp twt_mail.update_email_address ARGV[0], ARGV[1], ARGV[2], ARGV[3], ARGV[4]
      when TwtMail::TWT_DELETEEMAILADDRESS
        raise ArgumentError if  ARGV[0].nil? 
        pp twt_mail.delete_email_address ARGV[0]
      when TwtMail::TWT_TESTEMAILADDRESS
        pp twt_mail.test_email_address
      when TwtMail::TWT_GETDOMAIN
        raise ArgumentError if  ARGV[0].nil?
        pp twt_mail.get_domain ARGV[0]
      else
        raise ArgumentError
    end
  rescue SOAP::FaultError => exception
    puts "#{exception.faultcode}\t#{exception.faultstring}"
  rescue ArgumentError => exception
    puts options
    exit 2
  end
end


# Dead End
__END__
---
TwooIT:
  SOAP:
    uri: "http://api.twooit.com/twtApi.php"
    namespace: "urn:xmethods"
    soapaction: "urn:xmethods"
    username: ""
    password: ""
