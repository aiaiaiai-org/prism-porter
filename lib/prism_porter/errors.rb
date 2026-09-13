# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  class Error < StandardError; end
  class InvalidInput < Error; end
  class InvalidArtifact < Error; end
  class RouteNotFound < Error; end
  class RendererNotFound < Error; end
end
