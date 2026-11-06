# Blog articles

Each article is a folder here, with one Markdown file per language:

    content/blog/2026-11-hutba-live-uebersetzen/
      de.md  en.md  bs.md  fr.md  nl.md  tr.md

Every file starts with front matter:

    ---
    title: "Shown as the headline and in Google (keep it under ~65 characters if you can)"
    description: "One or two sentences for Google and link previews (~150 characters)"
    slug: url-of-this-article-in-this-language
    date: 2026-11-06
    ---

Then the article in Markdown: `## Heading`, `- list`, `1. steps`, `**bold**`, `[link](https://…)`.

- Files in the same folder are linked as translations of each other (language switcher, hreflang).
  A language can be left out; it then just doesn't show in that language's blog.
- Articles appear on /<locale>/blog and in /sitemap.xml automatically.
- Publish by committing and deploying. `bin/rails test test/integration/blog_test.rb` checks every file renders.
