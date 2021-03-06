#encoding: utf-8

require 'optparse'
require 'yaml'
require 'em-zeromq'

require 'active_record'
require 'logger'
require 'digest/md5'

require 'uri'
require 'multi_json'

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

$config = YAML.load_file 'realtime-server.yml'
server_conf = $config['server']
host = server_conf['host']
port = server_conf['port']

=begin
================================================================
	建立数据库连接
=================================================================
=end

logstdout = Logger.new STDERR

class RankUrl		< ActiveRecord::Base; end
class RankLanguage	< ActiveRecord::Base; end
class RankUseragent	< ActiveRecord::Base; end
ActiveRecord::Base.establish_connection $config['realtime_database']
#ActiveRecord::Base.logger = logstdout

unless RankUrl.table_exists?
	ActiveRecord::Schema.define do
		#-------------------------------------------------------
		create_table :rank_urls do |t|
			t.integer 	:machine_id
			t.datetime 	:time,	    	:null=>false
			t.integer	:requesturi_id,	:null=>false
			t.integer 	:counter,	:default=>0
		end

		#-------------------------------------------------------
		create_table :rank_languages do |t|
			t.integer 	:machine_id
			t.datetime 	:time,	    	:null=>false
			t.string	:language,	:null=>false
			t.integer 	:counter,	:default=>0
		end

		#-------------------------------------------------------
		create_table :rank_useragents do |t|
			t.integer 	:machine_id
			t.datetime 	:time,	    	:null=>false
			t.boolean	:mobile,  	:default=>false
			t.string	:platform,	:null=>false
			t.string	:browser,	:null=>false
			t.integer 	:counter,	:default=>0
		end
	end
end


class LogServer	    < ActiveRecord::Base 
	self.abstract_class = true
	establish_connection $config['log_database']
end
class DimLocation   < LogServer; end
class DimLanguage   < LogServer; end
class DimBrowser    < LogServer; end
class DimMachine    < LogServer; end
class DimUser	    < LogServer; end
class DimReferer    < LogServer; end
class DimHost	    < LogServer; end
class DimRequesturi < LogServer; end


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

def get_language language_id
	dim = DimLanguage.find language_id, :select=>'pri,sub'
	return "#{dim.pri}-#{dim.sub}" if dim
	'(not set)'
end

def get_browser browser_id
	dim = DimBrowser.find browser_id, :select=>'mobile,platform,browser'
	return [dim.mobile,dim.platform,dim.browser] if dim
	[false, '(not set)', '(not set)']
end

def get_machine_id token, hardware
	md5_str = get_md5_str token, hardware
	dim = DimMachine.find_by_md5 md5_str, :select=>'id'
	return dim.id if dim

	new_dim = DimMachine.create! :token_key=>token, :hardware_key=>hardware, :md5=>md5_str
	new_dim.id
end

def get_requesturi uri_id
	dim = DimRequesturi.find uri_id, :select=>'request_uri'
	return dim.request_uri if dim
	'null'
end

def get_fixed_time time
	time = Time.at(time)
	Time.utc(time.year, time.month, time.day, time.hour, 0, 0, 0)
end

$handle_counter = 0

def incomming_realtime_message msg
	msg_obj = MultiJson.load msg

	time,machine,user,location,language,ua,referer,host,url = msg_obj
	time = get_fixed_time time
	new_counter = 0

	$handle_counter += 1
	puts "(#{$handle_counter}) " + get_requesturi(url)

	conditions = ["machine_id=? and time=? and requesturi_id=?", machine,time,url]
	result = RankUrl.update_all("counter=counter+1", conditions, :limit=>1)

	if (result == 0)
		RankUrl.new do |o|
			o.machine_id = machine
			o.time = time
			o.requesturi_id = url
			o.counter = 1
			o.save!
		end
		new_counter += 1
	end

	language = get_language language
	conditions = ["machine_id=? and time=? and language=?", machine,time,language]
	result = RankLanguage.update_all("counter=counter+1", conditions, :limit=>1)

	if (result == 0)
		RankLanguage.new do |o|
			o.machine_id = machine
			o.time = time
			o.language = language
			o.counter = 1
			o.save!
		end
		new_counter += 1
	end

	mobile,platform,browser = get_browser ua
	conditions = ["machine_id=? and time=? and platform=? and browser=?", machine,time,platform,browser]
	result = RankUseragent.update_all("counter=counter+1", conditions, :limit=>1)

	if (result == 0)
		RankUseragent.new do |o|
			o.machine_id = machine
			o.time = time
			o.mobile = mobile
			o.platform = platform
			o.browser = browser
			o.counter = 1
			o.save!
		end
		new_counter += 1
	end

	new_counter
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

puts "Started realtime server (with zmq #{ZMQ::Util.version.join('.')})."

zmq = EM::ZeroMQ::Context.new(1)

EM.run do
	# setup pull sockets
	pull_srv = zmq.socket(ZMQ::PULL)

	pull_srv.hwm = 10000
	pull_srv.swap = 1024 * 4 * 256

	# push_socket1.hwm = 40
	#puts "HWM: #{pull_srv.hwm}"
	#puts "SWAP: #{pull_srv.swap}"

	pull_srv.bind("tcp://#{host}:#{port}")

	pull_srv.on(:message) { |msg|
		incomming_realtime_message msg.copy_out_string
		msg.close
	}
end

puts "Completed."

