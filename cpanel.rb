begin
  require 'rubygems'
  require 'json'
  require 'hpricot'
  require 'net/https'
rescue LoadError
  abort "Could not load json/hpricot gem(s). Check if they are installed."
end

module CpanelAPI
    
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
      raise res.message
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
      raise res.message
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
  
  private :get, :post, :random, :json_url, :return_msg, :parseAndFormatReply
    
  module CpanelDbUtil
  
    attr_reader :db_file_name, :db_type
   
    def db_type=(db_type)
      @db_type=db_type.to_sym
      @db_file_name ={:create_db => {:mysql => 'sql/addb.html',:psql => 'psql/addbs.html'}, :create_user => {:mysql => 'sql/adduser.html',:psql => 'psql/addusers.html'}, :assign_user2db => {:mysql => 'sql/addusertodb.html',:psql => 'psql/addusertodb.html'}, :del_db => {:mysql => 'sql/deldb.html', :psql => 'psql/deldb.html'}, :del_user => {:mysql => 'sql/deluser.html', :psql => 'psql/deluser.html'}, :api => {:mysql => 'MysqlFE', :psql => 'Postgres'} }
    end
  
    def list_dbs
      url = json_url(@cpanel_user,@db_file_name[:api][@db_type],'listdbs')
      reply = get(url)
      db_data = parseAndFormatReply(reply)
      db_list = []
      db_data.each{|x| db_list<< x['db']}
      db_list
    end

    alias list_db list_dbs
     
    def list_db_users
      url = json_url(@cpanel_user,@db_file_name[:api][@db_type],'listusers')
      reply = get(url)
      db_data = parseAndFormatReply(reply)
      db_users = []
      db_data.each{|x| db_users<< x['user']}
      db_users
    end
  
    def list_db_priv(db)
      db = add_cpanel_user_name(db)
      url = json_url(@cpanel_user,@db_file_name[:api][@db_type],'listusersindb',"db=#{db}")
      reply = get(url)
      db_data = parseAndFormatReply(reply)
      db_users = []
      db_data.each{|x| db_users<< x['user']}
      db_users
    end

    alias list_db_privs list_db_priv
  
    def create_db(db_name)
      db_name = remove_cpanel_user_name(db_name)
      full_db_name = add_cpanel_user_name(db_name)
      unless db_name.size > 16 || db_name.size == 0
        if list_dbs.include? full_db_name
          return_msg(false, "DB #{full_db_name} already exists")
        else
          return return_msg(false,'DB name should only be alphanumeric') unless /^[A-Za-z0-9]*$/ =~ db_name
          doc = Hpricot(post(@db_file_name[:create_db][@db_type],{:db => "#{db_name}"}).body) ##To grab any other type of errors like limit exceeded
          error = doc/"p.errors"
          if error.size == 0
            return_msg(true, "DB #{full_db_name} created successfully",:db => "#{full_db_name}")
          else
            error_msg = doc/"div.details"
            error_msg = error_msg.to_s.to_a
            return_msg(false, "Could not create the DB for the reason: #{error_msg[1].strip!}")
          end  
        end
      else
        if db_name.size > 16
          return_msg(false, "The DB name should be 16 characters max!!")
        elsif db_name.size == 0
          return_msg(false, "The DB name can not be left blank!!")
        end
      end  
    end

    def create_db_user(db_user,pass=random)
      db_user = remove_cpanel_user_name(db_user)
      full_db_user = add_cpanel_user_name(db_user)
      unless db_user.size > 7 || db_user.size == 0
        if list_db_users.include?(full_db_user) && current_method == 'create_db_user'
          return_msg(false, "User #{full_db_user} already exists")
        else
          return return_msg(false, 'Username should only be alphanumeric') unless /^[A-Za-z0-9]*$/ =~ db_user
          if list_db_users.include?(full_db_user) && current_method == 'reset_user_pass'
            post(@db_file_name[:create_user][@db_type],{:user => "#{db_user}",:pass => "#{pass}", :pass2 => "#{pass}"})
            return return_msg(true,"Password for the database user #{full_db_user} has been reset to #{pass}",{:user => "#{full_db_user}",:pass => "#{pass}"})
          elsif current_method == 'reset_user_pass'
            return return_msg(false, "Could not find the DB user #{full_db_user}")
          end  
          if current_method == 'create_db_user'
            post(@db_file_name[:create_user][@db_type],{:user => "#{db_user}",:pass => "#{pass}", :pass2 => "#{pass}"})
            return_msg(true, "Added a database user #{full_db_user} with password #{pass}",{:user => "#{full_db_user}",:pass => "#{pass}"})
          end  
        end  
      else
        if db_user.size > 7
          return_msg(false, "The DB Username should be seven characters max!!")
        elsif db_user.size == 0
          return_msg(false, "The DB Username can not be left blank")
        end
      end
    end
  
    alias reset_user_pass create_db_user
  
    def assign_user2db(db_name,db_user)
      db_name = add_cpanel_user_name(db_name)
      db_user = add_cpanel_user_name(db_user)
      if list_dbs.include?(db_name) && list_db_users.include?(db_user)
        post(@db_file_name[:assign_user2db][@db_type], {:db => "#{db_name}", :user => "#{db_user}",'ALL' => 'ALL'})
        if list_db_priv(db_name).include? db_user
          return_msg(true, "Added DB user #{db_user} to the DB #{db_name}",{:user => "#{db_user}",:db => "#{db_name}"})
        else
          return_msg(false, "Could not add the user #{db_user} to the DB #{db_name}")
        end
      else
        if !list_dbs.include?(db_name)
          return_msg(false, "Could not find the DB #{db_name}")
        elsif !list_db_users.include?(db_user)
          return_msg(false, "Could not find the DB user #{db_user}")
        end
      end  
    end

    def is_db?(db_name)
      list_dbs.include? add_cpanel_user_name(db_name)
    end

    def is_db_user?(db_user,db_name)
      list_db_priv(db_name).include? add_cpanel_user_name(db_user)
    end

    def del_db(db_name)
      db_name = add_cpanel_user_name(db_name)
      if list_dbs.include? db_name
        post(@db_file_name[:del_db][@db_type],{:db => "#{db_name}"})
        return_msg(true, "Deleted DB #{db_name}")
      else
        return_msg(false, "Could not find DB #{db_name}")
      end
    end
  
    def del_user(user)
      user = add_cpanel_user_name(user)
      if list_db_users.include? user
        post(@db_file_name[:del_user][@db_type],{:user => "#{user}"})
        return_msg(true, "Deleted DB user #{user}")
      else
        return_msg(false, "Could not find DB user #{user}")
      end
    end
  
    def remove_cpanel_user_name(name)
      unless name.scan(/^#{@cpanel_user}_/).empty?
        name.split(/#{@cpanel_user}_/)[1] 
      else
        name
      end
    end
  
    def add_cpanel_user_name(name)
      unless name.scan(/^#{@cpanel_user}_/).empty?
        name
      else
        name_dup = name.dup
        name_dup.insert(0,"#{@cpanel_user}_")
      end
    end
  
  
    private :remove_cpanel_user_name, :add_cpanel_user_name
  
  end  
    
  module CpanelDomainUtil
  
    def list_domains
      #parked domains, addon domains, and main domains
      url = json_url(@cpanel_user,'DomainLookup','getbasedomains')
      reply = get(url)
      data = parseAndFormatReply(reply)
      list = []
      data.each{|x| list<<x['domain']}
      list
    end
  
    def get_doc_root(domain)
      url = json_url(@cpanel_user,'DomainLookup','getdocroot',"domain=#{domain}")
      reply = get(url)
      data = parseAndFormatReply(reply)
      data[0]['docroot']
    end
  
    def list_park_domains
      url = json_url(@cpanel_user,'Park','listparkeddomains')
      reply = get(url)
      data = parseAndFormatReply(reply)
      list = []
      data.each{|x| list<<x['domain']}
      list
    end
  
    def list_addon_domains
      url = json_url(@cpanel_user,'AddonDomain','listaddondomains')
      reply = get(url)
      data = parseAndFormatReply(reply)
      list = []
      data.each{|x| list<<x['domain']}
      list
    end
  
    def list_sub_domains
      url = json_url(@cpanel_user,'SubDomain','listsubdomains')
      reply = get(url)
      data = parseAndFormatReply(reply)
      list = []
      data.each{|x| list<<x['domain']}
      list
    end
  
    def main_domain
      all = list_domains
      park_dom = list_park_domains
      addon_dom = list_addon_domains
      (all-(park_dom + addon_dom))[0]  
    end
  
    def is_park_domain?(domain)
      list_park_domains.include? scan_domain_name(domain)
    end
  
    def is_addon_domain?(domain)
      list_addon_domains.include? scan_domain_name(domain)
    end
  
    def is_sub_domain?(domain)
      list_sub_domains.include? scan_domain_name(domain)
    end
  
    def is_main_domain?(domain)
      main_domain == scan_domain_name(domain)
    end
  
    def park_domain(domain)
      domain = scan_domain_name(domain)
      unless is_park_domain?(domain)
        url = json_url(@cpanel_user,'Park','park',"domain=#{domain}")
        reply = get(url)
        data = parseAndFormatReply(reply)
        if data[0]['result'] == 1
          return_msg(true,data[0]['reason'],:domain_name => "#{domain}")
        else
          return_msg(false,data[0]['reason'],:domain_name => "#{domain}")
        end
      else
        return_msg(false,"Domain #{domain} already parked",:domain_name => "#{domain}")
      end  
      rescue Timeout::Error
        if is_addon_domain? domain
          return_msg(true,"Domain #{domain} parked successfully",:domain_name => "#{domain}")
        else
          return_msg(false,"Could not park the domain #{domain},Try again",:domain_name => "#{domain}")
        end
    end
  
    def add_addon_domain(domain,dir='',ftp_user='',pass=random)
      domain = scan_domain_name(domain)
      dir = domain if dir == ''
      ftp_user = (domain.split('.')[0]+random(4)) if ftp_user == ''
      unless is_addon_domain?(domain)
        url = json_url(@cpanel_user,'AddonDomain','addaddondomain',"newdomain=#{domain}&dir=#{dir}&subdomain=#{ftp_user}&pass=#{pass}")
        reply = get(url)
        data = parseAndFormatReply(reply)
        if data[0]['result'] == 1
          return_msg(true,"Domain #{domain} added successfully",{:domain_name => "#{domain}",:pass => "#{pass}",:doc_root => "#{dir}",:ftp_user => "#{ftp_user}"})
        else
          return_msg(false,data[0]['reason'], :domain_name => "#{domain}")
        end
      else
        return_msg(false,"Domain #{domain} already added",:domain_name => "#{domain}")
      end
    rescue Timeout::Error
      if is_addon_domain? domain
        return_msg(true,"Domain #{domain} added successfully",{:domain_name => "#{domain}",:pass => "{pass}",:doc_root => "#{dir}",:ftp_user => "#{ftp_user}"})
      else
        return_msg(false,"Could not add the domain #{domain},Try Again.",:domain_name => "#{domain}")
      end
    end
  
    def add_sub_domain(domain,rootdomain,dir='')
      domain = scan_domain_name(domain)
      rootdomain = scan_domain_name(rootdomain)
      dir = domain if dir == ''
      full_sub_domain = domain+'.'+rootdomain
      unless is_sub_domain?(full_sub_domain)
        url = json_url(@cpanel_user,'SubDomain','addsubdomain',"domain=#{domain}&rootdomain=#{rootdomain}&dir=#{dir}")
        reply = get(url)
        data = parseAndFormatReply(reply)
        if data[0]['result'] == 1
          return_msg(true,"Sub-domain #{full_sub_domain} added successfully",:domain_name => "#{full_sub_domain}")
        else
          return_msg(false,data[0]['reason'],:domain_name => "#{full_sub_domain}")
        end
      else
        return_msg(false,"Sub-domain #{full_sub_domain} already added",:domain_name => "#{full_sub_domain}")
      end
    rescue Timeout::Error
      if is_addon_domain?(full_sub_domain)
        return_msg(true,"Sub-domain #{full_sub_domain} added successfully",{:domain_name => "#{full_sub_domain}",:doc_root => "#{dir}"})
      else
        return_msg(false,"Could not add the sub-domain #{full_sub_domain},Try Again.",:domain_name => "#{full_sub_domain}")
      end
    end
  
    def del_park_domain(domain)
      domain = scan_domain_name(domain)
      url = json_url(@cpanel_user,'Park','unpark',"domain=#{domain}")
      reply = get(url)
      data = parseAndFormatReply(reply)
      if data[0]['result'] == 1
        return_msg(true,'Removed successfully',:domain_name => "#{domain}")
      else
        return_msg(false,data[0]['reason'],:domain_name => "#{domain}")
      end
    end
  
    def del_addon_domain(domain)
      domain = scan_domain_name(domain)
      url = json_url(@cpanel_user,'AddonDomain','deladdondomain',"domain=#{domain}")
      reply = get(url)
      data = parseAndFormatReply(reply)
      if data[0]['result'] == 1
        puts data[0]['reason']
        return_msg(true,data[0]['reason'],:domain_name => "#{domain}")
      else
        puts data[0]['reason']
        return_msg(false,data[0]['reason'],:domain_name => "#{domain}")
      end
    end
  
    def del_sub_domain(domain)
      domain = scan_domain_name(domain)
      url = json_url(@cpanel_user,'SubDomain','delsubdomain',"domain=#{domain}")
      reply = get(url)
      data = parseAndFormatReply(reply)
      if data[0]['result'] == 1
        puts data[0]['reason']
        return_msg(true,data[0]['reason'],:domain_name => "#{domain}")
      else
        puts data[0]['reason']
        return_msg(false,data[0]['reason'],:domain_name => "#{domain}")
      end
    end
  
    def scan_domain_name(domain)
      if /^http:\/\/|^https:\/\// =~ domain
        domain.split(/^http:\/\/|^https:\/\//)[1]
      else
        domain
      end
    end
  
    private :scan_domain_name
  
  end
    
  include CpanelDbUtil
  include CpanelDomainUtil  
end

module Kernel
 private
    def current_method
      caller[0] =~ /`([^']*)'/ and $1
    end
end

class Cpanel
  include CpanelAPI
end
