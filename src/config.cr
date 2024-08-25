struct Filter
  include YAML::Serializable
  property op : String = ""
  property regex : String = ""
  property global : Bool = false
end

struct Config
  include YAML::Serializable
  property endpoint : String = ""
  property host : String = ""
  property self_cert : Bool = true
  property scheme : String = "https"
  property prefer : String = ""
  property refresh : Bool = false
  property refresh_interval : String = "300"
  property bind_port : Int32 = 8081
  property bind_ip : String = "127.0.0.1"
  property new_window : Bool = true
  property protocols : Hash(String, String) = {} of String => String
  property filters : Array(Filter) = [] of Filter
end
