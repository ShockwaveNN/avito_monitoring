#!/usr/bin/ruby
require 'net/http'
require 'rubygems'
require 'pony'
sleep_time = 120;

last_array = [["title", "link", "cost", "time", "desc"]]; 
last_array.shift;
while 1
puts "getting new page ";
httpCon = Net::HTTP.new("www.avito.ru", 80);
resp = httpCon.get("/sankt-peterburg/komnaty?pmax=12000&params=200_1055.596_6203&user=1", nil);
ads = resp.body.split('<div class="t_i_divider"></div>')[1].split('<!--noindex-->')[0].split('<div class="t_i_i t_i');
new_array = [["title", "link", "cost", "time", "desc"]]
ads.shift;
new_array.shift;
puts "parsing new elems";
ads.each { |e| 
	time = e.split('t_i_time">')[1].split("</span>")[0];
	link = e.split('href="')[1].split('"')[0];
	title = e.split('title="')[1].split('"')[0].sub("&laquo;","«").sub("&raquo;","»");
	cost = e.split('<span>')[1].split('</span>')[0].sub("&nbsp;"," ");

	resp = httpCon.get(link, nil);
	desc = resp.body.split('<dd id="desc_text">')[1];
	if desc != nil then
		desc = desc.split('</dd>')[0];
	else
		desc = "Описание отсутствует"
	end;
	link = "http://www.avito.ru"+link;
	new_array.push(	[title, link, cost, time, desc] );
	if(new_array.length == 1 && !(last_array.empty?)) then
		if(new_array[0] == last_array[0]) then
			puts "first equalslast first. breaking";
			break;
		end;
	end;
 }
 if(last_array.empty?) then
 	puts "last is empty. setting it to current";
 	last_array = new_array;
 	sleep(sleep_time);
 	next;
  elsif (new_array.length!=1) then
 	puts "mailing";
 	diff_array = new_array - last_array;
 	last_array = new_array;
 	puts "elems count is "+diff_array.length.to_s;
 	body="";
 	diff_array.each{ |e|
 		body+='<h2>'+e[0]+'</h2><br /><a href="'+e[1]+'">'+e[1]+'</a><br /><h3>'+e[2]+'</h3><br />Опубликовано в '+e[3]+'<br /><br />'+e[4]+'<br /><br />';
 	}
 	Pony.mail(
	:to			=>	'recepient',
	:from		=>	'sender',
	:subject 	=>	'Новая комната',
	:html_body 	=> 	body,
	:charset	=>	'utf-8',
	:via		=>	'smtp',
	:via_options => {
		:address	=>	'smtp.server.ru',
		:port		=>	'25',
		:user_name	=>	'login',
		:password	=>	'pass',
		:authentification => 'plain',
		:domain		=>	'server.ru'
	}
	);
 end;
 puts "done. zzzz";
 sleep(sleep_time);
end

