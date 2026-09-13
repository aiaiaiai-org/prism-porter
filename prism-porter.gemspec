# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

require_relative "lib/prism_porter/version"

Gem::Specification.new do |spec|
  spec.name = "aiaiaiai-prism-porter"
  spec.version = PrismPorter::VERSION
  spec.authors = ["aiaiaiai"]
  spec.summary = "Provider-neutral Prism artifact routing and presentation"
  spec.homepage = "https://aiaiaiai.org"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 4.0.0"
  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "NOTICE", "docs/**/*.md"]
  spec.require_paths = ["lib"]
  spec.metadata = {
    "source_code_uri" => "https://github.com/aiaiaiai-org/prism-porter",
    "homepage_uri" => "https://aiaiaiai.org"
  }
end
