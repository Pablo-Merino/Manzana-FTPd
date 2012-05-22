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

%w[socket logger yaml trollop ./core.rb ./ftp_commands.rb ./tools.rb].each { |f| require f }

Thread.abort_on_exception = true

opts = Trollop::options do
  opt :dir,     "FTP public dir",         :short => '-d',    :type => :string, :default => Dir.pwd
  opt :addr,    "Bind address",           :short => '-a',    :type => :string, :default => "127.0.0.1"
  opt :port,    "Bind port",              :short => '-p',    :type => :int,    :default => 22002
  opt :config,  "Config file",            :short => '-c',    :type => :string
  opt :clients, "Max clients number",     :short => '-m',    :type => :int,    :default => 100
  opt :users,   "Users and passwords",    :short => '-u',    :type => :string

end
if opts[:config]
  unless !File.exists?(opts[:config])
    opts = YAML::load(File.open(opts[:config]))
  end
end

server = FTPServer.new(opts)

