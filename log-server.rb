#encoding: utf-8

require 'optparse'
require 'yaml'
require 'em-zeromq'

require 'active_record'
require 'logger'
require 'digest/md5'

require 'uri'
require 'multi_json'
require 'accept_language'
require 'useragent'
require 'geoip'

=begin 
=================================================================
	获取命令行参数
=================================================================
=end

options = {}

banner_str = <<end_of_banner
------------------ 程序说明 -------------------

------------------ 命令行说明 ---------------------
end_of_banner

option_parser = OptionParser.new do |opts|
	opts.banner = banner_str	
=begin
	title = '默认为48小时。=0，只抓新数据库中没的；>0，抓最新几个小时的'
	opts.on('-t TIME', '--time Time', Integer, title) do |value|
		options[:time] = value
	end
=end
end.parse!


=begin 
=================================================================
	读取配置文件
=================================================================
=end

config = YAML.load_file 'log-server.yml'
server_conf = config['server']
host = server_conf['host']
port = server_conf['port']

rt_server_conf = config['realtime_server']
rt_host = rt_server_conf['host']
rt_port = rt_server_conf['port']


=begin
================================================================
	建立数据库连接
=================================================================
=end

$log = Logger.new STDERR
ActiveRecord::Base.establish_connection config['database']
#ActiveRecord::Base.logger = $log

class DimReferer    < ActiveRecord::Base; has_many :fact_requests end
class DimLocation   < ActiveRecord::Base; has_many :fact_requests end
class DimLanguage   < ActiveRecord::Base; has_many :fact_requests end
class DimBrowser    < ActiveRecord::Base; has_many :fact_requests end
class DimMachine    < ActiveRecord::Base; has_many :fact_requests end
class DimUser	    < ActiveRecord::Base; has_many :fact_requests end
class DimHost	    < ActiveRecord::Base; has_many :fact_requests end
class DimRequesturi < ActiveRecord::Base; has_many :fact_requests end

class FactRequest   < ActiveRecord::Base 
	belongs_to :dim_referer
	belongs_to :dim_location
	belongs_to :dim_language
	belongs_to :dim_browser
	belongs_to :dim_machine
	belongs_to :dim_user
	belongs_to :dim_host
	belongs_to :dim_requesturi
=begin
	validates_presence_of :dim_referer
	validates_associated :dim_referer
=end
end


def create_tables
	ActiveRecord::Schema.define do
		create_table :fact_requests do |t|
			t.datetime 	:time,	    	:null=>false
			t.integer 	:dim_machine_id
			t.integer 	:dim_user_id
			t.integer 	:dim_language_id
			t.integer 	:dim_location_id
			t.integer 	:dim_browser_id
			t.integer	:dim_referer_id
			t.integer 	:dim_host_id
			t.integer 	:dim_requesturi_id
		end
		add_index :fact_requests, [:time]

		#-------------------------------------------------------
		create_table :dim_locations do |t|
			t.string	:continent,	:null=>false
			t.string	:country,	:null=>false
			t.string	:city,		:null=>false
			t.string	:timezone, 	:null=>false
			t.string	:md5,		:null=>false
		end
		add_index :dim_locations, [:id, :md5], :unique=>true

		#-------------------------------------------------------
		create_table :dim_languages do |t|
			t.string	:pri,		:null=>false
			t.string	:sub,		:null=>false
			t.string	:quality_value,	:null=>false
			t.string	:md5,		:null=>false
		end
		add_index :dim_languages, [:id, :md5], :unique=>true

		#-------------------------------------------------------
		create_table :dim_browsers do |t|
			t.boolean 	:mobile,	:default=>false
			t.string	:platform,	:null=>false
			t.string	:browser,	:null=>false
			t.string	:version,	:null=>false
			t.string	:md5,		:null=>false
		end
		add_index :dim_browsers, [:id, :md5], :unique=>true

		#-------------------------------------------------------
		create_table :dim_machines do |t|
			t.string	:token_key,	:null=>false
			t.string	:hardware_key,	:null=>false
			t.string	:md5,		:null=>false
		end
		add_index :dim_machines, [:id, :md5], :unique=>true

		#-------------------------------------------------------
		create_table :dim_users do |t|
			t.string	:user,		:null=>false
		end
		add_index :dim_users, [:id, :user], :unique=>true

		#-------------------------------------------------------
		create_table :dim_referers do |t|
			t.string	:url,		:null=>false
		end
		add_index :dim_referers, [:id, :url], :unique=>true

		#-------------------------------------------------------
		create_table :dim_hosts do |t|
			t.string	:host,		:null=>false
		end
		add_index :dim_hosts, [:id, :host], :unique=>true

		#-------------------------------------------------------
		create_table :dim_requesturis do |t|
			t.string	:request_uri,	:null=>false
		end
		add_index :dim_requesturis, [:id, :request_uri], :unique=>true
	end
end

unless FactRequest.table_exists?
	create_tables()
end


MD5_PREFIX = 'log-server-md5-prefix'

def get_md5_str *items
	digest = Digest::MD5.new
	digest << MD5_PREFIX
	items.each do |o|
		digest << '-'
		digest << o
	end
	digest.hexdigest
end

def get_referer_id referer_url
	dim = DimReferer.find_by_url referer_url, :select=>'id'
	return dim.id if dim

	new_dim = DimReferer.create! :url=>referer_url
	new_dim.id
end

def get_location_id continent, country, city, timezone
	md5_str = get_md5_str continent, country, city, timezone
	dim = DimLocation.find_by_md5 md5_str, :select=>'id'
	return dim.id if dim

	new_dim = DimLocation.new do |o|
		o.continent = continent
		o.country = country
		o.city = city
		o.timezone = timezone
		o.md5 = md5_str
		o.save!
	end
	new_dim.id
end

def get_language_id pri, sub, quality_value
	md5_str = get_md5_str pri, sub, quality_value.to_s
	dim = DimLanguage.find_by_md5 md5_str, :select=>'id'
	return dim.id if dim

	new_dim = DimLanguage.new do |o|
		o.pri = pri
		o.sub = sub
		o.quality_value = quality_value
		o.md5 = md5_str
		o.save!
	end
	new_dim.id
end

def get_browser_id mobile, platform, browser, version
	md5_str = get_md5_str mobile.to_s, platform, browser, version
	dim = DimBrowser.find_by_md5 md5_str, :select=>'id'
	return dim.id if dim

	new_dim = DimBrowser.new do |o|
		o.mobile = mobile
		o.platform = platform
		o.browser = browser
		o.version = version
		o.md5 = md5_str
		o.save!
	end
	new_dim.id
end

def get_machine_id token, hardware
	md5_str = get_md5_str token, hardware
	dim = DimMachine.find_by_md5 md5_str, :select=>'id'
	return dim.id if dim

	new_dim = DimMachine.create! :token_key=>token, :hardware_key=>hardware, :md5=>md5_str
	new_dim.id
end

def get_user_id user
	dim = DimUser.find_by_user user, :select=>'id'
	return dim.id if dim

	new_dim = DimUser.create! :user=>user
	new_dim.id
end

def get_host_id host
	dim = DimHost.find_by_host host, :select=>'id'
	return dim.id if dim

	new_dim = DimHost.create! :host=>host
	new_dim.id
end

def get_requesturi_id uri
	dim = DimRequesturi.find_by_request_uri uri, :select=>'id'
	return dim.id if dim

	new_dim = DimRequesturi.create! :request_uri=>uri
	new_dim.id
end

def import_database log_item
	FactRequest.new do |o|
		o.time = log_item[0]
		o.dim_machine_id = log_item[1]
		o.dim_user_id = log_item[2]
		o.dim_location_id = log_item[3]
		o.dim_language_id = log_item[4]
		o.dim_browser_id = log_item[5]
		o.dim_referer_id = log_item[6]
		o.dim_host_id = log_item[7]
		o.dim_requesturi_id = log_item[8]
		o.save!
	end
end

def push_log item_json
	item = MultiJson.load item_json
	return false unless host = item['Host']
	return false unless url  = item['Request URL']
	return false unless referer = item['Referer']
	return false unless ua = item['User-Agent']
	return false unless language = item['Accept-Language']
	return false unless ip = item['Client-Ip']
	return false unless userid = item['User-Id']
	return false unless tokenid = item['Token-Id']
	return false unless machineid = item['Machine-Id']

	time = item['Time'] || Time.now.utc.to_s
	time = Time.parse(time).utc
	
	city = GeoIP.new('GeoLiteCity.dat').city(ip)
	if city 
		continent = city.continent_code || 'null'
		country = city.country_name || 'null'
		cityname = city.city_name || 'null'
		timezone = city.timezone || 'null'
	else
		continent = country = cityname = timezone = 'null'
	end

	new_lang = language.split ','
	lang = AcceptLanguage::Parser::Phrase.new(new_lang[0])
	if lang
		pri = lang.primary || 'en'
		sub = lang.sub || pri || 'en'
		quality_value = lang.quality_value || '1'
	else
		pri = sub = 'en'
		quality_value = '1'
	end

	user_agent = UserAgent.parse ua
	if user_agent
		mobile = user_agent.mobile? || false
		platform = user_agent.platform || 'null'
		browser = user_agent.browser || 'null'
		version = user_agent.version || 'null'
	else
		mobile = false
		platform = browser = version = 'null'
	end

	log_item = [time]
	log_item << get_machine_id(tokenid, machineid)
	log_item << get_user_id(userid)
	log_item << get_location_id(continent, country, cityname, timezone)
	log_item << get_language_id(pri, sub, quality_value)
	log_item << get_browser_id(mobile, platform, browser, version)
	log_item << get_referer_id(referer)
	log_item << get_host_id(host)
	log_item << get_requesturi_id(url)

	import_database log_item
	outport_realtime_server log_item

	true
end

def outport_realtime_server log_item
	time = log_item[0]
	log_item[0] = time.to_i
	$push_remote.send_msg MultiJson.dump(log_item)
end

=begin 
=================================================================
	监听zeromq
=================================================================
=end

Thread.abort_on_exception = true

trap('INT') do
  EM::stop()
end

puts "Started (with zmq #{ZMQ::Util.version.join('.')})."

zmq = EM::ZeroMQ::Context.new(1)

EM.run do
	$push_remote  = zmq.socket(ZMQ::PUSH)
	$push_remote.connect("tcp://#{rt_host}:#{rt_port}")

	# setup pull sockets
	pull_srv = zmq.socket(ZMQ::PULL)

	pull_srv.hwm = 10000
	pull_srv.swap = 1024 * 4 * 256

	# push_socket1.hwm = 40
	#puts "HWM: #{pull_srv.hwm}"
	#puts "SWAP: #{pull_srv.swap}"

	pull_srv.bind("tcp://#{host}:#{port}")

	pull_srv.on(:message) { |msg|
		json_msg = msg.copy_out_string.strip
		if json_msg != ''
			unless push_log(json_msg)
				puts 'error input: ' + json_msg
			end
		end
		msg.close
	}
end

puts "Unexpect completed."

