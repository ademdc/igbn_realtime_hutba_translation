require "test_helper"

class BlogTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "every blog file has front matter and renders" do
    BlogPost.all.each do |post|
      get "/#{post.locale}/blog/#{post.slug}"
      assert_response :success
      assert_select "h1", post.title
      assert_select "script[type='application/ld+json']", /BlogPosting/
    end
  end

  test "index lists the articles in the visitor's language" do
    get "/de/blog"
    assert_response :success
    BlogPost.for_locale("de").each { |post| assert_select "a[href=?]", "/de/blog/#{post.slug}" }
  end

  test "language links point to the translated article" do
    post = BlogPost.for_locale("de").first
    get "/de/blog/#{post.slug}"
    english = post.translations["en"]
    assert_select "link[rel=alternate][hreflang=en][href=?]", "http://localhost/en/blog/#{english.slug}"
    assert_select ".locale-switch a[href=?]", "/en/blog/#{english.slug}"
  end

  test "unknown article is a 404" do
    get "/de/blog/does-not-exist"
    assert_response :not_found
  end

  test "articles are in the sitemap" do
    get "/sitemap.xml"
    BlogPost.all.each { |post| assert_includes response.body, "/#{post.locale}/blog/#{post.slug}</loc>" }
  end
end
