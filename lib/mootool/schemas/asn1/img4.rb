# frozen_string_literal: true

module MooTool
  module Schemas
    module ASN1
      # The container format of every +.img4+ file, as described by +img4.asn+.
      #
      #   Img4File ::= SEQUENCE {
      #     magic    IA5String,     -- always "IMG4"
      #     manifest Img4Manifest,
      #     payload  [0] EXPLICIT Img4Payload OPTIONAL
      #   }
      #
      # The nested structures are modelled by {Manifest}, {ManifestBody}, {Payload}, {Property},
      # {ImageProperties}, {Keybags} and {Keybag}, and may be parsed on their own: an +.im4p+ or an
      # +.im4m+ file is nothing more than the matching member of this container.
      #
      # @example Parse a whole container
      #   img4 = MooTool::Schemas::ASN1::IMG4.parse(der)
      #   img4.magic            # => "IMG4"
      #   img4.manifest[:magic] # => "IM4M"
      #   img4.payload?         # => true
      #
      # @example Parse a lone payload
      #   payload = MooTool::Schemas::ASN1::IMG4::Payload.parse(der)
      #   payload[:type].value  # => "dtre"
      class IMG4 < RASN2::Model
        # The magic of a container.
        # @return [String]
        MAGIC = 'IMG4'

        # A single manifest or image property.
        #
        #   Property ::= SEQUENCE {
        #     tag   IA5String,
        #     type  INTEGER,
        #     value ANY DEFINED BY type
        #   }
        class Property < RASN2::Model
          sequence :property,
                   content: [ia5_string(:tag),
                             integer(:type),
                             any(:value)]

          # The four character code naming this property.
          #
          # @return [String, nil]
          def tag
            self[:tag].value
          end

          # The +ANY+ value of this property, decoded into a plain Ruby object.
          #
          # @return [Object, nil]
          def decoded_value
            der = self[:value].value
            return nil if der.nil? || der.empty?

            decoded = RASN2.parse(der)
            decoded.is_a?(::Array) ? decoded.map(&:value) : decoded.value
          end
        end

        # The properties, hashes and permissions of a single firmware image.
        #
        #   ImageProperties ::= SEQUENCE {
        #     tag        IA5String,
        #     properties SET OF Property
        #   }
        class ImageProperties < RASN2::Model
          sequence :image_properties,
                   content: [ia5_string(:tag),
                             set_of(:properties, Property)]

          # The four character code of the described image, such as +ibot+.
          #
          # @return [String, nil]
          def tag
            self[:tag].value
          end

          # The properties of the described image.
          #
          # @return [Array<Property>]
          def properties
            self[:properties].value || []
          end
        end

        # The signed part of a manifest.
        #
        #   Img4ManifestBody ::= SEQUENCE {
        #     manifestInfo SET OF Property,
        #     images       SET OF ImageProperties
        #   }
        class ManifestBody < RASN2::Model
          sequence :manifest_body,
                   content: [set_of(:manifest_info, Property),
                             set_of(:images, ImageProperties)]

          # The global manifest settings, such as the board identifier or the ECID.
          #
          # @return [Array<Property>]
          def manifest_info
            self[:manifest_info].value || []
          end

          # The per image properties of this manifest.
          #
          # @return [Array<ImageProperties>]
          def images
            self[:images].value || []
          end
        end

        # The properties, signature and certificate chain of a container.
        #
        #   Img4Manifest ::= SEQUENCE {
        #     magic        IA5String,     -- always "IM4M"
        #     version      INTEGER,
        #     body         Img4ManifestBody,
        #     signature    OCTET STRING,
        #     certificates SEQUENCE OF Certificate
        #   }
        class Manifest < RASN2::Model
          # The magic of a manifest.
          # @return [String]
          MAGIC = 'IM4M'

          sequence :manifest,
                   content: [ia5_string(:magic),
                             integer(:version),
                             model(:body, ManifestBody),
                             octet_string(:signature),
                             sequence_of(:certificates, RASN2::Types::Any)]

          # The signed part of this manifest.
          #
          # @return [ManifestBody]
          def body
            self[:body]
          end

          # The cryptographic signature covering {#body}.
          #
          # @return [String, nil]
          def signature
            self[:signature].value
          end

          # The X.509 chain used to verify {#signature}.
          #
          # @return [Array<OpenSSL::X509::Certificate>]
          def certificates
            (self[:certificates].value || []).map { |any| OpenSSL::X509::Certificate.new(any.to_der) }
          end
        end

        # A single encryption keybag.
        #
        #   Keybag ::= SEQUENCE {
        #     type INTEGER,
        #     iv   OCTET STRING,
        #     key  OCTET STRING
        #   }
        class Keybag < RASN2::Model
          sequence :keybag,
                   content: [integer(:type),
                             octet_string(:iv),
                             octet_string(:key)]

          # The initialization vector of this keybag.
          #
          # @return [String, nil]
          def iv
            self[:iv].value
          end

          # The wrapped AES key of this keybag.
          #
          # @return [String, nil]
          def key
            self[:key].value
          end
        end

        # The keybags of an encrypted payload.
        #
        #   Keybags ::= SEQUENCE {
        #     magic IA5String,     -- always "KBAG"
        #     body  SEQUENCE OF Keybag
        #   }
        class Keybags < RASN2::Model
          # The magic of a keybag container.
          # @return [String]
          MAGIC = 'KBAG'

          sequence :keybags,
                   content: [ia5_string(:magic),
                             sequence_of(:body, Keybag)]

          # Every keybag of this container, usually a development and a production one.
          #
          # @return [Array<Keybag>]
          def body
            self[:body].value || []
          end
        end

        # The firmware payload of a container.
        #
        #   Img4Payload ::= SEQUENCE {
        #     magic       IA5String,     -- always "IM4P"
        #     type        IA5String,
        #     description IA5String,
        #     data        OCTET STRING,
        #     keybags     [0] EXPLICIT Keybags OPTIONAL
        #   }
        class Payload < RASN2::Model
          # The magic of a payload.
          # @return [String]
          MAGIC = 'IM4P'

          sequence :payload,
                   content: [ia5_string(:magic),
                             ia5_string(:type),
                             ia5_string(:description),
                             octet_string(:data),
                             wrapper(model(:keybags, Keybags), explicit: 0, constructed: true, optional: true)]

          # The magic of this payload.
          #
          # @return [String, nil]
          def magic
            self[:magic].value
          end

          # The text description of the carried component.
          #
          # @return [String, nil]
          def description
            self[:description].value
          end

          # The raw, possibly compressed and encrypted, firmware bytes.
          #
          # @return [String, nil]
          def data
            self[:data].value
          end

          # The keybags of this payload, when it is encrypted.
          #
          # @return [Keybags, nil]
          def keybags
            keybags = self[:keybags]
            keybags.value?? keybags : nil
          end

          # Whether this payload is encrypted, i.e. carries keybags.
          #
          # @return [Boolean]
          def encrypted?
            !keybags.nil?
          end
        end

        sequence :img4_file,
                 content: [ia5_string(:magic),
                           model(:manifest, Manifest),
                           wrapper(model(:payload, Payload), explicit: 0, constructed: true, optional: true)]

        # The magic of this container, always +IMG4+.
        #
        # @return [String, nil]
        def magic
          self[:magic].value
        end

        # The manifest of this container.
        #
        # @return [Manifest]
        def manifest
          self[:manifest]
        end

        # The payload of this container, when it embeds one.
        #
        # @return [Payload, nil]
        def payload
          payload = self[:payload]
          payload.value?? payload : nil
        end

        # Whether this container embeds a payload.
        #
        # @return [Boolean]
        def payload?
          !payload.nil?
        end
      end
    end
  end
end
