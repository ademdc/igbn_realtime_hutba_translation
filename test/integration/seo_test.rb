require "test_helper"

class SeoTest < ActionDispatch::IntegrationTest
  test "marketing robots.txt points to the sitemap" do
    host! "localhost"
    get "/robots.txt"
    assert_response :success
    assert_includes response.body, "Sitemap: http://localhost/sitemap.xml"
  end

  test "sitemap lists every page in every language" do
    host! "localhost"
    get "/sitemap.xml"
    assert_response :success
    assert_equal SeoController::PAGES.size * MarketingController::LOCALES.size, response.body.scan("<loc>").size
    assert_includes response.body, "<loc>http://localhost/de</loc>"
  end

  test "landing page has share tags, canonical link and structured data" do
    host! "localhost"
    get "/de"
    assert_select "link[rel=canonical][href=?]", "http://localhost/de"
    assert_select "link[rel=alternate][hreflang=x-default][href=?]", "http://localhost/de"
    assert_select "meta[property='og:image'][content=?]", "http://localhost/og-image.png"
    assert_select "meta[name=keywords]"
    assert_select "script[type='application/ld+json']"
    assert_nil response.headers["X-Robots-Tag"]
  end

  test "mosque pages are kept out of search" do
    host! "#{accounts(:igbd).subdomain}.localhost"
    get "/robots.txt"
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    assert_not_includes response.body, "Sitemap"
  end
end
