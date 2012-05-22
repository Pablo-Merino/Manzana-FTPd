#
## ftpd.rb
## a simple ruby ftp server
#
# version: 3 (2006-03-09)
#
# author:  chris wanstrath // chris@ozmm.org
# site:    http://github.com/defunkt/ftpd.rb
#
# license: MIT License // http://www.opensource.org/licenses/mit-license.php
# copyright: (c) two thousand six chris wanstrath
#
# tested on: ruby 1.8.4 (2005-12-24) [powerpc-darwin8.4.0]
#
# special thanks:
#   - Peter Harris for his ftpd.py (Jacqueline FTP) script
#   - RFC 959 (ftp)
#
# get started:  
#  $ ruby ftpd.rb --help
#

%w[socket logger optparse yaml ./core.rb].each { |f| require f }

Thread.abort_on_exception = true

class FTPConfig
  
  #
  # command line option business
  #
  def self.parse_options(args)
    config = Hash.new
    config[:d]            = Hash.new    # the defaults
    config[:d][:host]     = "127.0.0.1"
    config[:d][:port]     = 21
    config[:d][:clients]  = 5
    config[:d][:yaml_cfg] = "ftpd.yml"
    config[:d][:debug]    = false
    
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{FTPServer::PROGRAM} [options]"

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-h", "--host HOST", 
              "The hostname or ip of the host to bind to " << \
              "(default 127.0.0.1)") do |host|
        config[:host] = host
      end
      
      opts.on("-p", "--port PORT", 
              "The port to listen on (default 21)") do |port|
        config[:port] = port
      end
      
      opts.on("-c", "--clients NUM", Integer,
              "The number of connections to allow at once (default 5)") do |c|
        config[:clients] = c
      end
      
      opts.on("--config FILE", "Load configuration from YAML file") do |file|
        config[:yaml_cfg] = file
      end
      
      opts.on("--sample", "See a sample YAML config file") do
        sample = Hash.new
        config[:d].each do |k, v| 
          sample = sample.merge(k.to_s => v) unless k == :yaml_cfg
        end
        puts YAML::dump( sample )
        exit
      end
      
      opts.on("-d", "--debug", "Turn on debugging mode") do
        config[:debug] = true
      end

      opts.separator ""
      opts.separator "Common options:"

      opts.on_tail("--help", "Show this message") do
        puts opts
        exit
      end

      opts.on_tail("-v", "--version", "Show version") do
        puts "#{FTPServer::PROGRAM} FTP server v#{FTPServer::VERSION}"
        exit
      end  
    end
    opts.parse!(args)
    config
  end
  
end

#
# config
#
if $0 == __FILE__ 
  # gather config options
  config = FTPConfig.parse_options(ARGV)

  # try and get name for yaml config file from command line or defaults
  config_file = config[:yaml_cfg] || config[:d][:yaml_cfg]

  # if file exists, override default options with arguments from it
  if File.file? config_file
    yaml = YAML.load(File.open(config_file, "r"))
    yaml.each { |k,v| config[k.to_sym] ||= v }
  end

  # now fill in missing config options from the default set
  config[:d].each { |k,v| config[k.to_sym] ||= v }

  # run the daemon
  server = FTPServer.new(config)
end
