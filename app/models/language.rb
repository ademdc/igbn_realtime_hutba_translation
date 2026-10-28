# Target languages a mosque can offer to listeners. Codes are ISO 639-1 and are
# passed to Soniox as translation targets as-is.
class Language
  CATALOG = {
    "de" => { name: "Deutsch",    flag: "🇩🇪", name_bs: "Njemački", poster: "Die Hutba live auf Deutsch mitlesen" },
    "en" => { name: "English",    flag: "🇬🇧", name_bs: "Engleski", poster: "Read the khutbah live in English" },
    "fr" => { name: "Français",   flag: "🇫🇷", name_bs: "Francuski", poster: "Lire la khutba en direct en français" },
    "nl" => { name: "Nederlands", flag: "🇳🇱", name_bs: "Holandski", poster: "Lees de khutba live mee in het Nederlands" },
    "it" => { name: "Italiano",   flag: "🇮🇹", name_bs: "Italijanski", poster: "Leggi la khutba in diretta in italiano" },
    "es" => { name: "Español",    flag: "🇪🇸", name_bs: "Španski", poster: "Lee la jutba en directo en español" },
    "sv" => { name: "Svenska",    flag: "🇸🇪", name_bs: "Švedski", poster: "Läs khutban live på svenska" },
    "tr" => { name: "Türkçe",     flag: "🇹🇷", name_bs: "Turski", poster: "Hutbeyi canlı olarak Türkçe okuyun" },
    "ar" => { name: "العربية",    flag: "🇸🇦", name_bs: "Arapski", poster: "اقرأ الخطبة مباشرة بالعربية" },
    "sq" => { name: "Shqip",      flag: "🇦🇱", name_bs: "Albanski", poster: "Lexo hutben drejtpërdrejt në shqip" }
  }.freeze

  CODES = CATALOG.keys.freeze
  RTL = %w[ar].freeze

  # Old single-tenant routes used full names (/german).
  LEGACY_NAMES = { "german" => "de", "deutsch" => "de", "english" => "en" }.freeze

  def self.supported?(code)
    CATALOG.key?(code)
  end

  def self.info(code)
    CATALOG[code]
  end
end
