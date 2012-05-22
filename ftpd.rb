#
## Manzana-FTPd
## A featured FTP server written in Ruby
#
# version: 3 (2006-03-09)
#
# Original author:  chris wanstrath // chris@ozmm.org
# New author:  pablo merino // pablo.perso1995@gmail.com
# Old site:    http://github.com/defunkt/ftpd.rb
# New site:    http://github.com/pablo-merino/manzana-ftpd
#
# license: MIT License // http://www.opensource.org/licenses/mit-license.php
# copyright: (c) two thousand six chris wanstrath
#
# tested on: ruby 1.8.4 (2005-12-24) [powerpc-darwin8.4.0] | ruby 1.9.3-p125 (2012-05-22) [intel osx 10.7.3]
#
# special thanks:
#   - Chris Wanstrath for the original FTP implementation
#   - Peter Harris for his ftpd.py (Jacqueline FTP) script
#   - RFC 959 (ftp)
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

