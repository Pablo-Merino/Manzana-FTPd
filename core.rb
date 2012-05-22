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

  PROGRAM      = "Manzana-FTPd"  
  VERSION      = 4
  AUTHOR       = ["Chris Wanstrath", "Pablo Merino"]
  AUTHOR_EMAIL = ["chris@ozmm.org", "pablo.perso1995@gmail.com"]
  
  LBRK = "\r\n" # ftp protocol says this is a line break
  
  # commands supported
  COMMANDS = %w[quit type user pass retr stor port cdup cwd dele rmd pwd list size
                syst site mkd rnfr rnto]
  
  # setup a TCPServer instance and house our main loop
  def initialize(config)
    host = config[:addr]
    port = config[:port]

    @config  = config
    @config[:debug] = false
    
    if config[:users]
      @users = YAML::load(File.open(config[:users]))
    else
      @users = false
    end

    @threads = []
    
    begin
      server = super(host, port)
    rescue Errno::EACCES
      debug "[ERROR] The port you have chosen is already in use or reserved."
      return
    end
    
    @status  = :alive

    log "Server started successfully at ftp://#{host}:#{port} [PID: #{Process.pid}]"
    
    # periodically check for inactive connections and kill them
    kill_dead_connections
    if config[:dir]
      Dir.chdir(config[:dir])
    end
    while (@status == :alive)
      begin
        socket  = server.accept
        clients = 0
        @threads.each { |t| clients += 1 if t.alive? }
        if clients >= @config[:clients]
          socket.print "530 Too many connections" << LBRK
          socket.close
        else
          @threads << threaded_connection(socket)
        end
        
      rescue Interrupt
        @status = :dead
      rescue Exception => ex
        @status = :dead
        request ||= 'No request'
        log "#{ex.class}: #{ex.message} - #{request}\n\t#{ex.backtrace[0]}"
      end
    end
    
    log "Shutting server down..."
    
    # clean up anything we've still got open - a simple join won't work because
    # we may still have open sockets, which we need to terminate
    @threads.each do |t|
      next if t.alive? == false
      sk = t[:socket]
      sk.close unless sk.nil? or sk.closed? or sk.is_a?(Socket) == false
      t[:socket] = sk = nil
      t.kill
    end
    server.close
  end
  
  private
  
  def threaded_connection(sock)
    Thread.new(sock) do |socket|
      thread[:socket] = socket
      thread[:mode]   = :binary
      info = socket.peeraddr
      remote_port, remote_ip = info[1], info[3]
      thread[:addr]  = [remote_ip, remote_port]
      debug "[DEBUG] Got connection #{remote_ip}:#{remote_port}"
      response "200 #{@config[:addr]}:#{@config[:port]} FTP server " \
               "(#{PROGRAM}) ready."
      while socket.nil? == false and socket.closed? == false
        request = socket.gets
        response handler(request)
      end
    end    
  end
  
  # send a message to the client
  def response(msg)
    sock = thread[:socket]
    sock.print msg << LBRK unless msg.nil? or sock.nil? or sock.closed?
  end
  
  # deals with the user input
  def handler(request)
    stamp!
    return if request.nil? or request.to_s == ''
    begin
      command = request[0,4].downcase.strip
      rqarray = request.split
      message = rqarray.length > 2 ? rqarray[1..rqarray.length] : rqarray[1]
      debug "[DEBUG] Request: #{command}(#{message})"
      case command
        when *COMMANDS
          __send__ command, message
        else
          bad_command command, message
      end
    rescue Errno::EACCES, Errno::EPERM
      "553 Permission denied"
    rescue Errno::ENOENT
      "553 File doesn't exist" 
    rescue Exception => e
      debug "[DEBUG] Request: #{request}"
      log "[ERROR] #{e.class} - #{e.message}\n\t#{e.backtrace[0]}"
      exit!
    end

  end
  
  # periodically kill inactive connections
  def kill_dead_connections
    Thread.new do
      loop do
        @threads.delete_if do |t|
          if Time.now - t[:stamp] > 400
            t[:socket].close
            t.kill
            debug "[DEBUG] Killed inactive connection."
            true
          end
        end
        sleep 20
      end
    end    
  end
  
  # set a timestamp (user's last action)
  def stamp!; thread[:stamp] = Time.now end  
  
  # Thread.current wrapper
  def thread; Thread.current end
  
  #
  # logging functions
  #
  
  def log(msg)
    Kernel.puts msg
  end

  def debug(msg)
    if @config[:debug]
      Kernel.puts msg
    end
  end
  # where the user's from
  def remote_addr; thread[:addr].join(':') end
  
  # thread count
  def show_threads
    threads = 0
    @threads.each { |t| threads += 1 if t.alive? }
    threads
  end
  
  # command not understood
  def bad_command(name, *params)
    arg = (params.is_a? Array) ? params.join(' ') : params
    if @config[:debug]
      "500 I don't understand " << name.to_s << "(" << arg << ")"
    else
      "500 Sorry, I don't understand #{name.to_s}"
    end
  end
  
  #
  # actions a user can perform
  #
  # all of these methods are expected to return a string
  # which will then be sent to the client.
  #
  
  # send data over a connection
  def send_data(data)
    bytes = 0
    begin
      # this is where we do ascii / binary modes, if we ever get that far
      if data.is_a? String
        if thread[:mode] == :binary
          bytes = data.size

          thread[:datasocket].syswrite(data)
        else
          thread[:datasocket].send(data, 0)
        end
      else
        data.each do |line|
          if thread[:mode] == :binary
            thread[:datasocket].syswrite(line)
          else
            thread[:datasocket].send(line, 0)
          end
          bytes += line.length
        end
      end
    rescue Errno::EPIPE
      log "[#{remote_addr}] #{thread[:user]} aborted file transfer"  
      return quit
    else
      log "[#{remote_addr}] #{thread[:user]} got #{bytes} bytes"
    ensure
      thread[:datasocket].close
      thread[:datasocket] = nil    
    end
    bytes
  end


  #
  # graveyard -- non implemented features with no plans
  #
  def mode(msg)
    "202 Stream mode only supported"
  end
  
  def stru(msg)
    "202 File structure only supported"
  end



end
