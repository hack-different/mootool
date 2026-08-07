# frozen_string_literal: true

module MooTool
  # Generic formatters extensions for mootool.
  #
  # This module provides custom formatting logic for various MooTool models and types,
  # allowing them to be displayed with specialized coloring and structure.
  module Formatters
    # Hook to alias the cast method when included.
    #
    # @param base [Class, Module] the class or module including this module
    def self.included(base)
      base.send :alias_method, :cast_without_formatters, :cast
      base.send :alias_method, :cast, :cast_with_formatters
    end

    # Determines the formatting type for a given object.
    #
    # @param object [Object] the object to cast
    # @param type [Symbol] the suggested type
    # @return [Symbol] the resolved formatting type
    def cast_with_formatters(object, type)
      cast = cast_without_formatters(object, type)

      case object
      when Pathname
        :path
      when UUIDTools::UUID
        :uuid
      when OpenSSL::PKey::EC::Point
        :point
      when MooTool::Models::IMG4::FirmwareEntry
        :firmware_entry
      when MooTool::Models::Digest
        :digest
      when MooTool::Models::Certificate
        :certificate
      when MooTool::Models::ECCPublicKey
        :ecc_public_key
      when MooTool::Models::ECCSignature
        :ecc_signature
      when MooTool::Models::ECIESEncryption
        :ecc_encryption
      when Models::RSAPublicKey
        :rsa_public_key
      when Models::DescriptorResult
        :string_descriptor
      when :ALLOW_ANY_VALUE
        :any_value
      else
        cast
      end
    end

    # Formats an RSA public key for output.
    #
    # @param key [Models::RSAPublicKey] the RSA public key to format
    # @return [String] the colorized string representation
    def awesome_rsa_public_key(key)
      "#{colorize('RSAPublicKey', :class)} e=#{colorize(key.e, :integer)}, n=#{colorize(key.n_hex, :digest)}"
    end

    # Formats a string descriptor for output.
    #
    # @param descriptor [Models::DescriptorResult] the string descriptor to format
    # @return [String] the colorized string representation
    def awesome_string_descriptor(descriptor)
      "#{colorize(descriptor.key, :symbol)}:#{colorize(descriptor.string_name, :string)}"
    end

    # Formats an 'any value' placeholder for output.
    #
    # @param _input [Object] the input (unused)
    # @return [String] the colorized string representation
    def awesome_any_value(_input)
      colorize('*** SPLAT ***', :trueclass)
    end

    # Formats a Pathname for output.
    #
    # @param object [Pathname] the pathname to format
    # @return [String] the colorized string representation
    def awesome_path(object)
      colorize(object.to_s, :path)
    end

    # Formats a UUID for output.
    #
    # @param object [UUIDTools::UUID] the UUID to format
    # @return [String] the colorized string representation
    def awesome_uuid(object)
      colorize(object.to_s, :uuid)
    end
  end
end
