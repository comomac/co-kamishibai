# encoding: utf-8

if RUBY_VERSION <= "1.9"
	puts "Require Ruby at least 1.9"
	exit
end

# making sure program runs in UTF-8 encoding in any environment
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'rubygems'
llf = File.dirname(__FILE__) + '/co-kamishibai/functions.rb'
if FileTest.exists?(llf)
	load llf
else
	require 'co-kamishibai/functions'
end
require 'thread'
require 'sinatra/base'
require 'sinatra/reloader' if $debug
require 'haml'

# worker thread for saving bookmarks
# kick off initial save
$bookmarks_dirty = true
Thread.new {
	while true
		save_bookmarks
		sleep 60
	end
}

class CoKamishibai < Sinatra::Base
	# shutdown hook, save bookmarks when exiting
	at_exit do
		save_bookmarks
	end

	if $debug
		register Sinatra::Reloader

		also_reload 'kamishibai/functions'
		also_reload 'kamishibai/patches'
	end

	# setup listening
	set :bind, $SETTINGS[:BIND]
	set :port, $SETTINGS[:PORT]
	set :server, 'thin'

	# enable session support
	enable :sessions
	use Rack::Session::Pool, :expire_after => 60*60*24*365

	# setup public folder location
	set :public_folder, settings.root + '/pub'

	# setup template location
	set :views, settings.root + '/views'

	configure do
		mime_type :jpeg, 'image/jpeg'
		mime_type :png, 'image/png'
		mime_type :gif, 'image/gif'
		mime_type :css, 'text/css'
		mime_type :javascript, 'application/javascript'
	end

	# authentication
	before do
		# make sure client is logged in, otherwise show login page
		unless session['user_name']
			if request.path != '/login'
				redirect "/login?redirect=#{request.path}?#{request.query_string}"
			end
		end
	end

	# login page
	get '/login' do
		haml :login
	end

	# submitted from login page
	post '/login' do
		if params[:username] == $SETTINGS[:USERNAME] && params[:password] == $SETTINGS[:PASSWORD]
			session['user_name'] = params[:username]

			# make sure it resume exactly where it left off
			if params[:url_redirect]
				redirect params[:url_redirect]
			else
				redirect '/'
			end
		else
			"login failed!"
		end
	end

	# redirect index
	get '/' do
		redirect '/browse/'
	end

	# cbz file reader
	get '/cbz/*' do
		cache_control :public, :must_revalidate, :max_age => 3600

		# requesting this way because block will convert '+' into ' ' instead, may also happen to other characters
		cbz = CGI::unescape( request.env['REQUEST_PATH'].sub(/^\/cbz\//,'') )

		quality = $SETTINGS[:DEFAULT_IMAGE_QUALITY]
		width =   $SETTINGS[:DEFAULT_IMAGE_WIDTH]
		height =  $SETTINGS[:DEFAULT_IMAGE_HEIGHT]

		src = $srcs[params[:s].to_i] || $srcs[0]
		cbz = src + '/' + cbz
		page = params[:p].to_i

		if File.extname( cbz ) == '.cbz' and FileTest.file?( cbz )
			itype, image = open_cbz( cbz, page, { :quality => quality, :width => width, :height => height } )
			case itype
				when :jpeg
					content_type :jpeg
				when :png
					content_type :png
				when :gif
					content_type :gif
				else
					halt "no supported image. #{cbz}"
			end
			return image
		else
			not_found "no such file. #{cbz}"
		end
	end

	# reader page
	get '/reader/*' do
		# requesting this way because block will convert '+' into ' ' instead, may also happen to other characters
		cbz = CGI::unescape( request.env['REQUEST_PATH'].sub(/^\/reader\//,'') )

		src = $srcs[params[:s].to_i]
		@src = params[:s].to_i || 0
		@cbz = cbz
		@page = params[:p].to_i
		@pages = cbz_pages?( src + '/' + cbz )
		# prevent page go out of range
		@page = 1 if @page <= 0
		@page = @pages if @page > @pages

		haml :reader
	end


	# browse directory
	get '/browse/*' do
		# requesting this way because block will convert '+' into ' ' instead, may also happen to other characters
		d = CGI::unescape( request.env['REQUEST_PATH'].sub(/^\/browse\//,'') )

		s = params[:s].to_i
		src = $srcs[params[:s].to_i] || $srcs[0]
		@dir = File.expand_path(src + '/' + d)
		unless @dir =~ /^#{src}/
			halt 'not allowed here'
		end
		# relative path
		@rdir = @dir.sub(/^#{src}\//,'')
		@rdir = '/' if @rdir =~ /^#{src}/

		i = -1
		@srcs = $srcs.collect {
			i+=1
			"<a href=\"/browse/?s=#{i}\">src#{i}</a>&nbsp;&nbsp;\n"
		}

		puts "browse #{@dir}" if $debug

		if FileTest.directory?( @dir )
			@lists = []

			@lists << "<a href=\"/browse/#{ CGI::escape( File.expand_path('/' + @rdir + '/..').gsub(/\/+/,'/').gsub(/^\//,'') ) }?s=#{s}\">..</a>\n"

			for fp in Dir.glob( escape_glob(@dir) + '/*' )
				f = File.basename(fp)
				rp = fp.sub(/^#{src}\//,'')

				if FileTest.directory?( fp )
					@lists << "<a href=\"/browse/#{ CGI::escape( rp ) }?s=#{s}\">#{f}</a>\n"
				elsif File.extname( fp ) == '.cbz'
					bcbz = File.basename( fp )
					if $bookmarks[bcbz]
						o = $bookmarks[bcbz]

						if o[0] == o[1]
							# book finished reading
							@lists << "<a class=\"read\" href=\"/reader/#{ CGI::escape( rp ) }?s=#{s}&p=#{o[0]}\">#{f}</a>\n"
						else
							@lists << "<a href=\"/reader/#{ CGI::escape( rp ) }?s=#{s}&p=#{o[0]}\">#{f}</a>\n"
						end
					else
						@lists << "<a href=\"/reader/#{ CGI::escape( rp ) }?s=#{s}\">#{f}</a>\n"
					end
				else
					next
				end
			end

			haml :browse
		end
	end

	get '/setbookmark/*/*' do |page, cbz|
		cbz = File.basename( CGI::unescape(cbz) )
		page = page.to_i

		o = $bookmarks[ cbz ]
		$bookmarks[ cbz ] = [ page, o[1], o[2] ]
		$bookmarks_dirty = true

		"bookmarked #{page} #{cbz}" if $debug
	end
end
