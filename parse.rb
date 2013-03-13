#!/usr/bin/ruby
require 'net/http'
require 'rubygems'
require 'pony'

def send_mail(body, params)
	begin
		if (body.nil? || params['recepient'].nil? || params['server'].nil? || params['login'].nil? || params['pass'].nil?) then
			raise ArgumentError, "Empty parameters. Fill all required" 
		end
		Pony.mail(
		:to			=>	params['recepient'],
		:from		=>	params['sender'] || "Mailer",
		:subject 	=>	params['subject'] || "Новое объявление",
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
		);
	rescue
		puts "Error while sending email. Check params";
		exit 1;
	end;
end

def parse(html, first_elem = [])
begin
	ads = html.split('<div class="t_i_i t_i');
	elems_array = [["title", "link", "cost", "time", "desc"]] #just for info
	ads.shift;
	elems_array.shift;
	ads.each { |e| 
		if(e['premium'] != nil) then
			next;
		end
		time = e.split('t_i_time">')[1].split("</span>")[0];
		link = e.split('href="')[1].split('"')[0];
		link = "http://www.avito.ru"+link;
		title = e.split('title="')[1].split('"')[0].sub("&laquo;","«").sub("&raquo;","»");
		cost = e.split('<span>')[1].split('</span>')[0].sub("&nbsp;"," ");
	
		desc = "Описание отсутствует"
		resp = fetch(link);
		if resp != nil then
			desc = resp.split('<dd id="desc_text">')[1];
			if desc != nil then
				desc = desc.split('</dd>')[0];
			end
		end;
		elems_array.push([title, link, cost, time, desc]);
		if(elems_array.last == first_elem) then
			return elems_array
		end
	}
	return elems_array;
rescue
	return "Error"
end;
end

def fetch(uri_str, limit = 10)
  raise ArgumentError, 'too many HTTP redirects' if limit == 0
  begin
  	response = Net::HTTP.get_response(URI(uri_str))
  	case response
  	when Net::HTTPSuccess then
  	  response.body
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
		'main' => { 'url' => "http://www.avito.ru/", 'sleep_time' => 10},
		'mail' => { 'recepient' => "zduderman@gmail.com", 'sender'=> "duderman@mail.ru", 'subject'=> "Новое объявление", 'server'=> "mail.ru", 'login' => "duderman", 'pass'=> "as8F9P"}
	}
	File.open("config.yml", "w") do |file|
  		file.write config.to_yaml
	end
end

#Main
begin
	config = YAML::load_file "config.yml"
rescue
	config = create_default_config
	puts 'Default config created. Please fill it and try again';
	exit 1;
end;
if config['main']['url'].nil? then
	puts "URL is required. Please set it in config.yml"
end
sleep_time = 10
sleep_time = config['main']['sleep_time'].to_i if !config['main']['sleep_time'].nil?
puts "Script started with url " + config['main']['url'];
puts "subject is" + config['mail']['subject']
puts send_mail "Тест", config['mail']

puts "Initial Check";
test_resp = fetch(config['main']['url']);
if(test_resp == nil) then
	puts "Can't get page. Do you have internet connection and the url correct?";
	exit 1;
elsif (parse(test_resp) == "Error") then
	puts "Can't parse page. Check url";
	exit 1;
end
puts "OK";

last_array = [["title", "link", "cost", "time", "desc"]]; 
last_array.shift;
is_error = false;
while 1
	puts "Getting new page ";
	resp = fetch(config['main']['url']);
	if(resp == nil) then
		puts "Something wrong with internet connection"
	else
		puts "Parsing response";
		if(!last_array.empty?) then
			new_array = parse(resp, last_array[0]);
		else
			new_array = parse(resp);
		end;
		if(new_array == "Error" || new_array.empty?) then
			if(!is_error) then
				is_error = true;
				puts "Can't parse page";
				send_mail("Ошибка при обработке страницы. Скрипт продожит работу и попытается устранить ошибку", config['mail']);
			end
		else
			if(is_error) then
				is_error = false;
				puts "Script working again"
				send_mail("Работа скрипта восстановлена", config['mail']);
			end
			if(last_array.empty?) then
				puts "First run. Initial array obtained";
				last_array = new_array;
			elsif(new_array[0] == last_array[0]) then
				puts "Nothing has changed";
			elsif (new_array.length!=1) then
				puts "Mailing";
				diff_array = new_array - last_array;
				last_array = new_array;
				puts "Elements count is "+diff_array.length.to_s;
				body="";
				diff_array.each{ |e|
					body+='<h2>'+e[0]+'</h2><br /><a href="'+e[1]+'">'+e[1]+'</a><br /><h3>'+e[2]+'</h3><br />Опубликовано в '+e[3]+'<br /><br />'+e[4]+'<br /><br />';
				}
				send_mail(body, config['mail']);
			end;
		end
	end
	puts "Done. zzzz";
	sleep(config['main']['sleep_time'].to_i);
end