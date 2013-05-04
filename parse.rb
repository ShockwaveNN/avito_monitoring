#!/usr/bin/ruby
# encoding: UTF-8
require 'net/http'
require 'rubygems'
require 'pony'

def send_mail(body, params)
	begin
		if body.nil? || params['recepient'].nil? || params['server'].nil? || params['login'].nil? || params['pass'].nil? then
			raise ArgumentError, 'Empty parameters. Fill all required'
    end
		Pony.mail(
		:to			=>	params['recepient'],
		:from		=>	params['sender'] || 'Mailer',
		:subject 	=>	params['subject'] || 'Новое объявление',
		:html_body 	=> 	body,
		:charset	=>	'utf-8',
		:via		=>	'smtp',
		:via_options => {
			:address	=>	'smtp.'+params['server'],
			:port		=>	'25',
			:user_name	=>	params['login'],
			:password	=>	params['pass'],
			:authentification => 'plain',
			:domain		=>	params['server']
		}
		)
  rescue
		log 'Error while sending email. Check params', 'error'
		exiting
	end
end

def parse(html, first_elem = [])
begin
	ads = html.split('<div class="t_i_i t_i')
  elems_array = [%w(title link cost time desc)] #just for info
	ads.shift
  elems_array.shift
  ads.each { |e|
		if e['premium'] != nil then
			next
    end
		time = e.split('t_i_time">')[1].split('</span>')[0]
    link = e.split('href="')[1].split('"')[0]
    link = 'http://www.avito.ru'+link
    title = e.split('title="')[1].split('"')[0].sub('&laquo;', '«').sub('&raquo;', '»')
    cost = e.split('<span>')[1]
		if cost.nil? then
			cost = ''
		else
			cost = cost.split('</span>')[0].sub('&nbsp;', ' ')
    end
	
		desc = 'Описание отсутствует'
		resp = fetch(link)
    if resp != nil then
			desc = resp.split('<dd id="desc_text">')[1]
      if desc != nil then
				desc = desc.split('</dd>')[0]
      end
		end
    elems_array.push([title, link, cost, time, desc])
    if !first_elem.empty? && elems_array.last == first_elem then
			return elems_array
		end
	}
	return elems_array
rescue
	return 'Error'
end
end

def fetch(uri_str, limit = 10)
  raise ArgumentError, 'too many HTTP redirects' if limit == 0
  begin
  	response = Net::HTTP.get_response(URI(uri_str))
  	case response
      when Net::HTTPSuccess then
  	  response.body.force_encoding('UTF-8')
  	when Net::HTTPRedirection then
  	  location = response['location']
  	  warn "redirected to #{location}"
  	  fetch(location, limit - 1)
  	else
  	  raise
  	end
  rescue
  	nil
  end
end

def create_default_config
	config = {
		'main' => { 'url' => 'http://www.avito.ru/', 'sleep_time' => 300},
		'mail' => { 'recepient' => 'recepient', 'sender'=> 'sender', 'subject'=> 'Mail subject', 'server'=> 'server.ru', 'login' => 'login', 'pass'=> 'pass'}
	}
	File.open( (File.expand_path(File.dirname(__FILE__))+'/config.yml'), 'w') do |file|
  		file.write config.to_yaml
	end
end

def log(text, level = 'DEBUG')
	message = Time.now.strftime('%X')+' ['+level.upcase+'] '+text
	puts message
end

def exiting
	puts 'Press ENTER to continue'
	gets
	exit 1
end

#Main
log 'Opening config in '+File.expand_path(File.dirname(__FILE__))+'/config.yml'
begin
	config = YAML::load_file File.expand_path(File.dirname(__FILE__))+'/config.yml'
rescue
	config = create_default_config
	log 'Default config created. Please fill it and try again', 'warn'
	exiting
end
if config['main']['url'].nil? then
	log 'URL is required. Please set it in config.yml', 'error'
	exiting
end
sleep_time = 300
sleep_time = config['main']['sleep_time'].to_i if !config['main']['sleep_time'].nil?
log 'Script started with url ' + config['main']['url']

log 'Initial Check'

test_resp = fetch(config['main']['url'])
if test_resp == nil then
	log "Can't get page. Do you have internet connection and the url correct?", 'error'
	exiting
elsif parse(test_resp) == 'Error' then
	log "Can't parse page. Check url", 'error'
	exiting
end
log 'OK'


last_array = [%w(title link cost time desc)]
last_array.shift
is_error = false
while 1
	log 'Getting new page '

  resp = fetch(config['main']['url'])
  if resp == nil then
		log 'Something wrong with internet connection', 'error'
	else
		log 'Parsing response'

    if !last_array.empty? then
			new_array = parse(resp, last_array[0])
    else
			new_array = parse(resp)
    end
    if new_array == 'Error' || new_array.empty? then
			if !is_error then
				is_error = true
        log "Can't parse page", 'error'
				send_mail('Ошибка при обработке страницы. Скрипт продожит работу и попытается устранить ошибку', config['mail'])
      end
		else
			if is_error then
				is_error = false
        log 'Script working again'
				send_mail('Работа скрипта восстановлена', config['mail'])
      end
			if last_array.empty? then
				log 'First run. Initial array obtained'

        last_array = new_array
      elsif new_array[0] == last_array[0] then
				log 'Nothing has changed'

      elsif new_array.length!=1 then
				log 'Mailing'

        diff_array = new_array - last_array
        last_array = new_array
        log 'Elements count is '+diff_array.length.to_s
        body=''

        diff_array.each{ |e|
					body+='<h2>'+e[0]+'</h2><br /><a href="'+e[1]+'">'+e[1]+'</a><br /><h3>'+e[2]+'</h3><br />Опубликовано в '+e[3]+'<br /><br />'+e[4]+'<br /><br />'
        }
				send_mail(body, config['mail'])
      end
    end
	end
	log "Done. Sleeping for #{sleep_time} seconds"

  sleep(sleep_time)
end
