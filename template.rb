# Kalamazoo -- a minimal Rails application template.
#
# Inspired by https://github.com/mattbrictson/rails-template
#
# Produces a Rails 8 app wired with Vite + Tailwind 4 + daisyui (pnpm),
# Hotwire, reactionview, standard, herb, annotaterb, and mise.
#
# Usage:
#   rails new my-app -d sqlite3 --skip-js --skip-rubocop --skip-system-test \
#     -m https://raw.githubusercontent.com/hschne/kalamazoo/main/template.rb

require "bundler"
require "json"

RAILS_REQUIREMENT = ">= 8.0".freeze

def apply_template!
  assert_minimum_rails_version
  add_template_repository_to_source_path

  add_dependencies

  after_bundle do
    setup_vite
    setup_annotaterb
    setup_reactionview
    setup_frontend
    setup_tooling
    setup_mise
    setup_ci
    update_layout
    finalize
  end
end

def add_dependencies
  gem "vite_rails"

  # Better ERB
  gem "reactionview"

  gem_group :development, :test do
    gem "amazing_print"
  end

  gem_group :development do
    gem "annotaterb"
    gem "herb"
    gem "standard"
    gem "standard-rails"
    gem "rubocop-minitest"
    gem "rubocop-performance"
  end
end

# Install Vite (creates config/vite.json, package.json, layout tags, binstubs).
def setup_vite
  run "bundle exec vite install"
end

# Correct annotaterb install generator (creates lib/tasks + .annotaterb.yml).
def setup_annotaterb
  generate "annotate_rb:install"
end

def setup_reactionview
  copy_file "config/initializers/reactionview.rb"
end

# Move from npm/app/frontend to pnpm/app/javascript and wire Tailwind + daisyui.
def setup_frontend
  run "rm -rf app/frontend node_modules package-lock.json"

  copy_file "config/vite.json", force: true
  copy_file "vite.config.ts", force: true
  copy_file "app/assets/stylesheets/application.css", force: true
  copy_file "app/javascript/entrypoints/application.js"
  copy_file "app/javascript/entrypoints/application.css"
  copy_file "app/javascript/controllers/index.js"
  copy_file "app/javascript/controllers/application.js"

  js_packages = %w[
    @eslint/js
    @herb-tools/formatter
    @hotwired/stimulus
    @hotwired/turbo-rails
    @tailwindcss/forms
    @tailwindcss/typography
    @tailwindcss/vite
    browserslist
    daisyui
    eslint
    eslint-plugin-compat
    globals
    prettier
    prettier-plugin-tailwindcss
    stimulus-vite-helpers
    stylelint
    stylelint-config-html
    stylelint-config-standard
    stylelint-no-unsupported-browser-features
    tailwindcss
  ]
  run "pnpm add -D #{js_packages.join(" ")}"

  patch_package_json
end

# Pin pnpm and add lint/format scripts + browserslist to the generated package.json.
def patch_package_json
  pnpm_version = `pnpm -v`.strip
  pkg = JSON.parse(File.read("package.json"))
  pkg["type"] = "module"
  pkg["packageManager"] = "pnpm@#{pnpm_version}"
  pkg["scripts"] = {
    "lint" => "pnpm lint:js && pnpm lint:css && pnpm format:js:check",
    "lint:js" => "eslint app/javascript",
    "lint:css" => "stylelint 'app/assets/stylesheets/**/*.css' 'app/javascript/entrypoints/**/*.css'",
    "format" => "pnpm format:js && pnpm format:css",
    "format:js" => "prettier --write 'app/javascript/**/*.js'",
    "format:js:check" => "prettier --check 'app/javascript/**/*.js'",
    "format:css" => "stylelint --fix 'app/assets/stylesheets/**/*.css' 'app/javascript/entrypoints/**/*.css'"
  }
  pkg["browserslist"] = ["baseline widely available"]
  File.write("package.json", JSON.pretty_generate(pkg) + "\n")
end

def setup_tooling
  copy_file "eslint.config.js"
  copy_file "stylelint.config.js"
  copy_file ".prettierrc"
  copy_file ".herb.yml"
  copy_file ".standard.yml", force: true
end

def setup_mise
  copy_file "mise.toml"
  node_version = `node -v`.strip.sub(/\Av/, "")
  create_file ".node-version", "#{node_version}\n"
end

# Keep Rails' default CI flow, but add Node + pnpm to the test job so Vite
# assets build for view-rendering tests (driven by .node-version).
def setup_ci
  ci = ".github/workflows/ci.yml"
  return unless File.exist?(ci)

  steps = <<~YAML
    - name: Install pnpm
      uses: pnpm/action-setup@v6

    - name: Set up Node
      uses: actions/setup-node@v6
      with:
        node-version-file: .node-version
        cache: pnpm

    - name: Install JavaScript dependencies
      run: pnpm install
  YAML

  # Indent to match the steps list (6 spaces), then keep the existing tests step.
  indented = steps.each_line.map { |line| line.strip.empty? ? "\n" : "      #{line}" }.join
  gsub_file ci, "      - name: Run tests\n", "#{indented}\n      - name: Run tests\n"
end

# Use the Vite entrypoints and drop the Propshaft app stylesheet.
def update_layout
  layout = "app/views/layouts/application.html.erb"
  gsub_file layout, /<%= vite_javascript_tag ['"]application['"] %>/,
    %(<%= vite_javascript_tag "entrypoints/application.js" %>\n    <%= vite_stylesheet_tag "entrypoints/application.css", "data-turbo-track": "reload" %>)
  gsub_file layout, /^[ \t]*<%#[^\n]*app\/assets\/stylesheets[^\n]*%>\n/, ""
  gsub_file layout, /^[ \t]*<%= stylesheet_link_tag :app[^%]*%>\n/, ""
end

def finalize
  run "pnpm install"
  run "pnpm format"
  gsub_file "config/environments/production.rb", /TaggedLogging\.logger\(STDOUT\)/, "TaggedLogging.logger($stdout)"
  gsub_file "config/environments/production.rb", /Logger\.new\(STDOUT\)/, "Logger.new($stdout)"
  run "bundle exec standardrb --fix"

  # Create the database and dump schema.rb so the default CI test job passes.
  rails_command "db:migrate"
end

# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__.match?(%r{\Ahttps?://})
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("kalamazoo-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/hschne/kalamazoo.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{kalamazoo/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. " \
           "You are using #{rails_version}. Continue anyway?"
  exit 1 if no?(prompt)
end

apply_template!
