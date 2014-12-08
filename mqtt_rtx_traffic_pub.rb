#!/usr/bin/ruby

require 'rubygems'
require 'mqtt'
require 'pit'
require 'json'
require 'net/telnet'
require 'bigdecimal'
require 'pstore'
require 'pp'

$db_path = File.dirname(__FILE__) + "/rtx_status.db"

class RTXStatus
	def initialize(host, port, password, lan)
		@host     = host
		@port     = port
		@password = password
		@lan      = lan
		#@debug    = true
	end

	def update
		if @password.nil?
			STDERR.puts "error : password is nil..."
			return false
		end

		t = Net::Telnet.new("Host"=>@host, "Port"=>@port, "Timeout"=>60);
		t.waitfor(/Password/)  {|c| }
		t.cmd(@password) {|c|
			if c =~ /Incorrect password/
				STDERR.puts "error : Incorrect password..."
				return false
			end
			print l if @debug
		}

		current_tx = 0
		current_rx = 0

		t.cmd("show status #{@lan}") {|c|
			c.each_line {|l|
				if l =~ /^Transmitted:\s+([0-9]+) packets \(([0-9]+) octets\)/
					current_tx = $2.to_i
				end
				if l =~ /^Received:\s+([0-9]+) packets \(([0-9]+) octets\)/
					current_rx = $2.to_i
				end
				print l if @debug
			}
		}

		current_time = Time.now

		db = PStore.new($db_path)
		db.transaction {
			if !db['old_tx'].nil? &&  !db['old_rx'].nil? && !db['old_time'].nil?
				@tx = current_tx - db['old_tx']
				@rx = current_rx - db['old_rx']
				@tx = 0 if @tx < 0
				@rx = 0 if @rx < 0

				@interval = (current_time - db['old_time']).to_i
				@tx_kbps = @tx / @interval / 1024
				@rx_kbps = @rx / @interval / 1024
			end
			db['old_tx']   = current_tx
			db['old_rx']   = current_rx
			db['old_time'] = current_time
		}

		t.cmd("quit") {|c|
			print c if @debug
		}
		true
	end

	attr_reader :tx, :rx, :tx_kbps, :rx_kbps, :interval
end


$conf_rtx = Pit.get("rtx_info", :require => {
	"host"     => "rtx.example.com",
	"port"     => 23,
	"password" => "password",
	"lan"      => "lan2",
})

#  
rtx = RTXStatus.new($conf_rtx['host'], $conf_rtx['port'], $conf_rtx['password'], $conf_rtx['lan'])
rtx.update

$config = Pit.get("mqtt_rtx_pub", :require => {
	"remote_host" => "mqtt.example.com",
	"remote_port" => 1883,
	"username" => "username",
	"password" => "password",
	"topic" => "topic",
})
$conn_opts = {
	remote_host: $config["remote_host"],
	remote_port: $config["remote_port"].to_i,
	username: $config["username"],
	password: $config["password"],
}

h = {}
h["rx_kbps"] = rtx.rx_kbps
h["tx_kbps"] = rtx.tx_kbps

json_str = JSON.generate(h)
puts json_str
MQTT::Client.connect($conn_opts) do |c|
	c.publish($config["topic"], json_str)
end

