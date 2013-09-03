# Simple http server that handles post, get and head requests
# Author::    Paul Giletich (paul.giletich@gmail.com)
# Copyright:: Copyright (c) 2002 GNU
# License::   Distributes under the same terms as Ruby


require 'socket'
require 'cgi'

# This class holds all you need to handle some of http requests
class HttpServer

	# Server constructor, initialises server
	# port::: port at which server will be initialised
	# basePath::: path to folder with html's

	def initialize(port, basePath)
		@basePath = basePath
		@server = TCPServer.new(port)
		@logfile = basePath + "/log.txt"
		@log = ""
		log("Server started at #{Time.new}\nbase path: #{basePath}\nport: #{port}")
		run
	end

	# Runs server. For each request the new thread is created
	def run
		loop do
			Thread.start(@server.accept) do |session|
				serve session
			end
		end
	end

	# Serves session (socket), determines request type and moves handling to corresponding handler
	# session::: http socket corresponding to current session
	def serve(session)
		request = ""
		line = ""
		until line == "\r\n"
			line = session.gets
			request += line
		end
		return head(session, request)	if request =~ /HEAD .* HTTP.*/
		return post(session, request)	if request =~ /POST .* HTTP.*/
		return get(session, request)	if request =~ /GET .* HTTP.*/
	rescue => exception
		return errorReport(session, exception)
	end

	# Serves head requests
	# session::: http socket corresponding to current session
	# request::: session request
	def head(session, request)
		fullPath = @basePath + request.gsub(/HEAD /, '').gsub(/ HTTP.*/m, '')
		if File.exists?(fullPath)
			header = ["HTTP/1.0 200/OK",
				"Date: #{Time.new.utc}",
				"Server: My Server",
				"Last-modified: #{File.mtime(fullPath).utc}",
				"Content-type: #{getContentType(fullPath)}",
				"Content-Length: #{File.size(fullPath)}",
				"\r\n"].join("\r\n")
			session.puts header
		else
			header = ["HTTP/1.0 404/Object Not Found", 
				"Server: My Server\r\n\r\n"].join("\r\n")
			session.puts header
			writeFile session, @basePath + '//404.htm'
		end
		session.close
		log "===REQUEST===", request, "===RESPONSE===", header
	end

	# Serves get requests
	def get(session, request)
		fullPath = @basePath + request.gsub(/GET /, '').gsub(/ HTTP.*/m, '')
		if fullPath == (@basePath + '/')
			fullPath = @basePath + '/index.htm'
		end
		if File.exists?(fullPath)
			header = ["HTTP/1.0 200/OK",
				"Date: #{Time.new.utc}",
				"Server: My Server",
				"Last-modified: #{File.mtime(fullPath).utc}",
				"Content-type: #{getContentType(fullPath)}",
				"Content-Length: #{File.size(fullPath)}",
				"\r\n"].join("\r\n")
			session.puts header
			writeFile(session, fullPath)
		else
			header = ["HTTP/1.0 404/Object Not Found", 
				"Server: My Server\r\n\r\n"].join("\r\n")
			session.puts header
			writeFile session, @basePath + '//404.htm'
		end
		session.close
		log "===REQUEST===", request, "===RESPONSE===", header
	end

	# Returns error page
	def errorReport(session, exception)
		header = ["HTTP/1.0 500/Internal Server Error", 
				"Server: My Server\r\n\r\n"].join("\r\n")
		session.puts header
		writeFile session, @basePath + '//500.htm'
		session.puts exception.message
		session.puts exception.backtrace
		session.close
		log exception.message, exception.backtrace
		log "===RESPONSE===", header
	end

	# Serves post request
	def post(session, request)
		header = ["HTTP/1.0 200/OK",
			"Date: #{Time.new.utc}",
			"Server: My Server",
			"\r\n"].join("\r\n")
		content_length = request[/Content-Length: (.*)/, 1]
		body = session.read(content_length.to_i)
		params = CGI.parse(body)
		session.puts header
		session.puts "Post parameters:"
		params.each do |key, value|
			session.puts "#{key}: #{value[0]}<br>"
		end
		session.close
		log "===RESPONSE===", header
	end

	# Writes file to stream
	def writeFile(session, fullPath)
		File.open(fullPath, "rb") do |src|
			until src.eof?
				session.write(src.read(256))
			end
		end
	end

	# Returns content type for file
	def getContentType(path)
	    ext = File.extname(path)
	    return "text/css"   if ext == ".css"
	    return "image/jpeg" if ext == ".jpeg" or ext == ".jpg"
	    return "image/png" 	if ext == ".png"
	    return "image/gif"  if ext == ".gif"
	    return "text/html"  #if ext == ".html" or ext == ".htm" #in all other cases
	end

	# Logs message to console and to a logfile in html dir
	def log(*messages)
		for message in messages
			puts message
		end
	end
end

server = HttpServer.new(ARGV[0], ARGV[1])