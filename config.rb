###
# Sprockets
###
require 'rake/file_list'
require 'pathname'

bower_directory = 'source/bower_components'

# Build search patterns
patterns = [
  '.png',  '.gif', '.jpg', '.jpeg', '.svg', # Images
  '.eot',  '.otf', '.svc', '.woff', '.ttf', # Fonts
  '.js',                                    # Javascript
].map { |e| File.join(bower_directory, "**", "*#{e}" ) }

# Create file list and exclude unwanted files
Rake::FileList.new(*patterns) do |l|
  l.exclude(/src/)
  l.exclude(/test/)
  l.exclude(/demo/)
  l.exclude { |f| !File.file? f }
end.each do |f|
  # Import relative paths
  sprockets.import_asset(Pathname.new(f).relative_path_from(Pathname.new(bower_directory)))
end

###
# Compass
###

compass_config do |config|
  # Require any additional compass plugins here.
  config.add_import_path "bower_components"
  config.add_import_path "bower_components/foundation/scss"
  config.add_import_path "bower_components/foundation-3/stylesheets"
  config.add_import_path "bower_components/normalize/"
  config.add_import_path "bower_components/bxslider-4/"
  
  # Set this to the root of your project when deployed:
  config.http_path = "/new04/biodiscovery/"
  config.css_dir = "stylesheets"
  config.sass_dir = "stylesheets"
  config.images_dir = "images"
  config.javascripts_dir = "javascripts"
  # config.layout_dir = "layouts"

  # You can select your preferred output style here (can be overridden via the command line):
  # output_style = :expanded or :nested or :compact or :compressed

  # To enable relative paths to assets via compass helper functions. Uncomment:
  # relative_assets = true

end

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
page "index.html", :layout => "home-page"

# data.pages.each do |page|
#   proxy "/#{page.url}.html", "/.html", :locals => { :title => page.title }, ignore => true
# end

#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end

# Proxy pages (http://middlemanapp.com/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", :locals => {
#  :which_fake_page => "Rendering a fake page with a local variable" }

# Reload the browser automatically whenever files change
activate :livereload
activate :directory_indexes

set :http_prefix, "/"
set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'

set :haml, { :ugly => true, :format => :html5 }

helpers do
  class Event
    attr_reader :location, :time, :speaker, :event_type, :title

    def initialize(location, time, speaker, event_type, title)
      @location = location
      @time = time
      @speaker = speaker
      @event_type = event_type
      @title = title
    end

    def ==(other)
      self.class === other and
      other.location == @location and
      other.time == @time and
      other.speaker == @speaker and
      other.event_type == @event_type and
      other.title == @title
    end

    alias eql? ==

    def hash
      @location.hash ^ @time.hash ^ @speaker.hash ^ @event_type.hash ^ @title.hash #XOR
    end
  end

  def current_page?(page)
    if page.title == current_page.data.title
      return true
    else
      return false
    end
  end

  def current_page_is_a_sub_page?(page)
    is_sub_page = false                     # set the switch in the off position

    if page.sub_pages?
      page.sub_pages.each do |sub|
        if sub.title == current_page.data.title # if we are on the sub page
          is_sub_page = true                  # trip the switch
        end
      end
    end
    return is_sub_page                      # return the switch's state (true or false)
  end

  def test_values_compared_in_cp_vs_subpage(page)
    a = ""
    page.sub_pages.each do |sub|
      a+="<p>#{sub.title}, #{current_page.data.title} "
      a+="is #{sub.title == current_page.data.title}</p>"
    end
    return a
  end

  def rss_feed
    feed = Feedjira::Feed::fetch_and_parse("https://colleges.moss.drexel.edu/biomed/news/_layouts/listfeed.aspx?List=%7B9F69F06D-EE35-4190-B980-BAEFD51F908A%7D")
    feed.entries.each do |entry|
      # Alias for entry.summary 
        es = entry.summary
      # Clean up data
        es.gsub!(":</b> \n", ":</b> ")
        # es.gsub!("<b>Time", "\n<b>Time")
        es.gsub!('<div>','')
        es.gsub!('</div>','')
      # Remove new lines
        10.times do
          es.gsub!("\n\n", "")
        end
      # Remove labels
        # es.gsub!(/<b(.{3,22})b>/, "")
      # Decode HTML Entities
        es = HTMLEntities.new.decode es
      # Remove extra whitespace
        # es.lstrip!
      # Split string into array
        a = es.lines
      # Conditional fix formatting errors
        if a[0].include?("<b>Time") == true
          # Separate to 2 lines
            a_split = a[0].gsub!("<b>Time", "-<b>Time").split("-")
            a.shift
            a.insert(0, a_split[0], a_split[1])
        end

        if !(a[1].include?("<b>Time")) == true
          a_concat = [a[0], a[1]].join
          a_concat.gsub!("\n", ' ').squeeze!(' ')
          a.shift(2)
          a.insert(0, a_concat)
        end

        puts "1: " + a[0]
        puts "2: " + a[1]
        puts "3: " + a[2]
        puts "4: " + a[3]
        # puts "5: " + a[4]
        puts "__________"

      # Map Array to hash
      # event = Event.new location, time, speaker, event_type, title
      # Push hash onto array
      # puts event.inspect
    end
  end
  # Return array of Event hashes
end


# Add bower's directory to sprockets asset path
after_configuration do
  @bower_config = JSON.parse(IO.read("#{root}/.bowerrc"))
  sprockets.append_path File.join "#{root}", @bower_config["directory"]
end

activate :deploy do |deploy|
  # ...
  deploy.build_before = false # default: false

  deploy.method   = :ftp
  deploy.host     = "biomed.drexel.edu"
  deploy.path     = "/new04/biodiscovery"
  deploy.user     = "DREXEL\\drm68"
  deploy.password = "1d5SrAJb"
end


# Build-specific configuration
configure :build do
  # Ignore irrelevant directories during build 
  ignore 'bower_components/**'

  # For example, change the Compass output style for deployment
  # activate :minify_css

  # Minify Javascript on build
  # activate :minify_javascript

  # Enable cache buster
  # activate :asset_hash

  # Use relative URLs
  # activate :relative_assets
  # set :relative_links, true

  # Or use a different image path
  set :http_prefix, "/new04/biodiscovery/"
end
