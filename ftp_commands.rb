#
## Manzana-FTPd
## A featured FTP server written in Ruby
#
# version: 4 (2012-05-22)
#
# Original author:  chris wanstrath // chris@ozmm.org
# New author:  pablo merino // pablo.perso1995@gmail.com
# Old site:    http://github.com/defunkt/ftpd.rb
# New site:    http://github.com/pablo-merino/manzana-ftpd
#
# license: MIT License // http://www.opensource.org/licenses/mit-license.php
# copyright: (c) two thousand six chris wanstrath | two thousand twelve pablo merino
#
# tested on: ruby 1.8.4 (2005-12-24) [powerpc-darwin8.4.0] | ruby 1.9.3-p125 (2012-05-22) [intel osx 10.7.3]
#
# special thanks:
#   - Chris Wanstrath for the original FTP implementation
#   - Peter Harris for his ftpd.py (Jacqueline FTP) script
#   - RFC 959 (ftp)
#

class FTPServer < TCPServer
  # login
  def user(msg)
    unless @users
      return "502 Only anonymous user implemented" if msg != 'anonymous'
    end
    
    #log "[#{remote_addr}] User #{msg} logged in."
    thread[:user] = msg  
    "331 User name okay, need password."
    
  end
  
  def pass(msg)
    if check_username_password(thread[:user], msg)
      "230 User logged in, proceed."
    else
      "530 Not logged in."
    end
  end

  # open up a port / socket to send data
  def port(msg)
    nums = msg.split(',')
    port = nums[4].to_i * 256 + nums[5].to_i
    host = nums[0..3].join('.')
    if thread[:datasocket]
      thread[:datasocket].close
      thread[:datasocket] = nil
    end
    thread[:datasocket] = TCPSocket.new(host, port)
    debug "[DEBUG] Opened passive connection at #{host}:#{port}"
    "200 Passive connection established (#{port})"
  end
  
  # listen on a port
  def pasv(msg)
    "500 pasv not yet implemented"
  end
  
  # retrieve a file
  def retr(msg)
    response "125 Data transfer starting"
    if File.exists?("#{Dir.pwd}/#{msg}")
      bytes = send_data(File.read("#{Dir.pwd}/#{msg}"))
    else
      "553 File doesn't exist" 
    end

    "226 Closing data connection, sent #{bytes} bytes"      
  end
  
  # upload a file
  def stor(msg)
    data = ""
    response "125 Data transfer starting"

    data = thread[:datasocket].read
    bytes = data.length


    f = File.open("#{Dir.pwd}/#{msg}", 'w') do |f|
      f.write(data)
    end
    log "[#{remote_addr}] #{thread[:user]} created file #{Dir.pwd}/#{msg}"
    "200 OK, received #{bytes} bytes"
     
  end
  
  # make directory
  def mkd(msg)
    msg = msg.join(" ") if msg.is_a? Array

    return %[521 "#{msg}" already exists] if File.directory? msg
    Dir.mkdir(msg)
    debug "[DEBUG] #{thread[:user]} created directory #{Dir::pwd}/#{msg}"
    "257 \"#{msg}\" created"
  end
  
  # crazy site command
  def site(msg)
    command = (msg.is_a?(Array) ? msg[0] : msg).downcase
    case command
      when 'chmod'
        File.chmod(msg[1].oct, msg[2])
        return "200 CHMOD of #{msg[2]} to #{msg[1]} successful"
    end
    "502 Command not implemented"
  end
  
  # wrapper for rmd
  def dele(msg); rmd(msg); end
  
  # delete a file / dir
  def rmd(msg)
    msg = msg.join(" ") if msg.is_a? Array

    if File.directory? msg
      Dir::delete msg
    elsif File.file? msg
      File::delete msg
    end
    log "[DEBUG] #{thread[:user]} deleted #{Dir::pwd}/#{msg}"
    "200 OK, deleted #{msg}"
  end
  
  # file size in bytes
  def size(msg)
    debug "#{Dir.pwd}/#{msg}: #{File.exists?("#{Dir.pwd}/#{msg}")}"
    if File.exists?("#{Dir.pwd}/#{msg}")
      bytes = File.size(msg)
      "#{msg} #{bytes}"
    else
      "553 File doesn't exist" 
    end

  end
  
  # report the name of the server
  def syst(msg)
    "215 UNIX #{PROGRAM} v#{VERSION} "
  end
  
  # list files in current directory
  def list(msg)
    response "125 Opening ASCII mode data connection for file list"
    send_data(`ls -l`.split("\n").join(LBRK) << LBRK)
    "226 Transfer complete"
  end
  
  # crazy tab nlst command
  def nlst(msg)
    Dir["*"].join " "   
  end
  
  # print the current directory
  def pwd(msg)
    %[257 "#{Dir.pwd}" is the current directory]
  end
  
  # change directory
  def cwd(msg)
    msg = msg.join(" ") if msg.is_a? Array
    begin
      Dir.chdir(msg)
    rescue Errno::ENOENT
      "550 Directory not found"
    else 
      "250 Directory changed to " << Dir.pwd
    end
  end
  
  # go up a directory, really just an alias
  def cdup(msg)
    cwd('..')
  end
  
  # ascii / binary mode
  def type(msg)
    if msg == "A"
       thread[:mode] == :ascii
      "200 Type set to ASCII"
    elsif msg == "I"
      thread[:mode] == :binary  
      "200 Type set to binary"
    end
  end
  
  # quit the ftp session
  def quit(msg = false)
    thread[:socket].close
    thread[:socket] = nil
    debug "[DEBUG] User #{thread[:user]} disconnected."
    "221 Laterz"
  end

  def rnfr(msg)
    msg = msg.join(" ") if msg.is_a? Array
    @rnfr_file = "#{msg}"
    "350 Requested file action pending further information."
  end
  
  def rnto(msg)
    msg = msg.join(" ") if msg.is_a? Array
    File.rename(@rnfr_file, "#{msg}")
    "250 File renamed."
  end
  # help!
  def help(msg)
    commands = COMMANDS
    commands.sort!
    response "214-"
    response "  The following commands are recognized."
    i   = 1
    str = "  "
    commands.each do |c|
      str += "#{c}"
      str += "\t\t"
      str += LBRK << "  " if (i % 3) == 0      
      i   += 1
    end
    response str
    "214 Send comments to #{AUTHOR_EMAIL}"
  end
  
  # no operation
  def noop(msg); "200 "; end
end