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

### Get options
OptionParser.parse do |parser|
  parser.banner = "Usage: #{BASENAME} [-d|--debug] [-c|--config configfile.yml]"
  parser.on("-d","--debug","Turn on debug statements") { debug = true }
  parser.on("-c configfile","--config configfile","Choose config file") { |c| config_file = c }
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

### Read config
config = File.open(config_file) do |file|
  YAML.parse(file)
end
config = config.as_h
cf = Config.new

# Configure scheme used for accessing traefik endpoint
unless config.has_key? "scheme"
  puts "Must have a protocol scheme, either http or https"
  exit 2
end

if /^http[s]$/.match(config["scheme"].as_s)
  cf.scheme = config["scheme"].as_s
else
  puts "Protocol scheme must be either http or https"
  exit 2
end

# Configure endpoint
begin
  cf.endpoint = config["endpoint"].as_s
rescue
  puts "Configuration does not have an endpoint"
  exit 2
end

if config.has_key? "host"
  cf.host = config["host"].as_s
end

# Set to insecure if using self-signed cert
# Only implemented way for now
if config.has_key? "self_cert"
  cf.self_cert = config["self_cert"].as_bool
end

# Create protocols hash
if config.has_key? "protocols"
  protocols = config["protocols"].as_h
else
  puts "Configuration does not have a protocols entry"
  exit 2
end
puts "Protocols = #{protocols}" if debug

if debug
  puts "Scheme = #{cf.scheme}"
  puts "Endpoint = #{cf.endpoint}"
  if cf.host
    puts "Host = #{cf.host}"
  end
end

if config.has_key? "refresh"
  if config["refresh"]
    cf.refresh = true
    if config.has_key? "refresh_interval"
      cf.refresh_interval = config["refresh_interval"].as_i
    end
  end
end

# Create filters array
if config.has_key? "filters"
  filters = config["filters"].as_a
else
  filters = [] of Hash(String,String)
end

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

# Bind port, default 8081
if config.has_key? "bind_port"
  cf.bind_port = config["bind_port"].as_i
end

# Bind host, default localhost/127.0.0.1
if config.has_key? "bind_ip"
  cf.bind_ip = config["bind_ip"].as_s
end

if config.has_key? "new_window"
  cf.new_window = config["new_window"].as_bool
end

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
def get_list(rules,filters,debug = false)
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

      ## Currently not used
      #if filter.has_key? "global"
      #  global = filter["global"]
      #else
      #  global = false
      #end

      if debug
        puts "========"
        puts "New filter"
      end
      if filter["op"] == "deleteline"
        puts "Deleteline" if debug
        regex = filter["regex"]
        puts "Regex = #{regex}" if debug
        puts "Rule = #{rule}" if debug
        match = /#{regex}/.match(rule.host)
        pp match if debug
        if /#{regex}/.match(rule.host)
          puts "deleted" if debug
          rule.host = ""
        end
      elsif filter["op"] == "select"
        puts "Select" if debug
        regex = filter["regex"]
        puts "Regex = #{regex}" if debug
        puts "Rule = #{rule}" if debug
        match = /#{regex}/.match(rule.host)
        pp match if debug
        if match
          rule.host = match.try &.[1]
        end
      end

      if debug
        if filter.has_key? "global"
          pp typeof(filter["global"])
        end
      end
    end
    puts "Rule2 = #{rule}" if debug
    rule
  end
  hosts
end

# Initialize crinja information
CRINJA = Crinja.new
CRINJA.loader = Crinja::Loader::FileSystemLoader.new("templates")

# Main server
# Create server information
server = HTTP::Server.new do |context|
  # If request is "/", use traefik links
  # Otherwise, attempt to server html or css file
  # Serves nothing on other files
  if context.request.path != "/"
    filepath = "./assets/#{context.request.path}"
    if filepath[-3..] == "css"
      context.response.content_type = "text/css"
    else
      context.response.content_type = "text/html"
    end
    begin
      File.open(filepath) do |file|
        IO.copy(file, context.response)
      end
    rescue
      puts "File not found #{filepath}" if debug
    end
    next
  end

  rules = get_routers(url, headers, tls)
  hosts = get_list(rules, filters, debug)
  hosts = hosts.select { |e| e.host.size > 0 }

  pp hosts if debug

  # Create template page
  vars = {
    "hosts" => hosts,
    "protocols" => protocols,
    "new_window" => cf.new_window
  }
  template = CRINJA.get_template("index.html.j2")
  output = template.render(vars)
  context.response.content_type = "text/html"

  if cf.refresh
    context.response.headers["refresh"] = cf.refresh_interval.to_s
  end
  context.response.print output
end

address = server.bind_tcp cf.bind_ip,cf.bind_port
puts "Listening on http://#{address}"
server.listen
