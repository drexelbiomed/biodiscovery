###
# Sprockets
###
require 'rake/file_list'
require 'pathname'
require 'date'
require 'httparty'

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
  class Seminar
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
    xml = HTTParty.get('https://colleges.moss.drexel.edu/biomed/news/_layouts/listfeed.aspx?List=%7B9F69F06D-EE35-4190-B980-BAEFD51F908A%7D').body
    feed = Feedjira.parse(xml)
    events = []

    feed.entries.each do |entry|
      event_details = [] # Set up event container

      entry = entry.summary # Grab only the RSS entry contents
      entry.gsub!("\n", "") # Remove messy \n tags

      ntree = Nokogiri::HTML(entry) # Parse into nokogiri
      ntree.search('b').each do |b| # Remove <b> tags
        b.remove
      end

      nodes = ntree.search('div') # Separate each <div> into separate fields
      nodes.map do |node|
        clean = node.inner_html.strip
        clean = HTMLEntities.new.decode clean
        event_details << clean
      end

      location   = event_details[0]
      time       = event_details[1]
      speaker    = event_details[2]
      event_type = event_details[3]
      title      = event_details[4]

      time = DateTime.strptime("#{time}", '%m/%d/%Y %I:%M %p')

      # Map Array to hash
      # Push hash onto array
      events << {:location => location, :time => time, :speaker => speaker, :event_type => event_type, :title => title}
    end

    # Order descending date
    events = events.sort_by{ |hash| hash[:time] }.reverse
    return events
  end

  def home_event(event, type)
    max_length = 99999
    if type == "title"
      if event[:title].length > max_length
        event[:title].slice(0, max_length).insert(-1, "...")
      else
        event[:title]
      end
    elsif type == "speaker"
      if event[:speaker].length > max_length
        event[:speaker].slice(0, max_length).insert(-1, "...")
      else
        event[:speaker]
      end
    elsif type == "time"
      event[:time].strftime("%A, %b %d, %Y – %l:%M %p")
    end
  end
end


# Add bower's directory to sprockets asset path
after_configuration do
  @bower_config = JSON.parse(IO.read("#{root}/.bowerrc"))
  sprockets.append_path File.join "#{root}", @bower_config["directory"]
end

activate :deploy do |deploy|
  # ...
  deploy.build_before = true # default: false

  deploy.method   = :ftp
  deploy.host     = data.ftp.host
  deploy.path     = data.ftp.path
  deploy.user     = data.ftp.user
  deploy.password = data.ftp.pass
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
  set :http_prefix, data.ftp.path
end
