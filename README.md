mqtt_rtx_traffic_pub.rb
====
Publish router status script for YAMAHA RTX router series.

how to use
====
<pre>
$ gem install mqtt
$ gem install pit

$ cd ~/work/
$ git clone https://github.com/yoggy/mqtt_rtx_traffic_pub.git
$ cd mqtt_rtx_traffic_pub
$ EDITOR=vi ./mqtt_rtx_traffic_pub.rb

  #### configure MQTT & RTX parameters ####

$ crontab -e
  
  #### append this line ####
  */10 * * * *  ~/work/mqtt_rtx_traffic_pub/mqtt_rtx_traffic_pub.rb 2>&1 >/dev/null
</pre>


