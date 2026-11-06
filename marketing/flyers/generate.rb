# Builds the A4 promo flyers: one PDF per language in copy.yml.
#   bundle exec ruby marketing/flyers/generate.rb
require "erb"
require "yaml"
require "cgi"
require "rqrcode"

DIR = __dir__
FONTS = "file://" + File.expand_path("../../app/assets/fonts", DIR)
def h(text) = CGI.escapeHTML(text.to_s)

CHROME = ENV.fetch("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
GERMAN = "Liebe Brüder und Schwestern, Allah ruft uns im Koran zur Barmherzigkeit gegenüber unseren Eltern auf."

template = ERB.new(File.read(File.join(DIR, "template.html.erb")))
out = File.join(DIR, "out")
Dir.mkdir(out) unless Dir.exist?(out)

YAML.load_file(File.join(DIR, "copy.yml")).each do |lang, c|
  qr = RQRCode::QRCode.new(c["url"]).as_svg(use_path: true, viewbox: true, color: "12302d", module_size: 4, standalone: true)
  html = template.result_with_hash(lang: lang, c: c, fonts: FONTS, german: GERMAN, qr: qr)
  html_path = File.join(out, "hutba-flyer-#{lang}.html")
  File.write(html_path, html)
  pdf_path = File.join(out, "hutba-flyer-#{lang}.pdf")
  system(CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--allow-file-access-from-files",
         "--virtual-time-budget=3000", "--print-to-pdf=#{pdf_path}", "file://#{html_path}", exception: true,
         out: File::NULL, err: File::NULL)
  puts pdf_path
end
