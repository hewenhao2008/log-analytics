#encoding: utf-8

require 'yaml'
require 'em-zeromq'
require 'multi_json'

config = YAML.load_file 'log-server.yml'
server_conf = config['server']
host = server_conf['host']
port = server_conf['port']

zmq = EM::ZeroMQ::Context.new(1)


$language_samples =<<end_of_text
en-us,en;q=0.5
da,en-gb;q=0.8,en;q=0.7
no,en-gb;q=0.8,de;q=0.55
ja;q=0.8,en;q=0.3,de-de,de;q=0.5
en-us;q=0.5,en;q=0.8,de-de,de;q=0.9
de-de,de;q=0.8,en-us;q=0.5,en;q=0.3
en-us;q=0.8,en;q=0.5,de-de,de;q=0.3
end_of_text

$useragent_samples = <<end_of_text
Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)
Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)
Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0 )
Mozilla/4.0 (compatible; MSIE 5.5; Windows 98; Win 9x 4.90)
Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.1) Gecko/2008070208 Firefox/3.0.1
Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.14) Gecko/20080404 Firefox/2.0.0.14
Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.2.149.29 Safari/525.13
Mozilla/4.8 [en] (Windows NT 6.0; U)
Mozilla/4.8 [en] (Windows NT 5.1; U)
Opera/9.25 (Windows NT 6.0; U; en)
Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0; en) Opera 8.0
Opera/7.51 (Windows NT 5.1; U) [en]
Opera/7.50 (Windows XP; U)
Mozilla/5.0 (Windows; U; Win98; en-US; rv:1.4) Gecko Netscape/7.1 (ax)
Mozilla/5.0 (Windows; U; Windows XP) Gecko MultiZilla/1.6.1.0a
Opera/7.50 (Windows ME; U) [en]
Mozilla/3.01Gold (Win95; I)
Mozilla/2.02E (Win95; U)
Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/125.2 (KHTML, like Gecko) Safari/125.8
Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/125.2 (KHTML, like Gecko) Safari/85.8
Mozilla/4.0 (compatible; MSIE 5.15; Mac_PowerPC)
Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.7a) Gecko/20050614 Firefox/0.9.0+
Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-US) AppleWebKit/125.4 (KHTML, like Gecko, Safari) OmniWeb/v563.15
Mozilla/5.0 (X11; U; Linux; i686; en-US; rv:1.6) Gecko Debian/1.6-7
Mozilla/5.0 (X11; U; Linux; i686; en-US; rv:1.6) Gecko Epiphany/1.2.5
Mozilla/5.0 (X11; U; Linux i586; en-US; rv:1.7.3) Gecko/20050924 Epiphany/1.4.4 (Ubuntu)
Mozilla/5.0 (compatible; Konqueror/3.5; Linux) KHTML/3.5.10 (like Gecko) (Kubuntu)
Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.19) Gecko/20081216 Ubuntu/8.04 (hardy) Firefox/2.0.0.19
Mozilla/5.0 (X11; U; Linux; i686; en-US; rv:1.6) Gecko Galeon/1.3.14
Konqueror/3.0-rc4; (Konqueror/3.0-rc4; i686 Linux;;datecode)
Mozilla/5.0 (compatible; Konqueror/3.3; Linux 2.6.8-gentoo-r3; X11;
Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.6) Gecko/20050614 Firefox/0.8
ELinks/0.9.3 (textmode; Linux 2.6.9-kanotix-8 i686; 127x41)
ELinks (0.4pre5; Linux 2.6.10-ac7 i686; 80x33)
Links (2.1pre15; Linux 2.4.26 i686; 158x61)
Links/0.9.1 (Linux 2.4.24; i386;)
MSIE (MSIE 6.0; X11; Linux; i686) Opera 7.23
Opera/9.52 (X11; Linux i686; U; en)
Lynx/2.8.5rel.1 libwww-FM/2.14 SSL-MM/1.4.1 GNUTLS/0.8.12
Links (2.1pre15; FreeBSD 5.3-RELEASE i386; 196x84)
Mozilla/5.0 (X11; U; FreeBSD; i386; en-US; rv:1.7) Gecko
Mozilla/4.77 [en] (X11; I; IRIX;64 6.5 IP30)
Mozilla/4.8 [en] (X11; U; SunOS; 5.7 sun4u)
Mozilla/3.0 (compatible; NetPositive/2.1.1; BeOS)
Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)
Googlebot/2.1 (+http://www.googlebot.com/bot.html)
msnbot/1.0 (+http://search.msn.com/msnbot.htm)
msnbot/0.11 (+http://search.msn.com/msnbot.htm)
Mozilla/5.0 (compatible; Yahoo! Slurp; http://help.yahoo.com/help/us/ysearch/slurp)
Mozilla/2.0 (compatible; Ask Jeeves/Teoma)
Mozilla/5.0 (compatible; ScoutJet; +http://www.scoutjet.com/)
Gulper Web Bot 0.2.4 (www.ecsl.cs.sunysb.edu/~maxim/cgi-bin/Link/GulperBot)
EmailWolf 1.00
grub-client-1.5.3; (grub-client-1.5.3; Crawl your own stuff with http://grub.org)
Download Demon/3.5.0.11
OmniWeb/2.7-beta-3 OWF/1.0
end_of_text

$host_samples = <<end_of_text
www.baidu.com
www.17173.com
www.263.com
www.tudou.com
www.youku.com
www.sohu.com
www.tianya.com
www.qq.com
end_of_text

$user_samples = <<end_of_text
and
jiwei
luoxu
benteng
end_of_text


def random_item list
	list[rand(list.length)]
end


def get_random_item
	if $ua_list.nil?
		$ua_list = $useragent_samples.split "\n"
		$lang_list = $language_samples.split "\n"
		$user_list = $user_samples.split "\n"
		$host_list = $host_samples.split "\n"
	end

	step_time = 3600*24*3 #1天
	min_time = Time.now - step_time
	use_time = min_time + rand(1..step_time)

	result = {}
	result["Time"] = use_time.utc.to_s
	result["User-Id"] = random_item($user_list)
	result["Host"] = random_item($host_list)
	result["Request URL"] = "http://" + result["Host"] + "/category/item#{rand(1..10)}\.html"
	result["Referer"] = "http://" + random_item($host_list) + "/"
	result["User-Agent"] = $ua_list[rand($ua_list.length)]
	result["Accept-Language"] = $lang_list[rand($lang_list.length)]
	result["Client-Ip"] = "#{rand(200..210)}.#{rand(100..200)}.#{rand(1..254)}.#{rand(1..254)}"
	result["Token-Id"] = "token-id-001"
	result["Machine-Id"] = "machine-id-1"

	MultiJson.dump result
end


EM.run do
	push = zmq.socket(ZMQ::PUSH)
	push.connect("tcp://#{host}:#{port}")

	counter = 0

	EM.add_periodic_timer(1) {
		(0..100).each do
			push.send_msg(get_random_item)
			counter += 1
		end

		if counter >= 10000
			puts 'push 10000 completed'
			exit 0
		end
	}
end

