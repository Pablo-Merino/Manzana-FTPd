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


class FTPServer < TCPServer
  def check_username_password(username, password)
    @users.each do |h|
      if h[:username] == username
      	return h[:password] == password
      end
    end
  end
end