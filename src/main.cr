require "http/client"
require "http/headers"
require "json"
require "yaml"
require "option_parser"
require "http/server"
require "crinja"

require "./router.cr"
require "./config.cr"

BASENAME = File.basename(PROGRAM_NAME)
debug = false
config_file = "config.yml"

# Get options
OptionParser.parse do |parser|
  parser.banner = "Usage: #{BASENAME} [-d|--debug] [-c|--config configfile.yml]"
  parser.on("-d", "--debug", "Turn on debug statements") { debug = true }
  parser.on("-c configfile", "--config configfile", "Choose config file") { |c| config_file = c }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit 1
  end
end

puts "Debug = #{debug}" if debug
puts "Config file = #{config_file}" if debug

# Read config
begin
  cf = Config.from_yaml(File.open(config_file))
rescue
  puts "Config file #{config_file} does not exist"
  exit 1
end

unless /^http[s]$/.match(cf.scheme)
  puts "Protocol scheme must be either http or https"
  exit 2
end

# Set to insecure if using self-signed cert
# Only implemented way for now

puts "Protocols = #{cf.protocols}" if debug

if debug
  puts "Scheme = #{cf.scheme}"
  puts "Endpoint = #{cf.endpoint}"
  if cf.host
    puts "Host = #{cf.host}"
  end
end

puts "Filters = #{cf.filters}" if debug

# Create url for traefik routers api access
url = "#{cf.scheme}://#{cf.endpoint}/api/http/routers"
puts "URL = #{url}" if debug

# Configure host headers if needed
headers = HTTP::Headers.new
unless cf.host.nil? || cf.host.size == 0
  headers.add("Host", cf.host)
end
pp headers if debug

# Configure tls insecure/don't verify
# for self-signed certs
# real certs are not supported yet

tls = nil
if cf.self_cert && cf.scheme == "https"
  tls = OpenSSL::SSL::Context::Client.insecure
end
pp tls if debug

# Get routers from traefik api
def get_routers(url, headers, tls)
  response = HTTP::Client.get(
    url,
    headers: headers,
    tls: tls
  )
  response

  res = JSON.parse(response.body)
  rules = res.as_a.map do |s|
    a = Router.new(s["rule"].as_s, s["using"][0].as_s)
    a
  end
  rules
end

# Massage router information
# Filter out unwanted routers
def get_list(rules, filters, debug = false)
  hosts = rules.map do |rule|
    if debug
      puts "********"
      puts "Rule = #{rule}"
    end
    filters.each do |filter|
      case filter
      when YAML::Any
        filter = filter.as_h
      end

      # Currently not used
      # if filter.has_key? "global"
      #  global = filter["global"]
      # else
      #  global = false
      # end

      if debug
        puts "========"
        puts "New filter"
      end
      if filter.op == "deleteline"
        puts "Deleteline" if debug
        regex = filter.regex
        puts "Regex = #{regex}" if debug
        puts "Rule = #{rule}" if debug
        match = /#{regex}/.match(rule.host)
        pp match if debug
        if /#{regex}/.match(rule.host)
          puts "deleted" if debug
          rule.host = ""
        end
      elsif filter.op == "select"
        puts "Select" if debug
        regex = filter.regex
        puts "Regex = #{regex}" if debug
        puts "Rule = #{rule}" if debug
        match = /#{regex}/.match(rule.host)
        pp match if debug
        if match
          rule.host = match.try &.[1]
        end
      end
    end
    puts "Rule2 = #{rule}" if debug
    rule
  end
  hosts
end

# Initialize crinja information
CRINJA = Crinja.new loader: Crinja::Loader::FileSystemLoader.new("templates")

# Main server
# Create server information
server = HTTP::Server.new([
  HTTP::ErrorHandler.new,
  HTTP::LogHandler.new,
  HTTP::CompressHandler.new,
  HTTP::StaticFileHandler.new("./assets", true, false),
]) do |context|
  # If request is "/", use traefik links
  # Otherwise, attempt to server html or css file
  # Serves nothing on other files
  if context.request.path == "/" && context.request.method == "GET"
    context.response.content_type = "text/html"
    rules = get_routers(url, headers, tls)
    hosts = get_list(rules, cf.filters, debug)
    hosts = hosts.select { |e| e.host.size > 0 }
    # Create template page
    vars = {
      "hosts"      => hosts,
      "protocols"  => cf.protocols,
      "new_window" => cf.new_window,
    }
    template = CRINJA.get_template("index.html.j2")
    output = template.render(vars)
    if cf.refresh
      context.response.headers["refresh"] = cf.refresh_interval
    end
    context.response.print output
  end
end

address = server.bind_tcp cf.bind_ip, cf.bind_port
server.listen
