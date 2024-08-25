@[Crinja::Attributes]
struct Router
  include Crinja::Object::Auto
  property host, prot

  def initialize(@host : String, @prot : String)
  end
end
