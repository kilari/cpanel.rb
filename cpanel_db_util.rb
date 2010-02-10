require 'cpanel.rb'

class CpanelDbUtil < CpanelAPI
  
  attr_reader :file_name, :db_type
  
  def initialize(cpanel_user, cpanel_pass, domain,db_type=:mysql,port = 2083)
    super(cpanel_user, cpanel_pass, domain, port)
    @db_type=db_type.to_sym
    @file_name ={:create_db => {:mysql => 'sql/addb.html',:psql => 'psql/addbs.html'}, :create_user => {:mysql => 'sql/adduser.html',:psql => 'psql/addusers.html'}, :assign_user2db => {:mysql => 'sql/addusertodb.html',:psql => 'psql/addusertodb.html'}, :del_db => {:mysql => 'sql/deldb.html', :psql => 'psql/deldb.html'}, :del_user => {:mysql => 'sql/deluser.html', :psql => 'psql/deluser.html'}, :api => {:mysql => 'MysqlFE', :psql => 'Postgres'} }
  end  
   
  def db_type=(db_type)
    @db_type = db_type.to_sym
  end
  
  def list_dbs
    url = json_url(@cpanel_user,@file_name[:api][@db_type],'listdbs')
    reply = parse(get(url))
    db_data = get_data(reply)
    db_list = []
    db_data.each{|x| db_list<< x['db']}
    db_list
  end
 
  def list_db_users
    url = json_url(@cpanel_user,@file_name[:api][@db_type],'listusers')
    reply = parse(get(url))
    db_data = get_data(reply)
    db_users = []
    db_data.each{|x| db_users<< x['user']}
    db_users
  end
  
  def list_db_priv(db)
    db = add_cpanel_user_name(db)
    url = json_url(@cpanel_user,@file_name[:api][@db_type],'listusersindb',"db=#{db}")
    reply = parse(get(url))
    db_data = get_data(reply)
    db_users = []
    db_data.each{|x| db_users<< x['user']}
    db_users
  end
  
  def create_db(db_name)
    db_name = remove_cpanel_user_name(db_name)
    full_db_name = add_cpanel_user_name(db_name)
    unless db_name.size > 16 || db_name.size == 0
      if list_dbs.include? full_db_name
        return_msg(false, "DB #{full_db_name} already exists")
      else
        return return_msg(false,'DB name should only be alphanumeric') unless /^[A-Za-z0-9]*$/ =~ db_name
        doc = Hpricot(post(@file_name[:create_db][@db_type],{:db => "#{db_name}"}).body) ##To grab any other type of errors like limit exceeded
        error = doc/"p.errors"
        if error.size == 0
          return_msg(true, "DB #{full_db_name} created successfully")
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
          post(@file_name[:create_user][@db_type],{:user => "#{db_user}",:pass => "#{pass}", :pass2 => "#{pass}"})
         return return_msg(true,"Password for the database user #{full_db_user} has been reset to #{pass}",:pass => "#{pass}")
        elsif current_method == 'reset_user_pass'
          return return_msg(false, "Could not find the DB user #{full_db_user}")
        end  
        if current_method == 'create_db_user'
          post(@file_name[:create_user][@db_type],{:user => "#{db_user}",:pass => "#{pass}", :pass2 => "#{pass}"})
          return_msg(true, "Added a database user #{full_db_user} with password #{pass}",:pass => "#{pass}")
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
      post(@file_name[:assign_user2db][@db_type], {:db => "#{db_name}", :user => "#{db_user}",'ALL' => 'ALL'})
      if list_db_priv(db_name).include? db_user
        return_msg(true, "Added DB user #{db_user} to the DB #{db_name}")
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

  def del_db(db_name)
    db_name = add_cpanel_user_name(db_name)
    if list_dbs.include? db_name
      post(@file_name[:del_db][@db_type],{:db => "#{db_name}"})
      return_msg(true, "Deleted DB #{db_name}")
    else
      return_msg(false, "Could not find DB #{db_name}")
    end
  end
  
  def del_user(user)
    user = add_cpanel_user_name(user)
    if list_db_users.include? user
      post(@file_name[:del_user][@db_type],{:user => "#{user}"})
      return_msg(true, "Deleted DB user #{user}")
    else
      return_msg(false, "Could not find DB user #{user}")
    end
  end
  
  private
  
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
  
end

module Kernel
 private
    def current_method
      caller[0] =~ /`([^']*)'/ and $1
    end
end

