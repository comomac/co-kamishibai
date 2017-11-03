require 'zip/filesystem'
require 'gd2-ffij'
require 'json'
require 'cgi'

def create_config(path)
  # settings template
  t = {}
  t[:SRCS] = ['/books', '~/books']
  t[:IMG_RESIZE] = true
  t[:USERNAME] = 'admin'
  t[:PASSWORD] = 'password'
  t[:BIND] = '0.0.0.0'
  t[:PORT] = 4567
  t[:DEFAULT_IMAGE_QUALITY] = 60
  t[:DEFAULT_IMAGE_WIDTH] = 768
  t[:DEFAULT_IMAGE_HEIGHT] = 0
  t[:BOOKMARKS_FILE] = '~/var/co-kamishibai/bookmarks.json'

  save_config(t, path)
end

class CGI
  def unescape2(str)
    str = CGI::unescape(str)
    CGI::escape(str)
  end
end

def save_config( conf, path )
  unless FileTest.exists?( File.dirname( path ) )
    FileUtils.mkdir_p( File.dirname( path ) )
  end

  conf[:SRCS].collect { |src| File.expand_path(src) }
  conf[:BOOKMARKS_FILE] = File.expand_path( conf[:BOOKMARKS_FILE] )

  File.binwrite( path, JSON.pretty_generate( conf ) )

  puts "config created at #{path}"
end


# load settings from json config file
def load_config(path)
  json = JSON.parse( File.binread(path) )

  $SETTINGS = {}
  $SETTINGS[:SRCS] = json['SRCS'].collect { |src| File.expand_path(src) }
  $SETTINGS[:IMG_RESIZE] = json['IMG_RESIZE']
  $SETTINGS[:USERNAME] = json['USERNAME']
  $SETTINGS[:PASSWORD] = json['PASSWORD']
  $SETTINGS[:BIND] = json['BIND']
  $SETTINGS[:PORT] = json['PORT']
  $SETTINGS[:DEFAULT_IMAGE_QUALITY] = json['DEFAULT_IMAGE_QUALITY']
  $SETTINGS[:DEFAULT_IMAGE_WIDTH] = json['DEFAULT_IMAGE_WIDTH']
  $SETTINGS[:DEFAULT_IMAGE_HEIGHT] = json['DEFAULT_IMAGE_HEIGHT']
  $SETTINGS[:BOOKMARKS_FILE] = File.expand_path( json['BOOKMARKS_FILE'] )
end



# load bookmarks
# bookmarks format:   bookmarks[ book_basename ] = [ last_page, total_pages, bookcode ]
def load_bookmarks
  $bookmarks = {}
  $bookcodes = []

  # check if bookmark file exists
  if FileTest.file?( $SETTINGS[:BOOKMARKS_FILE] )
    fp = File.new( $SETTINGS[:BOOKMARKS_FILE], 'rb' )
    str = fp.read(2**26)
    fp.close
    $bookmarks = JSON.parse( str )
  end

  for bcbz, dat in $bookmarks
    $bookcodes << dat[2]
  end
end

# save bookmarks
def save_bookmarks
  return unless $bookmarks_dirty

  if ! FileTest.exists?( File.dirname( $SETTINGS[:BOOKMARKS_FILE] ) )
    FileUtils.mkdir_p( File.dirname( $SETTINGS[:BOOKMARKS_FILE] ) )
  end

  fp = File.new( $SETTINGS[:BOOKMARKS_FILE], 'wb' )
  fp.write( JSON.pretty_generate( $bookmarks ) )
  fp.close

  puts "bookmarks saved #{Time.now}" if $debug
  $bookmarks_dirty = false
end

# escape glob for string containing "[" and "]"
def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?]/) { |x| "\\"+x }
end


# generate unique char
def GenID(length)
  length = length.to_i
  return nil if length < 1

  s = ''
  w = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-' # 64 uniq chars

  while s.length < length
    s = s + w[rand(64)]
  end

  return s
end


# returns total number of pages for cbz file, and save bookmarks
def cbz_pages?( zfile )
  bcbz = File.basename( zfile )
  if $bookmarks[ bcbz ]
    return $bookmarks[ bcbz ][1]
  end

  objs = []
  Zip::File.open( zfile ) { |x|
    x.each { |i|
      if i.ftype == :file and File.basename( i.name ) =~ /^[^.].+?\.(jpg|jpeg|png|gif)$/i
        objs << i
      end
    }
  }

  # generate a unique bookcode, lookup bookcode existance by using db
  while true
    word = GenID(3)
    break unless $bookcodes.include?(word) # find next available word
  end
  #puts "#{word} - #{f}"

  $bookmarks[ bcbz ] = [ 1, objs.length, word ]
  $bookcodes << word

  $bookmarks_dirty = true

  return objs.length
end

# cbz file accessor, give file name and page and you shall receive
def open_cbz( zfile, page = 1, options = {} )
  width =   $SETTINGS[:DEFAULT_IMAGE_WIDTH]
  height =  $SETTINGS[:DEFAULT_IMAGE_HEIGHT]
  quality = $SETTINGS[:DEFAULT_IMAGE_QUALITY]

  objs = []
  Zip::File.open( zfile ) { |x|
    x.each { |i|
      if i.ftype == :file and File.basename( i.name ) =~ /^[^.].+?\.(jpg|jpeg|png)$/i
        objs << i
      end
    }

    if objs.length == 0
      halt "error: no image detected. #{zfile}"
      return nil
    elsif page > objs.length or page < 1
      not_found "no such page #{page}"
    else
      puts "reading image… #{zfile}" if $debug
      img = objs.sort[page-1].name
      simg = x.file.read(img)
      itype = img_type(simg)

      if ! $SETTINGS[:IMG_RESIZE]
        return itype, simg
      else
        simg = img_resize(simg, width, height, {:quality => quality})

        return itype, simg
      end
    end
  }
end


def img_type(data)
  case data[0..1]
    when "BM"
      :bmp
    when "GI"
      :gif
    when 0xff.chr + 0xd8.chr, "\xFF\xD8"
      :jpeg
    when 0x89.chr + "P", "\x89P"
      :png
    else
      raise UnknownImageType
    end
end

# all done in memory, but gives seg fault on some condition, png file for eg
def img_resize( dat, w, h, options = {} )
  quality = options[:quality]
  format = options[:format]

  begin
    img = GD2::Image.load(dat)
    if h == 0
      h = ( w / img.aspect ).to_i
    end

    puts "resizing image… width: #{w}, height: #{h}, quality: #{quality}" if $debug

    # make sure it doesn't upscale image
    res = img.size

    if res[0] < w and res[1] < h
      w = res[0]
      h = res[1]
    elsif res[0] < w
      w = res[0]
      h = (w / img.aspect).to_i
    elsif res[1] < h
      h = res[1]
      w = (h / img.aspect).to_i
    end

    nimg = img.resize( w, h )

    if img_type(dat) == :jpeg and quality
      nimg.jpeg( quality.to_i )
    else
      case img_type(dat)
        when :png
          nimg.png
        when :jpeg
          nimg.jpeg
        when :gif
          nimg.gif
        else
          raise 'img_resize(), unknown output format'
      end
    end
  rescue => errmsg
    puts "error: resize failed. #{w} #{h} #{quality}"
    p errmsg
    return nil
  end
end