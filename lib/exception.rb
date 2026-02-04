class RubyLinkCheckerException < Exception

  attr_accessor :message, :argname, :argvalue, :exception

  def initialize(message, argname, argvalue, exception)
    super(message)
    self.message = message
    self.argname = argname
    self.argvalue = argvalue
    self.exception = exception
  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ message, argname, argvalue, exception ],
    }.to_json(*args)
  end

  def self.json_create(object)
    new(*object['a'])
  end

end

class URIParseException < RubyLinkCheckerException; end

class HTTPResponseException < RubyLinkCheckerException; end

class AnchorParseException < RubyLinkCheckerException; end

