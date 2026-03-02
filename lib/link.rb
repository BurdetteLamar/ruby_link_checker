class Link

  attr_accessor :page_path, :lineno, :href, :text, :dirname, :status

  def initialize(page_path, lineno, href, text)
    self.page_path = page_path
    self.lineno = lineno
    self.href = href
    self.text = text.nil? ? '' : text.strip
    dirname = File.dirname(page_path)
    while href.start_with?('../') do
      href.sub!('../', '')
      dirname = File.dirname(dirname)
    end
    self.dirname = dirname
    self.status = :unknown
  end

  def conditioned_path

  end

  def to_json(*args)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ page_path, lineno, href, text ]
    }.to_json(*args)
  end

  def self.json_create(object)
    # p object
    new(*object['a'])

  end
end
