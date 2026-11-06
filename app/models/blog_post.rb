# Blog articles live in content/blog/<article>/<locale>.md: YAML front matter
# (title, description, slug, date) followed by Markdown. Every file in one folder
# is a translation of the same article.
class BlogPost
  ROOT = Rails.root.join("content/blog")

  attr_reader :key, :locale, :slug, :title, :description, :date, :markdown

  def initialize(key:, locale:, slug:, title:, description:, date:, markdown:)
    @key, @locale, @slug, @title, @description, @date, @markdown = key, locale, slug, title, description, date, markdown
  end

  def self.all
    return load_all if Rails.env.development?
    @all ||= load_all
  end

  # Newest first
  def self.for_locale(locale)
    all.select { |post| post.locale == locale.to_s }.sort_by(&:date).reverse
  end

  def self.find(locale, slug)
    all.find { |post| post.locale == locale.to_s && post.slug == slug }
  end

  def self.load_all
    Dir[ROOT.join("*/*.md")].sort.map { |path| from_file(path) }
  end

  def self.from_file(path)
    front_matter, markdown = File.read(path).match(/\A---\n(.*?)\n---\n(.*)\z/m)&.captures ||
      raise(ArgumentError, "#{path} has no front matter")
    meta = YAML.safe_load(front_matter, permitted_classes: [Date])
    new(
      key: File.basename(File.dirname(path)),
      locale: File.basename(path, ".md"),
      slug: meta.fetch("slug"),
      title: meta.fetch("title"),
      description: meta.fetch("description"),
      date: meta.fetch("date"),
      markdown: markdown
    )
  end

  def html
    @html ||= Kramdown::Document.new(markdown, auto_ids: true).to_html.html_safe
  end

  # The same article in every language it is written in, keyed by locale
  def translations
    self.class.all.select { |post| post.key == key }.index_by(&:locale)
  end
end
