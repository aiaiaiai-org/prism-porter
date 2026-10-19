# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismPorter
  module Rendering
    # Ephemeral transactional mail, deliberately outside DeliveryIntent/CLI:
    # those durable, serializable channels are unsuitable for one-time secrets.
    class IdentityEmailRenderer
      SCHEMA = "identity.email-challenge.v1".freeze
      INTENTS = %w[verify_email sign_in link_email recover].freeze
      LOCALES = %w[uk en].freeze
      FROM_PATTERN = /\A[a-z0-9][a-z0-9._+-]*@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+\z/i
      SAFE_CLIENT_ID = /\A[a-z0-9]+(?:[-.][a-z0-9]+)*\z/
      CODE_PATTERN = /\A[0-9]{6,8}\z/

      COPY = {
        "uk" => {
          "verify_email" => ["Підтвердження електронної адреси", "Підтвердіть електронну адресу цим кодом:"],
          "sign_in" => ["Код для входу", "Скористайтеся цим кодом, щоб увійти:"],
          "link_email" => [
            "Прив'язування електронної адреси",
            "Скористайтеся цим кодом, щоб підтвердити прив'язування адреси:"
          ],
          "recover" => ["Відновлення доступу", "Використайте цей код, щоб продовжити відновлення доступу:"]
        },
        "en" => {
          "verify_email" => ["Verify your email address", "Use this code to verify your email address:"],
          "sign_in" => ["Your sign-in code", "Use this code to sign in:"],
          "link_email" => ["Link your email address", "Use this code to confirm linking your email address:"],
          "recover" => ["Account recovery", "Use this code to continue account recovery:"]
        }
      }.freeze
      FOOTER = {
        "uk" => "Якщо ви не запитували цей код, просто проігноруйте лист.",
        "en" => "If you did not request this code, you can ignore this email."
      }.freeze

      # Sender domains must be separately authorized by Identity's transport.
      # The user-provided artifact cannot select a From header.
      def initialize(clients:)
        unless clients.is_a?(Hash) && !clients.empty?
          raise InvalidInput, "email client configuration must be a nonempty hash"
        end

        @clients = clients.each_with_object({}) do |(id, settings), known|
          known[validated_client_id(id)] = validated_client_settings(settings)
        end.freeze
      end

      # Identity alone issues, expires, and validates the challenge code.
      # Immediately hand this result to a transactional transport adapter.
      # Never use ArtifactEnvelope/DeliveryIntent for one-time secrets.
      def render(schema_version:, client_id:, intent:, locale:, code:)
        validate_request!(schema_version:, client_id:, intent:, locale:, code:)

        client = @clients.fetch(client_id) { raise InvalidArtifact, "unknown identity mail client" }
        title, instruction = COPY.fetch(locale).fetch(intent)
        brand = client.fetch(:brand)
        body = "#{brand}\n\n#{instruction}\n\n#{code}\n\n#{FOOTER.fetch(locale)}"
        Message.new(from: client.fetch(:from), subject: "#{brand} — #{title}", body: body)
      end

      class Message
        attr_reader :from, :subject, :body

        def initialize(from:, subject:, body:)
          @from = from.freeze
          @subject = subject.freeze
          @body = body.freeze
          freeze
        end

        # Accidental logging via inspect must not reveal the OTP.
        def inspect
          "#<#{self.class} [REDACTED]>"
        end
      end

      private

      def validated_client_id(id)
        raise InvalidInput, "invalid email client ID" unless valid_client_id?(id)

        id.dup.freeze
      end

      def validated_client_settings(settings)
        raise InvalidInput, "invalid email client settings" unless settings.is_a?(Hash)

        from = settings.fetch("from", nil)
        brand = settings.fetch("brand", nil)
        raise InvalidInput, "invalid configured email sender" unless safe_sender?(from)
        raise InvalidInput, "invalid configured email branding" unless safe_brand?(brand)

        { from: from.dup.freeze, brand: brand.dup.freeze }.freeze
      end

      def validate_request!(schema_version:, client_id:, intent:, locale:, code:)
        raise InvalidArtifact, "unsupported identity mail schema" unless schema_version == SCHEMA
        raise InvalidArtifact, "unsupported identity mail intent" unless INTENTS.include?(intent)
        raise InvalidArtifact, "unsupported identity mail locale" unless LOCALES.include?(locale)
        raise InvalidArtifact, "invalid identity mail code" unless valid_code?(code)
        raise InvalidArtifact, "unknown identity mail client" unless valid_client_id?(client_id)
      end

      def valid_client_id?(value)
        valid_text_encoding?(value) && value.match?(SAFE_CLIENT_ID)
      end

      def valid_code?(value)
        valid_text_encoding?(value) && value.match?(CODE_PATTERN)
      end

      def safe_sender?(value)
        valid_text_encoding?(value) && value.bytesize <= 254 && value.match?(FROM_PATTERN)
      end

      def safe_brand?(value)
        valid_text_encoding?(value) && value.length.between?(1, 80) &&
          !value.match?(/[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/)
      end

      # Only UTF-8 or pure ASCII can safely be used with these regex contracts.
      def valid_text_encoding?(value)
        value.is_a?(String) && value.valid_encoding? &&
          (value.encoding == Encoding::UTF_8 || value.ascii_only?)
      end
    end
  end
end
