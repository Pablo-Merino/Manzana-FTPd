class FTPServer < TCPServer
  def check_username_password(username, password)
    @users.each do |h|
      if h[:username] == username
      	return h[:password] == password
      end
    end
  end
end