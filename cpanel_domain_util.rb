# Copyright (c) 2010, Kilari Vamsi
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


require 'cpanel1'

class CpanelDomainUtil < CpanelAPI
  
  def initialize(cpanel_user, cpanel_pass, domain,port = 2083)
    super(cpanel_user, cpanel_pass, domain, port)
    @file_name = {:api =>{'DomainLookup'}}
  end
  
  def list_domains
    url = json_url(@cpanel_user,'DomainLookup','getbasedomains')
    reply = parse(get(url))
    data = get_data(reply)
    list = []
    data.each{|x| list<<x['domain']}
    list
  end
  
  def get_doc_root(domain)
    url = json_url(@cpanel_user,'DomainLookup','getdocroot',"domain=#{domain}")
    reply = parse(get(url))
    data = get_data(reply)
    data[0]['docroot']
  end
  
  def get_doc_roots
    
  end
  
  def list_park_domains
    url = json_url(@cpanel_user,'Park','listparkeddomains')
    reply = parse(get(url))
    data = get_data(reply)
    list = []
    data.each{|x| list<<x['domain']}
    list
  end
  
  def list_addon_domains
    url = json_url(@cpanel_user,'AddonDomain','listaddondomains')
    reply = parse(get(url))
    data = get_data(reply)
    list = []
    data.each{|x| list<<x['domain']}
    list
  end
  
  def list_sub_domains
    url = json_url(@cpanel_user,'SubDomain','listsubdomains')
    reply = parse(get(url))
    data = get_data reply
    list = []
    data.each{|x| list<<x['domain']}
    list
  end
  
  def park_domain?(domain)
    get_park_domains.include? "#{domain}"
  end
  
  def addon_domain?(domain)
    get_addon_domains.include? "#{domain}"
  end
  
  def sub_domain?(domain)
    get_sub_domains.include? "#{domain}"
  end
  
  def park_domain(domain)
    
  end
  
  def add_addon_domain(domain)
    
  end
  
  def add_sub_domain(domain)
    
  end
  
  def del_park_domain(domain)
    url = json_url(@cpanel_user,'Park','unpark',"domain=#{domain}"
    reply = parse(get(url))
    data = get_data reply
    if data[0]['result'] == 1
      puts data[0]['reason']
      return_msg(true,data[0]['reason'])
    else
      puts data[0]['reason']
      return_msg(false,data[0]['reason'])
    end
  end
  
  def del_addon_domain(domain)
    url = json_url(@cpanel_user,'AddonDomain','deladdondomain',"domain=#{domain}")
    reply = parse(get(url))
    data = get_data reply
    if data[0]['result'] == 1
      puts data[0]['reason']
      return_msg(true,data[0]['reason'])
    else
      puts data[0]['reason']
      return_msg(false,data[0]['reason'])
    end
  end
  
  def del_sub_domain(domain)
    url = json_url(@cpanel_user,'SubDomain','delsubdomain',"domain=#{domain}")
    reply = parse(get(url))
    data = get_data reply
    if data[0]['result'] == 1
      puts data[0]['reason']
      return_msg(true,data[0]['reason'])
    else
      puts data[0]['reason']
      return_msg(false,data[0]['reason'])
    end
  end
end
