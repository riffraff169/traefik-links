require "http/client"
require "json"
require "yaml"
require "option_parser"

debug = false
config_file = "config.yml"

OptionParser.parse do |parser|
  parser.banner = "Usage: traefik-links [-d|--debug] [-c|--config configfile.yml]"
  parser.on("-d","--debug","Turn on debug statements") { debug = true }
  parser.on("-c configfile","--config configfile","Choose config file") { |c| config_file = c }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

puts "Debug = #{debug}" if debug
puts "Config file = #{config_file}" if debug

config = File.open(config_file) do |file|
  YAML.parse(file)
end
config = config.as_h

if config.has_key? "https"
  if config["https"].as_bool
    scheme = "https"
  else
    scheme = "http"
  end
end

begin
  endpoint = config["endpoint"].as_s
rescue
  puts "Configuration does not have an endpoint"
  exit 1
end

if config.has_key? "host"
  host = config["host"].as_s
end

if config.has_key? "self_cert"
  self_cert = config["self_cert"].as_bool
end

puts "Scheme = #{scheme}"
puts "Endpoint = #{endpoint}"
if host
  puts "Host = #{host}"
end

if config.has_key? "filters"
  filters = config["filters"].as_a
else
  filters = [] of Hash(String,String)
end

url = "#{scheme}://#{endpoint}/api/http/routers"
pp url

headers = nil
unless host.nil?
  headers = HTTP::Headers{ "Host" => host }
else
  headers = nil
end
pp headers

tls = nil
unless self_cert.nil?
  if self_cert && scheme == "https"
    tls = OpenSSL::SSL::Context::Client.insecure
  end
end
pp tls

response = HTTP::Client.get(
  #"https://hobbes/api/http/routers",
  url,
  #headers: HTTP::Headers{"Host" => "traefik.riffraff169.org"},
  headers: headers,
  tls: tls
)

res = JSON.parse(response.body)
rules = res.as_a.map { |s| s["rule"].as_s }

#res = /Host\(`([^`]+)`\)/.match(rules[0])

#pp res

hosts = rules.map do |rule|
  puts "********"
  puts "Rule = #{rule}"
  filters.each do |filter|
    case filter
    when YAML::Any
      filter = filter.as_h
    end

    #pp filter
    #pp typeof(filter["op"])
    #pp typeof(filter["regex"])

    if filter.has_key? "global"
      global = filter["global"]
    else
      global = false
    end

    #pp global
    puts "========"
    puts "New filter"
    if filter["op"] == "deleteline"
      puts "Deleteline"
      regex = filter["regex"]
      puts "Regex = #{regex}"
      puts "Rule = #{rule}"
      match = /#{regex}/.match(rule)
      pp match
      if /#{regex}/.match(rule)
        puts "deleted"
        rule = ""
      end
    elsif filter["op"] == "select"
      puts "Select"
      regex = filter["regex"]
      puts "Regex = #{regex}"
      puts "Rule = #{rule}"
      match = /#{regex}/.match(rule)
      pp match
      if match
        rule = match.try &.[1]
      end
    end

    if filter.has_key? "global"
      pp typeof(filter["global"])
    end
  end
  puts "Rule2 = #{rule}"
  rule
end

hosts = hosts.select { |e| e.size > 0 }

pp hosts
    #pp filter
#
#    op = case filter["op"]
#         when String
#           filter["op"]
#         else
#           filter["op"].as_s
#         end
#    regex = filter["regex"]
#    pp op
#    pp regex
#    if filter.has_key? "global"
#      global = filter["global"]
#    else
#      global = false
#    end
#    case filter["op"]
#    when "deleteline"
#      case rule
#      when String
#        if /#{filter["regex"]}/.match(rule)
#          rule = ""
#        end
#      when Nil
#        next
#      else
#        if /#{filter["regex"]}/.match(rule.as_s)
#          rule = ""
#        end
#      end
#    when "select"
#      case rule
#      when String
#        rule = /#{filter["regex"]}/.match(rule).try &.[1]
#      when Nil
#        next
#      else
#        rule = /#{filter["regex"]}/.match(rule.as_s).try &.[1]
#      end
#    end
#    #pp filter["op"]
#    #pp typeof(filter)
#    #pp typeof(filter["op"])
#  end
#  pp rule
#  rule
#end
#
