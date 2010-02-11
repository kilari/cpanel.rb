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


require 'cpanel'

class CpanelDomainUtil < CpanelAPI
  
  def initialize(cpanel_user, cpanel_pass, domain,port = 2083)
    super
  end
  
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
  
  def get_doc_roots
    
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
