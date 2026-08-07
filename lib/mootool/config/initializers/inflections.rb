# frozen_string_literal: true

# Custom inflections for MooTool.
#
# This initializer defines acronyms for various cryptographic and project-specific
# terms to ensure they are handled correctly by the ActiveSupport inflector.
ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym 'IMG4'
  inflect.acronym 'EC'
  inflect.acronym 'ECC'
  inflect.acronym 'ECIES'
  inflect.acronym 'IO'
  inflect.acronym 'JSON'
  inflect.acronym 'MooTool'
  inflect.acronym 'IPSW'
  inflect.acronym 'VERSION'
  inflect.acronym 'DWARF'
  inflect.acronym 'ASN1'
  inflect.acronym 'RSA'
end
