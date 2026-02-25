class RubyLinkCheckerException < Exception

  attr_accessor :description, :argname, :argvalue, :class_name, :message

  def initialize(description, argname, argvalue, class_name, message)
    super(message)
    self.description = description
    self.argname = argname
    self.argvalue = argvalue
    self.class_name = class_name
    self.message = message
  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ description, argname, argvalue, class_name, message ],
    }.to_json(*args)
  end

  def self.json_create(object)
    new(*object['a'])
  end

end

class URIParseException < RubyLinkCheckerException; end

class HTTPResponseException < RubyLinkCheckerException; end

class AnchorParseException < RubyLinkCheckerException; end

