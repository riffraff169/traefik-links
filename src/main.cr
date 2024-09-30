require "http/client"
require "http/headers"
require "json"
require "yaml"
require "option_parser"
require "http/server"
require "crinja"

require "./router.cr"
require "./config.cr"
require "./entrypoints.cr"

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
# for self-signed certs (or where cert doesn't match hostname)
# real certs are not supported yet

tls = nil
if !cf.verify_cert && cf.scheme == "https"
  tls = OpenSSL::SSL::Context::Client.insecure
end
pp tls if debug

# Get routers from traefik api
def get_routers(cf, url, headers, tls)
  uri = URI.parse(url)
  client = HTTP::Client.new(uri, tls: tls)
  # Only supported method right now
  if cf.auth && cf.auth_type == "basic"
    client.basic_auth(cf.auth_user, cf.auth_pass)
  end
  response = client.get("/api/http/routers", headers: headers)
  client.close

  if response.status_code == 401
    STDERR.puts "Unauthorized"
    exit 3
  end

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

ep = get_entrypoints(cf, url, headers, tls)
entrypoints = ep.each_with_object({} of String => Entrypoint) do |s, r|
  r[s.name] = s
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
  # Serves files in ./assets
  # If not there, serves the template file from the config
  # Only supports the one config as this is not a full fledge web server
  if context.request.path == "/" && context.request.method == "GET"
    context.response.content_type = "text/html"
    rules = get_routers(cf, url, headers, tls)
    hosts = get_list(rules, cf.filters, debug)
    hosts = hosts.select { |e| e.host.size > 0 }
    # Create template page
    vars = {
      "hosts"      => hosts,
      "protocols"  => entrypoints,
      "new_window" => cf.new_window,
    }
    template = CRINJA.get_template(cf.template)
    output = template.render(vars)
    if cf.refresh
      context.response.headers["refresh"] = cf.refresh_interval
    end
    context.response.print output
  end
end

address = server.bind_tcp cf.bind_ip, cf.bind_port
server.listen
