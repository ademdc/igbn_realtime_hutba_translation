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

  # Listener page text, in the listener's own language
  LISTENER_UI = {
    "de" => { connecting: "Verbinde …", connected: "Verbunden", disconnected: "Verbindung unterbrochen", waiting: "Warten auf die Hutba …", change: "Sprache wechseln" },
    "en" => { connecting: "Connecting…", connected: "Connected", disconnected: "Connection lost", waiting: "Waiting for the khutbah…", change: "Change language" },
    "fr" => { connecting: "Connexion…", connected: "Connecté", disconnected: "Connexion perdue", waiting: "En attente de la khutba…", change: "Changer de langue" },
    "nl" => { connecting: "Verbinden…", connected: "Verbonden", disconnected: "Verbinding verbroken", waiting: "Wachten op de khutba…", change: "Andere taal" },
    "it" => { connecting: "Connessione…", connected: "Connesso", disconnected: "Connessione persa", waiting: "In attesa della khutba…", change: "Cambia lingua" },
    "es" => { connecting: "Conectando…", connected: "Conectado", disconnected: "Conexión perdida", waiting: "Esperando la jutba…", change: "Cambiar idioma" },
    "sv" => { connecting: "Ansluter…", connected: "Ansluten", disconnected: "Anslutningen bröts", waiting: "Väntar på khutban…", change: "Byt språk" },
    "tr" => { connecting: "Bağlanıyor…", connected: "Bağlandı", disconnected: "Bağlantı kesildi", waiting: "Hutbe bekleniyor…", change: "Dili değiştir" },
    "ar" => { connecting: "جارٍ الاتصال…", connected: "متصل", disconnected: "انقطع الاتصال", waiting: "في انتظار الخطبة…", change: "تغيير اللغة" },
    "sq" => { connecting: "Duke u lidhur…", connected: "I lidhur", disconnected: "Lidhja u ndërpre", waiting: "Në pritje të hutbes…", change: "Ndrysho gjuhën" }
  }.freeze

  # Languages the imam can speak, with the Soniox recognition hints for each.
  # Bosnian, Croatian and Serbian are recognised together.
  SOURCES = {
    "bs" => { name: "Bosanski / Hrvatski / Srpski", hints: %w[bs hr sr] },
    "sq" => { name: "Shqip", hints: %w[sq] },
    "tr" => { name: "Türkçe", hints: %w[tr] },
    "ar" => { name: "العربية", hints: %w[ar] },
    "de" => { name: "Deutsch", hints: %w[de] },
    "en" => { name: "English", hints: %w[en] },
    "fr" => { name: "Français", hints: %w[fr] },
    "nl" => { name: "Nederlands", hints: %w[nl] }
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

  def self.source_hints(code)
    SOURCES.fetch(code, SOURCES["bs"])[:hints]
  end

  # The listener language is the one spoken: show the transcript, don't translate
  def self.same_as_source?(listener_code, source_code)
    source_hints(source_code).include?(listener_code)
  end

  def self.listener_ui(code)
    LISTENER_UI.fetch(code, LISTENER_UI["en"])
  end

  def self.direction(code)
    RTL.include?(code) ? "rtl" : "ltr"
  end
end
