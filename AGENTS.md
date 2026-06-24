# Kalamazoo

A Rails application template. Running it scaffolds a Rails 8 app with the house
default stack: Vite + Tailwind 4 + daisyui (pnpm), Hotwire, reactionview,
standard, herb, annotaterb, and mise.

## How it works

- `template.rb` orchestrates. It adds gems, then in `after_bundle` installs Vite,
  switches from npm/`app/frontend` to pnpm/`app/javascript`, copies the companion
  files, patches `package.json`, extends the default CI, wires the layout, and
  runs a final lint/format pass.
- Companion files live at their destination paths (`mise.toml`,
  `config/vite.json`, `app/javascript/...`, etc.) and are pulled in with
  `copy_file`. Dynamic bits (`.node-version`, `package.json` scripts, CI Node
  steps) are generated in `template.rb`.
- When run from a URL, `add_template_repository_to_source_path` clones this repo
  to a tempdir so the companion files resolve.

## Editing

- Change behavior in `template.rb`.
- Change generated file contents in the matching companion file.
- Keep both in sync. This repo is the source of truth for the default stack;
  the personal `~/.rails-template.rb` mirrors it.

## Testing a change

Run the template against a throwaway app using the local path (skips the clone):

```
rails new /tmp/kz-test -d sqlite3 --skip-js --skip-rubocop --skip-system-test \
  -m ~/Source/kalamazoo/template.rb
```

Then in the generated app verify it is green:

```
bundle exec standardrb
pnpm lint
bundle exec herb analyze app/views --no-timing
bin/vite build            # confirm daisyui compiles into the CSS
RAILS_ENV=test bin/rails db:test:prepare test
```
