# Target languages a mosque can offer to listeners. Codes are ISO 639-1 and are
# passed to Soniox as translation targets as-is.
class Language
  CATALOG = {
    "de" => { name: "Deutsch",    flag: "🇩🇪", name_bs: "Njemački" },
    "en" => { name: "English",    flag: "🇬🇧", name_bs: "Engleski" },
    "fr" => { name: "Français",   flag: "🇫🇷", name_bs: "Francuski" },
    "nl" => { name: "Nederlands", flag: "🇳🇱", name_bs: "Holandski" },
    "it" => { name: "Italiano",   flag: "🇮🇹", name_bs: "Italijanski" },
    "es" => { name: "Español",    flag: "🇪🇸", name_bs: "Španski" },
    "sv" => { name: "Svenska",    flag: "🇸🇪", name_bs: "Švedski" },
    "tr" => { name: "Türkçe",     flag: "🇹🇷", name_bs: "Turski" },
    "ar" => { name: "العربية",    flag: "🇸🇦", name_bs: "Arapski" },
    "sq" => { name: "Shqip",      flag: "🇦🇱", name_bs: "Albanski" }
  }.freeze

  CODES = CATALOG.keys.freeze

  # Old single-tenant routes used full names (/german).
  LEGACY_NAMES = { "german" => "de", "deutsch" => "de", "english" => "en" }.freeze

  def self.supported?(code)
    CATALOG.key?(code)
  end

  def self.info(code)
    CATALOG[code]
  end
end
