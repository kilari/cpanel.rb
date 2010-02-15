begin
  require 'rubygems'
  require 'json'
  require 'hpricot'
  require 'net/https'
rescue LoadError
  abort "Could not load json/hpricot gem(s). Check if they are installed."
end

require 'cpanel_api/cpanel_db_util'
require 'cpanel_api/cpanel_domain_util'

module CpanelAPI
  include CpanelDbUtil
  include CpanelDomainUtil
  
  attr_reader :cpanel_user,:cpanel_pass,:domain,:port
  
  def initialize(cpanel_user, cpanel_pass, domain, port=2083)
    @cpanel_user = cpanel_user
    @cpanel_pass = cpanel_pass
    @port = port
    @domain = domain
    @connection = Net::HTTP.new(@domain,@port)
    @connection.use_ssl = true if @port == 2083 
  end
  
  def get(path)
    req = Net::HTTP::Get.new(path)
    req.basic_auth @cpanel_user, @cpanel_pass
    res = @connection.request(req)
    if res.code == '200'
      res
    else
      raise LoginCredentialsError, res.message
    end
  end
  
  def post(path,data,theme='x3')
    req = Net::HTTP::Post.new("/frontend/x3/#{path}") if theme == 'x3'
    req.basic_auth @cpanel_user, @cpanel_pass
    req.set_form_data(data)
    res = @connection.request(req)
    if res.code == '200'
      res
    else
      raise LoginCredentialsError, res.message
    end
  end
  
  def random(n=20)
    key = ''
    char = ('a'..'z').to_a
    1.upto(n){key << char[rand(char.size-1)]}
    key
  end
  
  def json_url(cpanel_user,module_name,func_name,options='')
    options.insert(0,'&') unless options == ''
    "/json-api/cpanel?user=#{cpanel_user}&cpanel_jsonapi_module=#{module_name}&cpanel_jsonapi_func=#{func_name}#{options}"
  end
  
  def return_msg(status,msg,options={})
    unless options.empty?
      {:status => "#{status}", :message => "#{msg}"}.merge(options)
    else
      {:status => "#{status}", :message => "#{msg}"}
    end
  end
  
  def parseAndFormatReply(reply)
    parsed = JSON.parse(reply.body)
    parsed['cpanelresult']['data']
  end
  
  class DbNameSizeError < StandardError;end
    
  class UserNameSizeError < StandardError;end
    
  class LoginCredentialsError < StandardError;end
    
  class NameAlreadyExistsError < StandardError;end
   
  class NameFormatError < StandardError;end  
    
  class UserNotFoundError < StandardError;end
    
  class DbNotFoundError < StandardError;end  
  
  private :get, :post, :random, :json_url, :return_msg, :parseAndFormatReply
    
end

